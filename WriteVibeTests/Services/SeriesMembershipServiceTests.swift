import Testing
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct SeriesMembershipServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    @Test func testNextPositionReturnsSequentialValue() throws {
        let context = try makeContext()
        let service = SeriesMembershipService()
        let series = Series(title: "Engineering Notes")
        context.insert(series)

        let first = Article(title: "Part 1", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        first.series = series
        first.seriesPosition = 1
        let second = Article(title: "Part 2", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        second.series = series
        second.seriesPosition = 2

        context.insert(first)
        context.insert(second)
        try context.save()

        #expect(service.nextPosition(in: series) == 3)
    }

    @Test func testAttachAssignsSeriesAndPosition() throws {
        let service = SeriesMembershipService()
        let series = Series(title: "Swift Deep Dives")

        let existing = Article(title: "Part 1", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        existing.series = series
        existing.seriesPosition = 1

        let candidate = Article(title: "Part 2", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        service.attach(candidate, to: series)

        #expect(candidate.series?.title == "Swift Deep Dives")
        #expect(candidate.seriesPosition == 2)
    }
}
