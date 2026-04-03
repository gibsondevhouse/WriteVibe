//
//  WriteVibeTests.swift
//  WriteVibeTests
//
//  Created by Christopher Gibson on 3/10/26.
//

import Foundation
import Testing
@testable import WriteVibe

@MainActor
private final class FailingArticleEditOrchestrator: ArticleEditOrchestrating {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func requestAndApplyEdits(
        article: Article,
        modelID: String,
        existingChanges: BlockChanges
    ) async throws -> EditApplyResult {
        throw error
    }

    func acceptSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {}

    func rejectSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {}

    func acceptAllChanges() {}

    func rejectAllChanges(for article: Article) {}

    var hasPendingChanges: Bool { false }
    var blockChanges: BlockChanges { [:] }

    var state: EditOrchestrationState { .pending }
}

@MainActor
private final class CapturingArticleEditOrchestrator: ArticleEditOrchestrating {
    private(set) var capturedExistingChanges: BlockChanges?
    var blockChanges: BlockChanges
    var hasPendingChanges: Bool { !blockChanges.isEmpty }
    var state: EditOrchestrationState = .pending

    init(blockChanges: BlockChanges) {
        self.blockChanges = blockChanges
    }

    func requestAndApplyEdits(
        article: Article,
        modelID: String,
        existingChanges: BlockChanges
    ) async throws -> EditApplyResult {
        capturedExistingChanges = existingChanges
        state = .finalized(
            result: EditApplyResult(
                summary: "captured",
                appliedChanges: existingChanges,
                rejectedOperations: []
            )
        )
        return EditApplyResult(summary: "captured", appliedChanges: existingChanges, rejectedOperations: [])
    }

    func acceptSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {}
    func rejectSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {}
    func acceptAllChanges() {}
    func rejectAllChanges(for article: Article) {}
}

@MainActor
struct WriteVibeTests {

    @Test func articleEditorViewModelMapsMissingAPIKeyToRecoveryIssue() async throws {
        let article = Article(title: "Draft")
        article.blocks = [ArticleBlock(type: .paragraph, content: "Hello world", position: 0)]

        let vm = ArticleEditorViewModel(
            editOrchestrator: FailingArticleEditOrchestrator(error: WriteVibeError.missingAPIKey(provider: "OpenRouter"))
        )

        vm.requestAIEdits(for: article, defaultModel: .gpt4o)

        for _ in 0..<20 {
            if vm.isRequestingEdits == false {
                break
            }
            await Task.yield()
        }

        let issue = try #require(vm.aiError)
        #expect(issue.title == "OpenRouter API key required")
        #expect(issue.message.contains("no API key is configured"))
        #expect(issue.nextStep.contains("Settings > Cloud API Keys"))
    }

    @Test func articleEditorViewModelForwardsExistingChangesFromOrchestrationBoundary() async throws {
        let article = Article(title: "Draft")
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

        let orchestrator = CapturingArticleEditOrchestrator(blockChanges: existingChanges)
        let vm = ArticleEditorViewModel(editOrchestrator: orchestrator)

        vm.requestAIEdits(for: article, defaultModel: .gpt4o)

        for _ in 0..<20 {
            if vm.isRequestingEdits == false {
                break
            }
            await Task.yield()
        }

        let captured = try #require(orchestrator.capturedExistingChanges)
        #expect(captured[block.id]?.count == 1)
        #expect(vm.editSummary == "captured")
    }

}
