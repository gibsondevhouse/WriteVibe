import Testing
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct ArticleContextMutationAdapterTests {
    private let adapter = ArticleContextMutationAdapter()

    private func makeArticle() -> Article {
        let article = Article(title: "Seed", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        article.blocks = [ArticleBlock(type: .heading(level: 1), content: "Seed", position: 0)]
        return article
    }

    @Test func testAdapterMatrixMutatesAllSupportedCurrentFields() {
        let cases: [(field: String, value: String, assert: (Article) -> Bool)] = [
            ("title", "Renamed", { $0.title == "Renamed" && $0.sortedBlocks.first?.content == "Renamed" }),
            ("subtitle", "Sharper subtitle", { $0.subtitle == "Sharper subtitle" }),
            ("topic", "AI strategy", { $0.topic == "AI strategy" }),
            ("audience", "Product teams", { $0.audience == "Product teams" }),
            ("quicknotes", "Use case notes", { $0.quickNotes == "Use case notes" }),
            ("sourcelinks", "https://example.com", { $0.sourceLinks == "https://example.com" }),
            ("outline", "1. Intro", { $0.outline == "1. Intro" }),
            ("summary", "Big idea", { $0.summary == "Big idea" }),
            ("purpose", "Explain the shift", { $0.purpose == "Explain the shift" }),
            ("style", "Direct", { $0.style == "Direct" }),
            ("keytakeaway", "Clarity matters", { $0.keyTakeaway == "Clarity matters" }),
            ("publishingintent", "Newsletter", { $0.publishingIntent == "Newsletter" }),
            ("tone", "Technical", { $0.tone == .technical }),
            ("targetlength", "Long", { $0.targetLength == .long })
        ]

        for entry in cases {
            let article = makeArticle()
            let request: ArticleContextMutationRequest
            switch adapter.validate(field: entry.field, value: entry.value) {
            case .success(let validatedRequest):
                request = validatedRequest
            case .failure(let error):
                Issue.record("Expected validation success for \(entry.field), got \(error)")
                return
            }

            let result = adapter.apply(request, to: article)
            switch result {
            case .success(let mutationResult):
                #expect(mutationResult.field == request.field)
                #expect(entry.assert(article))
            case .failure(let error):
                Issue.record("Expected apply success for \(entry.field), got \(error)")
                return
            }
        }
    }

    @Test func testAdapterRejectsEmptyTitle() {
        switch adapter.validate(field: "title", value: "   ") {
        case .success:
            Issue.record("Expected empty title to fail validation")
        case .failure(let error):
            #expect(error.code == "CMD-011-VALIDATION_FAILED")
            #expect(error.message.contains("title") == true)
        }
    }

    @Test func testAdapterRejectsInvalidTargetLength() {
        switch adapter.validate(field: "targetlength", value: "Huge") {
        case .success:
            Issue.record("Expected invalid target length to fail validation")
        case .failure(let error):
            #expect(error.code == "CMD-011-VALIDATION_FAILED")
            #expect(error.message.contains("targetlength") == true)
        }
    }

    @Test func testStructuredWorkflowRequestsUseCanonicalKeysOnly() {
        let proposal = AppleStructuredContextSuggestionProposal(
            summary: "Explain the market shift.",
            audience: "Operators",
            purpose: "Clarify tradeoffs",
            style: "Direct",
            keyTakeaway: "Execution matters more than hype.",
            publishingIntent: "Newsletter",
            sourceLinks: "https://example.com/report",
            acceptedFields: []
        )

        switch adapter.structuredWorkflowRequests(from: proposal) {
        case .success(let requests):
            #expect(requests.map(\.field) == ["summary", "audience", "purpose", "style", "keytakeaway", "publishingintent", "sourcelinks"])
        case .failure(let error):
            Issue.record("Expected structured workflow requests to canonicalize fields, got \(error)")
        }
    }

    @Test func testStructuredWorkflowCanonicalFieldRejectsUnsupportedKey() {
        #expect(adapter.canonicalStructuredWorkflowField(for: "title") == nil)
        #expect(adapter.canonicalStructuredWorkflowField(for: "sourceLinks") == "sourcelinks")
    }
}