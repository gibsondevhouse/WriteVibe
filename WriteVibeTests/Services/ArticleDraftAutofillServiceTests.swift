import Testing
@testable import WriteVibe

struct ArticleDraftAutofillServiceTests {

    @Test func testDeterministicOutputsForCityEconomySummary() {
        let service = ArticleDraftAutofillService()
        let summary = "The article is about remote work reshaping city economies through commute declines and neighborhood spending gains, giving local businesses a playbook for adaptation"

        let result = service.autofill(from: summary)

        #expect(result.title == "Remote Work Reshaping City Economies Through Commute Declines")
        #expect(result.subtitle == "What changes: giving local businesses a playbook for adaptation")
    }

    @Test func testDeterministicOutputsForAISafetySummary() {
        let service = ArticleDraftAutofillService()
        let summary = "\n\tThis article explores   AI safety in healthcare!!!   It focuses on practical safeguards.  "

        let result = service.autofill(from: summary)

        #expect(result.title == "AI Safety in Healthcare")
        #expect(result.subtitle == "In practice: It focuses on practical safeguards")
    }

    @Test func testRepetitiveSummaryProducesDistinctTitleAndSubtitle() {
        let service = ArticleDraftAutofillService()
        let summary = "the article is about the social-economic effects of mass incarceration and policy choices"

        let result = service.autofill(from: summary)

        let title = result.title ?? ""
        let subtitle = result.subtitle ?? ""

        #expect(!title.isEmpty)
        #expect(!subtitle.isEmpty)
        #expect(title.lowercased() != subtitle.lowercased())
        #expect(!subtitle.lowercased().contains(title.lowercased()))
        #expect(!title.lowercased().hasPrefix("the article is about"))
        #expect(!subtitle.lowercased().hasPrefix("the article is about"))
    }

    @Test func testArticleLikeSummaryProducesPublishableLengthsAndComplementarySubheadline() {
        let service = ArticleDraftAutofillService()
        let summary = "This article discusses supply chain software that reduces stockouts for independent pharmacies. It explains rollout bottlenecks, staffing constraints, and the metrics operators can track in the first 90 days."

        let result = service.autofill(from: summary)

        let title = result.title ?? ""
        let subtitle = result.subtitle ?? ""

        #expect(!title.isEmpty)
        #expect(!subtitle.isEmpty)
        #expect(title.split(separator: " ").count <= 8)
        #expect(title.count <= 68)
        #expect(subtitle.count <= 120)
        #expect(subtitle.contains(":"))
        #expect(!subtitle.lowercased().contains(title.lowercased()))
    }

    @Test func testNoGenericFillerLeadingPatterns() {
        let service = ArticleDraftAutofillService()
        let summary = "In this article, this article is about practical climate adaptation planning for flood-prone neighborhoods and municipal budgeting tradeoffs."

        let result = service.autofill(from: summary)

        let title = result.title ?? ""
        let subtitle = result.subtitle ?? ""

        #expect(!title.lowercased().hasPrefix("the article"))
        #expect(!title.lowercased().hasPrefix("this article"))
        #expect(!title.lowercased().hasPrefix("in this article"))
        #expect(!subtitle.lowercased().hasPrefix("the article"))
        #expect(!subtitle.lowercased().hasPrefix("this article"))
        #expect(!subtitle.lowercased().hasPrefix("in this article"))
    }
}
