//
//  ArticleEditOrchestratorTests.swift
//  WriteVibeTests
//

import Foundation
import Testing
@testable import WriteVibe

@MainActor
struct ArticleEditOrchestratorTests {

    @Test func requestAndApplyEdits_appliesReplaceAndReturnsChangeSpan() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let range = try #require(block.content.range(of: "world"))
        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: range, newText: "there", reason: "Improve tone")],
            summary: "Improved wording."
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })

        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(article.blocks.count == 1)
        #expect(article.blocks[0].content == "Hello there")
        #expect(result.summary == "Improved wording.")
        #expect(result.rejectedOperations.isEmpty)

        let spans = result.appliedChanges[block.id] ?? []
        #expect(spans.count == 1)
        #expect(spans.first?.changeType == .replace)
        #expect(spans.first?.originalText == "world")
        #expect(spans.first?.proposedText == "there")
    }

    @Test func requestAndApplyEdits_rejectsOperationForMissingBlock() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let proposed = ProposedEdits(
            operations: [.insert(blockID: UUID(), at: block.content.startIndex, text: "Hi ", reason: "Prefix")],
            summary: "Attempted edit."
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })

        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(article.blocks.count == 1)
        #expect(article.blocks[0].content == "Hello world")
        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        #expect(result.rejectedOperations[0].reason.contains("target block not found"))
    }

    @Test func acceptSpan_removesSpanFromBlockChanges() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello there", position: 0)
        article.blocks = [block]

        let range = try #require(block.content.range(of: "there"))
        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: range, newText: "there", reason: "Improve tone")],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        
        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )
        
        let initialSpans = orchestrator.blockChanges[block.id] ?? []
        #expect(initialSpans.count == 1)
        
        let span = initialSpans[0]
        orchestrator.acceptSpan(span, in: block.id, article: article)
        
        #expect(orchestrator.blockChanges[block.id]?.isEmpty ?? true)
        #expect(!orchestrator.hasPendingChanges)
    }

    @Test func rejectSpan_revertsBlockContentAndRemovesSpan() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let range = try #require(block.content.range(of: "world"))
        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: range, newText: "there", reason: "Improve tone")],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        
        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )
        
        #expect(block.content == "Hello there")
        
        let span = try #require(orchestrator.blockChanges[block.id]?[0])
        
        orchestrator.rejectSpan(span, in: block.id, article: article)
        
        #expect(block.content == "Hello world")
        #expect(orchestrator.blockChanges[block.id]?.isEmpty ?? true)
        #expect(!orchestrator.hasPendingChanges)
    }

    @Test func acceptAllChanges_clearsAllBlockChanges() async throws {
        let article = Article(title: "Test")
        let block1 = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        let block2 = ArticleBlock(type: .paragraph, content: "Good bye world", position: 1000)
        article.blocks = [block1, block2]

        let range1 = try #require(block1.content.range(of: "world"))
        let range2 = try #require(block2.content.range(of: "bye"))
        let proposed = ProposedEdits(
            operations: [
                .replace(blockID: block1.id, range: range1, newText: "there", reason: nil),
                .replace(blockID: block2.id, range: range2, newText: "see", reason: nil)
            ],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        
        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )
        
        #expect(orchestrator.hasPendingChanges)
        #expect(orchestrator.blockChanges.count == 2)
        
        orchestrator.acceptAllChanges()
        
        #expect(!orchestrator.hasPendingChanges)
        #expect(orchestrator.blockChanges.isEmpty)
    }

    @Test func rejectAllChanges_revertsAllBlocksToBaseline() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let range = try #require(block.content.range(of: "world"))
        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: range, newText: "there", reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        
        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )
        
        #expect(block.content == "Hello there")
        #expect(orchestrator.hasPendingChanges)
        
        orchestrator.rejectAllChanges(for: article)
        
        #expect(block.content == "Hello world")
        #expect(!orchestrator.hasPendingChanges)
        #expect(orchestrator.blockChanges.isEmpty)
    }
}
