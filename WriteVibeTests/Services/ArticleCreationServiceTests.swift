import Testing
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct ArticleCreationServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    @Test func testCreateArticleSeedsCanonicalDefaults() throws {
        let context = try makeContext()
        let service = ArticleCreationService()

        let article = try service.createArticle(
            ArticleCreationRequest(
                title: "",
                subtitle: "Subtitle",
                topic: "Topic",
                tone: .technical,
                targetLength: .long
            ),
            context: context
        )

        #expect(article.title == "Untitled Article")
        #expect(article.subtitle == "Subtitle")
        #expect(article.topic == "Topic")
        #expect(article.tone == .technical)
        #expect(article.targetLength == .long)
        #expect(article.sortedBlocks.map(\.position) == [0, 1000])
        #expect(article.sortedBlocks.first?.content == "Untitled Article")
        #expect(article.bodyBlocks.count == 1)
        #expect(article.bodyBlocks.first?.content == "")
        #expect(article.drafts.count == 1)
        #expect(article.drafts.first?.title == "Draft 1")
        #expect(article.drafts.first?.content == "Untitled Article")
    }

    @Test func testCreateArticleAttachesSeriesAndAssignsNextPosition() throws {
        let context = try makeContext()
        let service = ArticleCreationService()

        let series = Series(title: "Swift Deep Dives")
        context.insert(series)
        _ = try service.createArticle(title: "Part 1", series: series, context: context)
        let second = try service.createArticle(title: "Part 2", series: series, context: context)

        #expect(second.series?.title == "Swift Deep Dives")
        #expect(second.seriesPosition == 2)
    }
}