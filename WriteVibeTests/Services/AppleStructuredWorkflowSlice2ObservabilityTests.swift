import XCTest
@testable import WriteVibe

@MainActor
final class AppleStructuredWorkflowSlice2ObservabilityTests: XCTestCase {

    private final class Slice2RecordingObservabilityService: AppleWorkflowObservabilityServicing {
        private(set) var artifacts: [AppleWorkflowRunArtifact] = []

        func recordRun(_ artifact: AppleWorkflowRunArtifact) async {
            artifacts.append(artifact)
        }
    }

    private func makeSelectionPayload(text: String) -> EditorSelectionPayload {
        EditorSelectionPayload(
            blockID: UUID(),
            range: NSRange(location: 0, length: (text as NSString).length),
            selectedText: text,
            surroundingContext: "Context",
            token: "selection-observe-token"
        )
    }

    private func makeArticle() -> Article {
        Article(title: "Observe")
    }

    private var validText: String {
        "This selection includes enough content to pass validation for observability checks."
    }

    func testSlice2AttemptRecordsInputSummaryWithoutRawSelectionText() async throws {
        let recorder = Slice2RecordingObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: recorder,
            availabilityEvaluator: { .available },
            summarizeSelectionExecutor: { _ in "Summary output" }
        )

        let result = await service.summarizeSelectedText(
            text: validText,
            selection: makeSelectionPayload(text: validText),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .success)
        XCTAssertEqual(recorder.artifacts.count, 1)

        let artifact = try XCTUnwrap(recorder.artifacts.first)
        XCTAssertEqual(artifact.taskKind, .summarizeSelection)
        XCTAssertEqual(artifact.outcomeState, result.state)
        XCTAssertEqual(artifact.fallbackCode, result.fallbackCode)
        XCTAssertNotNil(artifact.inputSummary)
        XCTAssertEqual(artifact.inputSummary?.selectionToken, "selection-observe-token")
    }

    func testFallbackAttemptRecordsOutcomeAndFallbackCode() async throws {
        let recorder = Slice2RecordingObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: recorder,
            availabilityEvaluator: { .modelUnavailable }
        )

        let result = await service.generateVariants(
            text: validText,
            selection: makeSelectionPayload(text: validText),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .completedWithFallback)
        XCTAssertEqual(recorder.artifacts.count, 1)

        let artifact = try XCTUnwrap(recorder.artifacts.first)
        XCTAssertEqual(artifact.taskKind, .generateVariants)
        XCTAssertEqual(artifact.outcomeState, .completedWithFallback)
        XCTAssertEqual(artifact.fallbackCode, .manualSelectionEditing)
        XCTAssertNotNil(artifact.inputSummary)
    }
}
