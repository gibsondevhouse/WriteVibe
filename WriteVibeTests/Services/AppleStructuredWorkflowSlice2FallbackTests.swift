import XCTest
@testable import WriteVibe

@MainActor
final class AppleStructuredWorkflowSlice2FallbackTests: XCTestCase {

    private func makeSelectionPayload(text: String) -> EditorSelectionPayload {
        EditorSelectionPayload(
            blockID: UUID(),
            range: NSRange(location: 0, length: (text as NSString).length),
            selectedText: text,
            surroundingContext: "Context",
            token: "slice2-token"
        )
    }

    private func makeArticle() -> Article {
        Article(title: "Fallback")
    }

    private var validText: String {
        "This selection is comfortably above fifty characters so validation passes."
    }

    func testSummarizeUsesManualSelectionFallbackWhenUnavailable() async {
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: Slice2SpyAppleWorkflowObservabilityService(),
            availabilityEvaluator: { .unsupportedPlatform }
        )

        let result = await service.summarizeSelectedText(
            text: validText,
            selection: makeSelectionPayload(text: validText),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .completedWithFallback)
        XCTAssertEqual(result.fallbackCode, .manualSelectionEditing)
        XCTAssertEqual(result.userMessage, "We couldn't enhance this right now. Try again later.")
        XCTAssertFalse(result.payload?.summarizedText.isEmpty ?? true)
    }

    func testImproveUsesRetryFallbackWhenExecutionFails() async {
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: Slice2SpyAppleWorkflowObservabilityService(),
            availabilityEvaluator: { .available },
            improveSelectionExecutor: { _, _ in
                throw WriteVibeError.generationFailed(reason: "forced failure")
            }
        )

        let result = await service.improveSelectedText(
            text: validText,
            selection: makeSelectionPayload(text: validText),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .completedWithFallback)
        XCTAssertEqual(result.fallbackCode, .retrySameAction)
        XCTAssertEqual(result.userMessage, "This utility isn't available now.")
        XCTAssertEqual(result.payload?.improvedText, validText)
    }

    func testVariantsUsesSingleOriginalVariantFallbackOnFailure() async {
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: Slice2SpyAppleWorkflowObservabilityService(),
            availabilityEvaluator: { .available },
            variantsSelectionExecutor: { _, _ in DraftVariants(variants: []) }
        )

        let result = await service.generateVariants(
            text: validText,
            selection: makeSelectionPayload(text: validText),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .completedWithFallback)
        XCTAssertEqual(result.fallbackCode, .retrySameAction)
        XCTAssertEqual(result.userMessage, "Variants aren't available now.")
        XCTAssertEqual(result.payload?.variants.count, 1)
        XCTAssertEqual(result.payload?.variants.first?.text, validText)
    }
}
