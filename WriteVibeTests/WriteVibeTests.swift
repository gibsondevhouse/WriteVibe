//
//  WriteVibeTests.swift
//  WriteVibeTests
//
//  Created by Christopher Gibson on 3/10/26.
//

import Foundation
import AppKit
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

    @Test func outlineSuggestionRequiresExplicitApplyBeforeMutatingArticle() async throws {
        let article = Article(title: "Platform rollout", topic: "Feature adoption")
        article.outline = "Existing outline"

        let vm = ArticleEditorViewModel(
            suggestOutlineWorkflow: { _ in
                .success(
                    OutlineSuggestionProposal(
                        title: "Platform rollout",
                        sections: [
                            OutlineSectionProposal(heading: "Current State", summary: "Describe the current rollout baseline."),
                            OutlineSectionProposal(heading: "Next Phase", summary: "Define the next staged rollout step.")
                        ],
                        applyMode: .replaceOutlineText
                    ),
                    userMessage: "Outline suggestion ready.",
                    nextStep: "Apply it if it fits."
                )
            }
        )

        vm.requestOutlineSuggestion(for: article)

        for _ in 0..<20 {
            if vm.isOutlineWorkflowRunning == false {
                break
            }
            await Task.yield()
        }

        #expect(article.outline == "Existing outline")
        let result = try #require(vm.latestOutlineWorkflowResult)
        #expect(result.state == .success)

        vm.applyOutlineSuggestion(to: article)

        #expect(article.outline.contains("Current State"))
        #expect(article.outline.contains("Next Phase"))
    }

    @Test func summarizeSelectionStoresReadOnlyResult() async throws {
        let article = Article(title: "Draft")
        let selection = EditorSelectionPayload(
            blockID: UUID(),
            range: NSRange(location: 0, length: 5),
            selectedText: "Hello world",
            surroundingContext: "Hello world in context.",
            token: "selection-1"
        )

        let vm = ArticleEditorViewModel(
            summarizeSelectionWorkflow: { request, _, _ in
                .success(
                    SelectionSummaryProposal(
                        summaryText: "A concise summary of the selected passage.",
                        sourceSelectionHash: request.selectionRangeToken
                    ),
                    userMessage: "Selection summary ready.",
                    nextStep: "Review the summary."
                )
            }
        )

        vm.requestSelectionWorkflow(.summarize, article: article, selection: selection)

        for _ in 0..<20 {
            if vm.isSelectionWorkflowRunning == false {
                break
            }
            await Task.yield()
        }

        let workflow = try #require(vm.latestSelectionWorkflow)
        #expect(workflow.kind == .summarize)
        #expect(workflow.result.state == .success)
        if case .summary(let proposal)? = workflow.result.payload {
            #expect(proposal.summaryText.contains("concise summary"))
            #expect(proposal.sourceSelectionHash == "selection-1")
        } else {
            Issue.record("Expected a summary payload.")
        }
    }

    @Test func improveSelectionAppliesOnlyWhenCurrentSelectionStillMatches() async throws {
        let article = Article(title: "Draft")
        let textView = NSTextView(frame: .zero)
        let blockID = UUID()
        let attributed = NSMutableAttributedString(string: "Original draft text")
        attributed.addAttribute(.wvBlockID, value: blockID, range: NSRange(location: 0, length: attributed.length))
        textView.textStorage?.setAttributedString(attributed)
        textView.setSelectedRange(NSRange(location: 0, length: 8))

        let editorState = EditorState()
        editorState.textView = textView
        editorState.updateSelectionState(from: textView)
        let selection = try #require(editorState.selectionPayload)

        let vm = ArticleEditorViewModel(
            improveSelectionWorkflow: { request, _, _ in
                .success(
                    SelectionRewriteProposal(
                        rewrittenText: "Refined draft",
                        changeIntent: "Clarify the opening.",
                        sourceSelectionHash: request.selectionRangeToken
                    ),
                    userMessage: "Revision ready.",
                    nextStep: "Apply it if it fits."
                )
            }
        )

        vm.requestSelectionWorkflow(.improve, article: article, selection: selection)

        for _ in 0..<20 {
            if vm.isSelectionWorkflowRunning == false {
                break
            }
            await Task.yield()
        }

        let applied = vm.applySelectionRewrite(using: editorState)

        #expect(applied)
        #expect(textView.string.hasPrefix("Refined draft"))
        switch vm.latestSelectionWorkflow {
        case nil:
            break
        case .some:
            Issue.record("Expected rewrite workflow state to clear after apply.")
        }
    }
}
