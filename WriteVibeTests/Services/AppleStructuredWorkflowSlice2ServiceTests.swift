import XCTest
@testable import WriteVibe

@MainActor
final class AppleStructuredWorkflowSlice2ServiceTests: XCTestCase {

    private func makeService(
        summarize: @escaping AppleStructuredWorkflowService.SummarizeSelectionExecutor = { _ in "Summarized output" },
        improve: @escaping AppleStructuredWorkflowService.ImproveSelectionExecutor = { text, _ in "Improved: \(text)" },
        variants: @escaping AppleStructuredWorkflowService.VariantsSelectionExecutor = { _, _ in DraftVariants(variants: ["v1", "v2", "v3"]) }
    ) -> AppleStructuredWorkflowService {
        AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: Slice2SpyAppleWorkflowObservabilityService(),
            availabilityEvaluator: { .available },
            summarizeSelectionExecutor: summarize,
            improveSelectionExecutor: improve,
            variantsSelectionExecutor: variants
        )
    }

    private func makeSelectionPayload(
        text: String,
        token: String = "selection-token",
        blockID: UUID? = UUID(),
        range: NSRange? = nil
    ) -> EditorSelectionPayload {
        let derivedRange = range ?? NSRange(location: 0, length: (text as NSString).length)
        return EditorSelectionPayload(
            blockID: blockID,
            range: derivedRange,
            selectedText: text,
            surroundingContext: "Surrounding context",
            token: token
        )
    }

    private func makeArticle() -> Article {
        Article(title: "Slice 2")
    }

    private var validText: String {
        String(repeating: "A", count: 80)
    }

    func testSummarizeValidationFailsForShortText() async {
        let service = makeService()
        let text = "short"
        let selection = makeSelectionPayload(text: text)

        let result = await service.summarizeSelectedText(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
    }

    func testImproveValidationFailsForInvalidSelectionToken() async {
        let service = makeService()
        let text = validText
        let selection = makeSelectionPayload(text: text, token: "")

        let result = await service.improveSelectedText(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
    }

    func testVariantsValidationFailsForInvalidRange() async {
        let service = makeService()
        let text = validText
        let selection = makeSelectionPayload(
            text: text,
            range: NSRange(location: 0, length: (text as NSString).length + 5)
        )

        let result = await service.generateVariants(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
    }

    func testSummarizeSuccessReturnsNonEmptyPayload() async {
        let service = makeService(summarize: { _ in "This is a compact summary." })
        let text = validText
        let selection = makeSelectionPayload(text: text)

        let result = await service.summarizeSelectedText(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .success)
        XCTAssertEqual(result.payload?.summarizedText, "This is a compact summary.")
        XCTAssertTrue((result.payload?.wordCount ?? 0) > 0)
    }

    func testImproveSuccessReturnsNonEmptyPayload() async {
        let service = makeService(improve: { _, _ in "Improved and clarified text." })
        let text = validText
        let selection = makeSelectionPayload(text: text)

        let result = await service.improveSelectedText(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .success)
        XCTAssertEqual(result.payload?.improvedText, "Improved and clarified text.")
        XCTAssertFalse(result.payload?.improvedText.isEmpty ?? true)
    }

    func testVariantsSuccessCapsPayloadToThreeItems() async {
        let service = makeService(variants: { _, _ in
            DraftVariants(variants: ["One", "Two", "Three", "Four", "Five"])
        })
        let text = validText
        let selection = makeSelectionPayload(text: text)

        let result = await service.generateVariants(text: text, selection: selection, article: makeArticle())

        XCTAssertEqual(result.state, .success)
        XCTAssertEqual(result.payload?.variants.count, 3)
    }
}
