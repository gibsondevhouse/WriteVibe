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

    @Test func requestAndApplyEdits_transitionsToFinalizedThenBackToPendingAfterAcceptAll() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Alpha beta", position: 0)
        article.blocks = [block]

        let range = try #require(block.content.range(of: "beta"))
        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: range, newText: "gamma", reason: nil)],
            summary: "Swap word"
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })

        #expect(orchestrator.state.isPending)

        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(orchestrator.state.isFinalized)
        #expect(orchestrator.hasPendingChanges)

        orchestrator.acceptAllChanges()

        #expect(orchestrator.state.isPending)
        #expect(!orchestrator.hasPendingChanges)
    }

    @Test func requestAndApplyEdits_roundTripRejectAllThenReapplyRemainsStable() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "One two three", position: 0)
        article.blocks = [block]

        let firstRange = try #require(block.content.range(of: "two"))
        let firstProposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: firstRange, newText: "TWO", reason: "first")],
            summary: "first pass"
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in firstProposed })

        _ = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(block.content == "One TWO three")
        #expect(orchestrator.hasPendingChanges)

        orchestrator.rejectAllChanges(for: article)

        #expect(block.content == "One two three")
        #expect(orchestrator.state.isPending)

        let secondRange = try #require(block.content.range(of: "three"))
        let secondProposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: secondRange, newText: "THREE", reason: "second")],
            summary: "second pass"
        )
        let secondOrchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in secondProposed })

        _ = try await secondOrchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(block.content == "One two THREE")
        #expect(secondOrchestrator.state.isFinalized)
    }

    @Test func requestAndApplyEdits_rejectsReplaceWithOutOfBoundsRange() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let foreign = "Detached index source"
        let lower = foreign.index(foreign.startIndex, offsetBy: 12)
        let upper = foreign.index(foreign.startIndex, offsetBy: 16)
        let foreignRange = lower..<upper

        let proposed = ProposedEdits(
            operations: [.replace(blockID: block.id, range: foreignRange, newText: "X", reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        let rejection = try #require(result.rejectedOperations.first)
        #expect(rejection.reason.contains("range out of bounds"))
        #expect(block.content == "Hello world")
    }

    @Test func requestAndApplyEdits_rejectsDeleteWithOutOfBoundsRange() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let foreign = "Detached index source"
        let lower = foreign.index(foreign.startIndex, offsetBy: 12)
        let upper = foreign.index(foreign.startIndex, offsetBy: 16)
        let foreignRange = lower..<upper

        let proposed = ProposedEdits(
            operations: [.delete(blockID: block.id, range: foreignRange, reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        let rejection = try #require(result.rejectedOperations.first)
        #expect(rejection.reason.contains("range out of bounds"))
        #expect(block.content == "Hello world")
    }

    @Test func requestAndApplyEdits_rejectsInsertWithOutOfBoundsIndex() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let foreign = "Detached index source"
        let foreignIndex = foreign.index(foreign.startIndex, offsetBy: 14)

        let proposed = ProposedEdits(
            operations: [.insert(blockID: block.id, at: foreignIndex, text: "Hi ", reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        let rejection = try #require(result.rejectedOperations.first)
        #expect(rejection.reason.contains("insert position out of bounds"))
        #expect(block.content == "Hello world")
    }

    @Test func requestAndApplyEdits_rejectsInsertBlockWithMissingAnchor() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let proposed = ProposedEdits(
            operations: [.insertBlock(afterBlockID: UUID(), type: .paragraph, content: "New block", reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        #expect(result.rejectedOperations[0].reason.contains("anchor block not found"))
        #expect(article.blocks.count == 1)
    }

    @Test func requestAndApplyEdits_rejectsDeleteBlockForNonEmptyContent() async throws {
        let article = Article(title: "Test")
        let block1 = ArticleBlock(type: .paragraph, content: "non-empty", position: 0)
        let block2 = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [block1, block2]

        let proposed = ProposedEdits(
            operations: [.deleteBlock(blockID: block1.id, reason: nil)],
            summary: nil
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: [:]
        )

        #expect(result.appliedChanges.isEmpty)
        #expect(result.rejectedOperations.count == 1)
        #expect(result.rejectedOperations[0].reason.contains("empty non-last block"))
        #expect(article.blocks.count == 2)
    }

    @Test func requestAndApplyEdits_preservesExistingChangesWhenApplyConflictIsRejected() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Hello world", position: 0)
        article.blocks = [block]

        let existingSpan = ChangeSpan(
            id: UUID(),
            changeType: .replace,
            author: .ai,
            timestamp: Date(),
            reason: "existing",
            proposedRange: block.content.startIndex..<block.content.startIndex,
            originalText: nil,
            proposedText: ""
        )
        let existingChanges: BlockChanges = [block.id: [existingSpan]]

        let proposed = ProposedEdits(
            operations: [.replace(blockID: UUID(), range: block.content.startIndex..<block.content.startIndex, newText: "unused", reason: nil)],
            summary: "conflict only"
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: existingChanges
        )

        #expect(article.blocks[0].content == "Hello world")
        #expect(result.rejectedOperations.count == 1)
        #expect(result.rejectedOperations[0].reason.contains("Apply conflict"))
        #expect(result.appliedChanges[block.id]?.count == 1)
        #expect(result.appliedChanges[block.id]?.first?.id == existingSpan.id)
        #expect(orchestrator.blockChanges[block.id]?.count == 1)
        #expect(orchestrator.state.isFinalized)
        #expect(orchestrator.hasPendingChanges)
    }

    @Test func requestAndApplyEdits_mixedOperationsApplyValidEditsAndRejectInvalidInOrder() async throws {
        let article = Article(title: "Test")
        let block = ArticleBlock(type: .paragraph, content: "Alpha beta gamma", position: 0)
        article.blocks = [block]

        let existingSpan = ChangeSpan(
            id: UUID(),
            changeType: .replace,
            author: .ai,
            timestamp: Date(),
            reason: "existing",
            proposedRange: block.content.startIndex..<block.content.startIndex,
            originalText: nil,
            proposedText: ""
        )
        let existingChanges: BlockChanges = [block.id: [existingSpan]]

        let replaceRange = try #require(block.content.range(of: "beta"))
        let foreign = "Detached index source with long tail"
        let invalidLower = foreign.index(foreign.startIndex, offsetBy: 24)
        let invalidUpper = foreign.index(foreign.startIndex, offsetBy: 28)
        let invalidRange = invalidLower..<invalidUpper

        let proposed = ProposedEdits(
            operations: [
                .replace(blockID: block.id, range: replaceRange, newText: "BETA", reason: "valid replace"),
                .insert(blockID: UUID(), at: block.content.startIndex, text: "X", reason: "missing block"),
                .delete(blockID: block.id, range: invalidRange, reason: "bad range")
            ],
            summary: "mixed"
        )

        let orchestrator = DefaultArticleEditOrchestrator(proposeEdits: { _, _ in proposed })
        let result = try await orchestrator.requestAndApplyEdits(
            article: article,
            modelID: "anthropic/claude-3-7-sonnet",
            existingChanges: existingChanges
        )

        #expect(block.content == "Alpha BETA gamma")
        #expect(result.appliedChanges[block.id]?.count == 2)
        #expect(result.appliedChanges[block.id]?.first?.id == existingSpan.id)
        #expect(result.appliedChanges[block.id]?.last?.proposedText == "BETA")

        #expect(result.rejectedOperations.count == 2)
        let rejectionReasons = result.rejectedOperations.map(\.reason)
        #expect(rejectionReasons[0].contains("Apply conflict"))
        #expect(rejectionReasons[1].contains("Validation failure"))
    }
}
