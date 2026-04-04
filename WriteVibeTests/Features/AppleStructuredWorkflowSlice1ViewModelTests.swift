//
//  AppleStructuredWorkflowSlice1ViewModelTests.swift
//  WriteVibeTests
//
//  Unit tests for ArticleEditorViewModel's Apple Structured Workflow integration.
//  Covers outline workflow states and selection workflow states (Slice 1 VM coverage).
//  Uses XCTest. Does not modify production source files.
//
//
//  Unit tests for ArticleEditorViewModel's Apple Structured Workflow integration.
//  Covers outline workflow states and selection workflow states (Slice 1 VM coverage).
//  Uses XCTest. Does not modify production source files.
//

import XCTest
import AppKit
@testable import WriteVibe

// MARK: - Private helpers

private func makeTestArticle(title: String = "Test Article", topic: String = "Swift") -> Article {
    Article(title: title, subtitle: "", topic: topic)
}

private func makeSelectionPayload(
    token: String = "tok-1",
    selectedText: String = "Hello world"
) -> EditorSelectionPayload {
    EditorSelectionPayload(
        blockID: UUID(),
        range: NSRange(location: 0, length: (selectedText as NSString).length),
        selectedText: selectedText,
        surroundingContext: nil,
        token: token
    )
}

// MARK: - Tests

@MainActor
final class AppleStructuredWorkflowSlice1ViewModelTests: XCTestCase {

    // MARK: - Proposal factories

    private func makeOutlineProposal() -> OutlineSuggestionProposal {
        OutlineSuggestionProposal(
            title: "Test Outline",
            sections: [OutlineSectionProposal(heading: "Introduction", summary: "Intro summary")],
            applyMode: .replaceOutlineText
        )
    }

    private func makeSummaryProposal(token: String = "tok-1") -> SelectionSummaryProposal {
        SelectionSummaryProposal(
            summaryText: "A concise summary.",
            sourceSelectionHash: token
        )
    }

    private func makeRewriteProposal(token: String = "tok-1") -> SelectionRewriteProposal {
        SelectionRewriteProposal(
            rewrittenText: "Improved text.",
            changeIntent: "clarity",
            sourceSelectionHash: token
        )
    }

    private func awaitOutlineResult(vm: ArticleEditorViewModel, iterations: Int = 60) async {
        for _ in 0..<iterations {
            await Task.yield()
            if case .result = vm.outlineWorkflowState { break }
        }
    }

    private func awaitSelectionResult(vm: ArticleEditorViewModel, iterations: Int = 60) async {
        for _ in 0..<iterations {
            await Task.yield()
            if case .result = vm.selectionWorkflowState { break }
        }
    }

    // MARK: - 1. Outline workflow: idle → running → result(success)

    func testOutlineWorkflow_idleToRunningToSuccessResult() async {
        let proposal = makeOutlineProposal()
        let vm = ArticleEditorViewModel(
            suggestOutlineWorkflow: { _ in
                .success(proposal, userMessage: "Outline ready.")
            }
        )
        let article = makeTestArticle()

        guard case .idle = vm.outlineWorkflowState else {
            XCTFail("Expected initial state to be .idle"); return
        }

        vm.requestOutlineSuggestion(for: article)
        await awaitOutlineResult(vm: vm)

        guard case .result = vm.outlineWorkflowState else {
            XCTFail("Expected .result state after requestOutlineSuggestion"); return
        }
        XCTAssertNotNil(vm.latestOutlineWorkflowResult)
        XCTAssertEqual(vm.latestOutlineWorkflowResult?.state, .success)
    }

    // MARK: - 2. Outline workflow: result apply mutates article outline

    func testOutlineWorkflow_applySuccessResultMutatesArticleOutline() async {
        let proposal = makeOutlineProposal()
        let vm = ArticleEditorViewModel()
        let article = makeTestArticle()

        let result = AppleWorkflowTaskResult<OutlineSuggestionProposal>.success(
            proposal, userMessage: "Done."
        )
        vm.outlineWorkflowState = .result(result)
        vm.applyOutlineSuggestion(to: article)

        XCTAssertFalse(article.outline.isEmpty, "Article outline should be non-empty after applying success result")
        guard case .idle = vm.outlineWorkflowState else {
            XCTFail("Expected .idle after applyOutlineSuggestion"); return
        }
    }

    // MARK: - 3. Outline workflow: apply is no-op on non-success result

    func testOutlineWorkflow_applyIsNoOpOnExecutionFailureResult() async {
        let vm = ArticleEditorViewModel()
        let article = makeTestArticle()

        let result = AppleWorkflowTaskResult<OutlineSuggestionProposal>.executionFailure(
            userMessage: "Failed.",
            nextStep: "Retry."
        )
        vm.outlineWorkflowState = .result(result)
        vm.applyOutlineSuggestion(to: article)

        XCTAssertTrue(article.outline.isEmpty, "Article outline must remain empty when result state is not success")
    }

    // MARK: - 4. Outline workflow: dismiss resets to idle

    func testOutlineWorkflow_dismissResetsToIdle() async {
        let proposal = makeOutlineProposal()
        let vm = ArticleEditorViewModel()
        let result = AppleWorkflowTaskResult<OutlineSuggestionProposal>.success(
            proposal, userMessage: "Done."
        )
        vm.outlineWorkflowState = .result(result)

        vm.dismissOutlineWorkflow()

        guard case .idle = vm.outlineWorkflowState else {
            XCTFail("Expected .idle after dismissOutlineWorkflow()"); return
        }
    }

    // MARK: - 5. Outline workflow: validation failure state is preserved

    func testOutlineWorkflow_validationFailureStateIsPreserved() async {
        let vm = ArticleEditorViewModel(
            suggestOutlineWorkflow: { _ in
                .validationFailure(userMessage: "No planning data.", nextStep: "Add topic.")
            }
        )
        let article = makeTestArticle(title: "", topic: "")

        vm.requestOutlineSuggestion(for: article)
        await awaitOutlineResult(vm: vm)

        XCTAssertEqual(
            vm.latestOutlineWorkflowResult?.state, .validationFailure,
            "latestOutlineWorkflowResult.state should be .validationFailure"
        )
    }

    // MARK: - 6. Selection workflow: summarize transitions to running then result

    func testSelectionWorkflow_summarizeTransitionsToResult() async {
        let summaryProposal = makeSummaryProposal()
        let vm = ArticleEditorViewModel(
            summarizeSelectionWorkflow: { _ in
                .success(summaryProposal, userMessage: "Summary ready.")
            }
        )
        let article = makeTestArticle()
        let payload = makeSelectionPayload(token: "tok-1")

        vm.requestSelectionWorkflow(.summarize, article: article, selection: payload)
        await awaitSelectionResult(vm: vm)

        guard case .result(let kind, _, _) = vm.selectionWorkflowState else {
            XCTFail("Expected .result state after summarize workflow"); return
        }
        XCTAssertEqual(kind, .summarize)
    }

    // MARK: - 7. Selection workflow: summarize result payload wraps as .summary

    func testSelectionWorkflow_summarizePayloadWrapsAsSummary() async {
        let summaryProposal = makeSummaryProposal()
        let vm = ArticleEditorViewModel(
            summarizeSelectionWorkflow: { _ in
                .success(summaryProposal, userMessage: "Summary ready.")
            }
        )
        let article = makeTestArticle()
        let payload = makeSelectionPayload(token: "tok-1")

        vm.requestSelectionWorkflow(.summarize, article: article, selection: payload)
        await awaitSelectionResult(vm: vm)

        let latest = vm.latestSelectionWorkflow
        XCTAssertNotNil(latest, "latestSelectionWorkflow should be non-nil")

        guard case .summary(let s) = latest?.result.payload else {
            XCTFail("Expected .summary payload, got \(String(describing: latest?.result.payload))")
            return
        }
        XCTAssertEqual(s.summaryText, summaryProposal.summaryText)
    }

    // MARK: - 8. Selection workflow: improve result payload wraps as .rewrite

    func testSelectionWorkflow_improvePayloadWrapsAsRewrite() async {
        let rewriteProposal = makeRewriteProposal()
        let vm = ArticleEditorViewModel(
            improveSelectionWorkflow: { _ in
                .success(rewriteProposal, userMessage: "Improved.")
            }
        )
        let article = makeTestArticle()
        let payload = makeSelectionPayload(token: "tok-1")

        vm.requestSelectionWorkflow(.improve, article: article, selection: payload)
        await awaitSelectionResult(vm: vm)

        let latest = vm.latestSelectionWorkflow
        XCTAssertNotNil(latest, "latestSelectionWorkflow should be non-nil")

        guard case .rewrite(let r) = latest?.result.payload else {
            XCTFail("Expected .rewrite payload, got \(String(describing: latest?.result.payload))")
            return
        }
        XCTAssertEqual(r.rewrittenText, rewriteProposal.rewrittenText)
    }

    // MARK: - 9. Selection workflow: token mismatch dismisses in-flight result

    func testSelectionWorkflow_tokenMismatchDismissesResult() async {
        let vm = ArticleEditorViewModel()
        let summaryProposal = makeSummaryProposal(token: "A")
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .summary(summaryProposal),
            userMessage: "Done.",
            nextStep: "Review.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .summarize, selectionToken: "A", result: result)

        vm.handleSelectionChange(currentToken: "B")

        guard case .idle = vm.selectionWorkflowState else {
            XCTFail("Expected .idle after token mismatch in handleSelectionChange"); return
        }
    }

    // MARK: - 10. Selection workflow: token match preserves result

    func testSelectionWorkflow_tokenMatchPreservesResult() async {
        let vm = ArticleEditorViewModel()
        let summaryProposal = makeSummaryProposal(token: "A")
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .summary(summaryProposal),
            userMessage: "Done.",
            nextStep: "Review.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .summarize, selectionToken: "A", result: result)

        vm.handleSelectionChange(currentToken: "A")

        guard case .result(let kind, let token, _) = vm.selectionWorkflowState else {
            XCTFail("Expected .result to be preserved after matching token"); return
        }
        XCTAssertEqual(kind, .summarize)
        XCTAssertEqual(token, "A")
    }

    // MARK: - 11. Selection workflow: dismiss resets to idle

    func testSelectionWorkflow_dismissResetsToIdle() async {
        let vm = ArticleEditorViewModel()
        let summaryProposal = makeSummaryProposal(token: "A")
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .summary(summaryProposal),
            userMessage: "Done.",
            nextStep: "Review.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .summarize, selectionToken: "A", result: result)

        vm.dismissSelectionWorkflow()

        guard case .idle = vm.selectionWorkflowState else {
            XCTFail("Expected .idle after dismissSelectionWorkflow()"); return
        }
    }

    // MARK: - 12. applySelectionRewrite returns false when state is idle

    func testApplySelectionRewrite_returnsFalseWhenStateIsIdle() async {
        let vm = ArticleEditorViewModel()
        let editorState = EditorState()

        let result = vm.applySelectionRewrite(using: editorState)

        XCTAssertFalse(result, "applySelectionRewrite should return false when selectionWorkflowState is .idle")
    }

    // MARK: - 13. applySelectionRewrite returns false when state is summarize result (not improve)

    func testApplySelectionRewrite_returnsFalseForSummarizeResult() async {
        let vm = ArticleEditorViewModel()
        let editorState = EditorState()
        let summaryProposal = makeSummaryProposal(token: "A")
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .summary(summaryProposal),
            userMessage: "Done.",
            nextStep: "Review.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .summarize, selectionToken: "A", result: result)

        let applyResult = vm.applySelectionRewrite(using: editorState)

        XCTAssertFalse(applyResult, "applySelectionRewrite should return false when kind is .summarize")
    }

    // MARK: - 14. Non-success outline result does not apply outline

    func testOutlineWorkflow_nonSuccessResultDoesNotApplyOutline() async {
        let vm = ArticleEditorViewModel(
            suggestOutlineWorkflow: { _ in
                .executionFailure(userMessage: "Failed.", nextStep: "Retry.")
            }
        )
        let article = makeTestArticle()

        vm.requestOutlineSuggestion(for: article)
        await awaitOutlineResult(vm: vm)

        vm.applyOutlineSuggestion(to: article)

        XCTAssertTrue(
            article.outline.isEmpty,
            "Article outline must remain empty after executionFailure result apply attempt"
        )
    }
}
