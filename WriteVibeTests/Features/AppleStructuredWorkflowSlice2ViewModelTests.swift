import XCTest
import AppKit
@testable import WriteVibe

private func makeSlice2Article() -> Article {
    Article(title: "Slice 2", subtitle: "", topic: "Editing")
}

private func makeSlice2SelectionPayload(
    token: String = "tok-s2",
    selectedText: String = String(repeating: "A", count: 80)
) -> EditorSelectionPayload {
    EditorSelectionPayload(
        blockID: UUID(),
        range: NSRange(location: 0, length: (selectedText as NSString).length),
        selectedText: selectedText,
        surroundingContext: "Context",
        token: token
    )
}

private struct StubAppleStructuredWorkflowService: AppleStructuredWorkflowServicing {
    let summarizeResult: AppleStructuredWorkflowTaskResult<SummarizeProposal>
    let improveResult: AppleStructuredWorkflowTaskResult<ImproveProposal>
    let variantsResult: AppleStructuredWorkflowTaskResult<VariantsProposal>

    func autofillDraft(from summary: String, articleSnapshot: DraftAutofillSeed?) async -> AppleStructuredWorkflowTaskResult<DraftAutofillProposal> {
        _ = summary
        _ = articleSnapshot
        return AppleStructuredWorkflowTaskResult(
            state: .validationFailed,
            payload: nil,
            unavailableReason: .validationFailed,
            fallbackCode: .retrySameAction,
            userMessage: "Not used",
            runID: UUID(),
            schemaVersion: "apple-structured-workflow/v1"
        )
    }

    func suggestOutline(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal> {
        _ = snapshot
        return AppleStructuredWorkflowTaskResult(
            state: .validationFailed,
            payload: nil,
            unavailableReason: .validationFailed,
            fallbackCode: .retrySameAction,
            userMessage: "Not used",
            runID: UUID(),
            schemaVersion: "apple-structured-workflow/v1"
        )
    }

    func suggestContext(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal> {
        _ = snapshot
        return AppleStructuredWorkflowTaskResult(
            state: .validationFailed,
            payload: nil,
            unavailableReason: .validationFailed,
            fallbackCode: .retrySameAction,
            userMessage: "Not used",
            runID: UUID(),
            schemaVersion: "apple-structured-workflow/v1"
        )
    }

    func summarizeSelectedText(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<SummarizeProposal> {
        _ = text
        _ = selection
        _ = article
        return summarizeResult
    }

    func improveSelectedText(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<ImproveProposal> {
        _ = text
        _ = selection
        _ = article
        return improveResult
    }

    func generateVariants(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<VariantsProposal> {
        _ = text
        _ = selection
        _ = article
        return variantsResult
    }
}

@MainActor
final class AppleStructuredWorkflowSlice2ViewModelTests: XCTestCase {

    private func awaitSelectionResult(vm: ArticleEditorViewModel, iterations: Int = 60) async {
        for _ in 0..<iterations {
            await Task.yield()
            if case .result = vm.selectionWorkflowState { break }
        }
    }

    private func makeEditorState(
        fullText: String,
        selectedRange: NSRange,
        token: String,
        selectedText: String
    ) -> EditorState {
        let editorState = EditorState()
        let textView = NSTextView(frame: .zero)
        textView.string = fullText
        textView.setSelectedRange(selectedRange)
        editorState.textView = textView
        editorState.selectionPayload = EditorSelectionPayload(
            blockID: UUID(),
            range: selectedRange,
            selectedText: selectedText,
            surroundingContext: nil,
            token: token
        )
        editorState.hasSelection = true
        return editorState
    }

    func testVariantsWorkflow_successMapsToVariantsPayload() async {
        let proposal = SelectionVariantsProposal(
            variants: [
                SelectionVariantItem(text: "First variant", styleLabel: "concise"),
                SelectionVariantItem(text: "Second variant", styleLabel: "balanced"),
                SelectionVariantItem(text: "Third variant", styleLabel: "vivid")
            ],
            sourceSelectionHash: "tok-s2"
        )
        let vm = ArticleEditorViewModel(
            generateVariantsWorkflow: { _, _, _ in
                .success(proposal, userMessage: "Variants ready.")
            }
        )

        vm.requestSelectionWorkflow(
            .variants,
            article: makeSlice2Article(),
            selection: makeSlice2SelectionPayload()
        )
        await awaitSelectionResult(vm: vm)

        guard case .result(let kind, _, let result) = vm.selectionWorkflowState else {
            XCTFail("Expected result state"); return
        }
        XCTAssertEqual(kind, .variants)
        guard case .variants(let payload)? = result.payload else {
            XCTFail("Expected variants payload"); return
        }
        XCTAssertEqual(payload.variants.count, 3)
        XCTAssertEqual(payload.variants.map(\.styleLabel), ["concise", "balanced", "vivid"])
    }

    func testVariantsWorkflow_shortSelectionFailsValidationWithoutMutation() async {
        let vm = ArticleEditorViewModel()
        let payload = makeSlice2SelectionPayload(selectedText: "Too short")

        vm.requestSelectionWorkflow(.variants, article: makeSlice2Article(), selection: payload)

        guard case .result(let kind, _, let result) = vm.selectionWorkflowState else {
            XCTFail("Expected validation result"); return
        }
        XCTAssertEqual(kind, .variants)
        XCTAssertEqual(result.state, .validationFailure)
        XCTAssertEqual(result.userMessage, "Select more text to generate variants.")
    }

    func testVariantsWorkflow_invalidVariantCountConvertsToExecutionFailure() async {
        let invalid = SelectionVariantsProposal(
            variants: [
                SelectionVariantItem(text: "Only one", styleLabel: "concise")
            ],
            sourceSelectionHash: "tok-s2"
        )
        let vm = ArticleEditorViewModel(
            generateVariantsWorkflow: { _, _, _ in
                .success(invalid, userMessage: "Variants ready.")
            }
        )

        vm.requestSelectionWorkflow(
            .variants,
            article: makeSlice2Article(),
            selection: makeSlice2SelectionPayload()
        )
        await awaitSelectionResult(vm: vm)

        guard case .result(_, _, let result) = vm.selectionWorkflowState else {
            XCTFail("Expected result"); return
        }
        XCTAssertEqual(result.state, .executionFailure)
        XCTAssertEqual(result.userMessage, "Variants could not be generated. Your selected text is unchanged. Please retry.")
    }

    func testApplySelectionVariant_tokenMismatchBlocksMutation() async {
        let fullText = "Original selected passage should stay unchanged."
        let selectedRange = NSRange(location: 0, length: 16)
        let editorState = makeEditorState(
            fullText: fullText,
            selectedRange: selectedRange,
            token: "live-token",
            selectedText: "Original selected"
        )

        let vm = ArticleEditorViewModel()
        let proposal = SelectionVariantsProposal(
            variants: [
                SelectionVariantItem(text: "Variant one", styleLabel: "concise"),
                SelectionVariantItem(text: "Variant two", styleLabel: "balanced"),
                SelectionVariantItem(text: "Variant three", styleLabel: "vivid")
            ],
            sourceSelectionHash: "stale-token"
        )
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .variants(proposal),
            userMessage: "Variants ready.",
            nextStep: "Apply one.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .variants, selectionToken: "stale-token", result: result)

        let applied = vm.applySelectionVariant(using: editorState, variantIndex: 0)

        XCTAssertFalse(applied)
        XCTAssertEqual(editorState.textView?.string, fullText)
        guard case .result(kind: .variants, _, let updatedResult) = vm.selectionWorkflowState else {
            XCTFail("Expected variants result after blocked apply"); return
        }
        XCTAssertEqual(updatedResult.state, .executionFailure)
        XCTAssertEqual(updatedResult.userMessage, "Variants could not be generated. Your selected text is unchanged. Please retry.")
    }

    func testApplySelectionVariant_tokenMatchAppliesSelectedVariantAndResetsIdle() async {
        let fullText = "Original selected passage should change."
        let selectedRange = NSRange(location: 0, length: 16)
        let editorState = makeEditorState(
            fullText: fullText,
            selectedRange: selectedRange,
            token: "tok-match",
            selectedText: "Original selected"
        )

        let vm = ArticleEditorViewModel()
        let proposal = SelectionVariantsProposal(
            variants: [
                SelectionVariantItem(text: "Variant one", styleLabel: "concise"),
                SelectionVariantItem(text: "Variant two", styleLabel: "balanced"),
                SelectionVariantItem(text: "Variant three", styleLabel: "vivid")
            ],
            sourceSelectionHash: "tok-match"
        )
        let result = AppleWorkflowTaskResult<SelectionWorkflowPayload>(
            state: .success,
            payload: .variants(proposal),
            userMessage: "Variants ready.",
            nextStep: "Apply one.",
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
        vm.selectionWorkflowState = .result(kind: .variants, selectionToken: "tok-match", result: result)

        let applied = vm.applySelectionVariant(using: editorState, variantIndex: 1)

        XCTAssertTrue(applied)
        XCTAssertTrue(editorState.textView?.string.hasPrefix("Variant two") == true)
        guard case .idle = vm.selectionWorkflowState else {
            XCTFail("Expected idle after successful variant apply"); return
        }
    }

    func testSelectionWorkflow_completedWithFallbackMapsToFallbackCompleteState() async {
        let service = StubAppleStructuredWorkflowService(
            summarizeResult: AppleStructuredWorkflowTaskResult(
                state: .completedWithFallback,
                payload: SummarizeProposal(
                    summarizedText: "Fallback summary",
                    wordCount: 2,
                    generatedOn: Date()
                ),
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Fallback executed.",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            ),
            improveResult: AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: ImproveProposal(improvedText: "x", rationale: nil, generatedOn: Date()),
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "unused",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            ),
            variantsResult: AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: VariantsProposal(variants: [], generatedOn: Date()),
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "unused",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            )
        )
        let vm = ArticleEditorViewModel(structuredWorkflowService: service)

        vm.requestSelectionWorkflow(
            .summarize,
            article: makeSlice2Article(),
            selection: makeSlice2SelectionPayload()
        )
        await awaitSelectionResult(vm: vm)

        guard case .result(let kind, _, let result) = vm.selectionWorkflowState else {
            XCTFail("Expected result state"); return
        }
        XCTAssertEqual(kind, .summarize)
        XCTAssertEqual(result.state, .fallbackComplete)
        XCTAssertEqual(result.userMessage, SelectionWorkflowKind.summarize.fallbackMessage)
        XCTAssertEqual(result.fallbackCode, AppleWorkflowFallbackCode.manualSelectionEditing.rawValue)
        guard case .summary(let payload)? = result.payload else {
            XCTFail("Expected summary payload"); return
        }
        XCTAssertEqual(payload.summaryText, "Fallback summary")
    }

    func testSelectionWorkflow_unavailableUsesDeterministicKindCopy() async {
        let service = StubAppleStructuredWorkflowService(
            summarizeResult: AppleStructuredWorkflowTaskResult(
                state: .modelUnavailable,
                payload: nil,
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Unavailable",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            ),
            improveResult: AppleStructuredWorkflowTaskResult(
                state: .modelUnavailable,
                payload: nil,
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Unavailable",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            ),
            variantsResult: AppleStructuredWorkflowTaskResult(
                state: .modelUnavailable,
                payload: nil,
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Unavailable",
                runID: UUID(),
                schemaVersion: "apple-structured-workflow/v1"
            )
        )
        let vm = ArticleEditorViewModel(structuredWorkflowService: service)

        vm.requestSelectionWorkflow(
            .improve,
            article: makeSlice2Article(),
            selection: makeSlice2SelectionPayload()
        )
        await awaitSelectionResult(vm: vm)

        guard case .result(let kind, _, let result) = vm.selectionWorkflowState else {
            XCTFail("Expected result state"); return
        }
        XCTAssertEqual(kind, .improve)
        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.userMessage, SelectionWorkflowKind.improve.unavailableMessage)
    }
}
