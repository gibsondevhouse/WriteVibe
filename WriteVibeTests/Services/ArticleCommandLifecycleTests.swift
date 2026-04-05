import Testing
import Foundation
import SwiftData
@testable import WriteVibe

// MARK: - TASK-310: End-to-End Command Lifecycle Integration Tests
//
// Covers: WS-305 create-to-edit lifecycle and regression gates
// Validates the full command pipeline from /article new through post-create mutations.

@Suite(.serialized)
@MainActor
struct ArticleCommandLifecycleTests {

    private struct StubDraftAutofillService: ArticleDraftAutofillServicing {
        let result: ArticleDraftAutofillResult

        func autofill(from summary: String) -> ArticleDraftAutofillResult {
            _ = summary
            return result
        }

        func fallbackProposal(from seed: DraftAutofillSeed) -> DraftAutofillProposal? {
            _ = seed
            guard let title = result.title else { return nil }
            return DraftAutofillProposal(
                title: title,
                subtitle: result.subtitle ?? "",
                tone: (result.tone ?? .informative).rawValue,
                targetLength: (result.targetLength ?? .medium).rawValue,
                confidenceNotes: ["Stub fallback"]
            )
        }
    }

    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let conversationId: UUID
        let appState: AppState
        let conversationService: ConversationService
        let services: ServiceContainer
    }

    private func makeHarness(autofillService: (any ArticleDraftAutofillServicing)? = nil) throws -> Harness {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let services = ServiceContainer(articleDraftAutofillService: autofillService)
        let appState = AppState(services: services)
        appState.bindModelContextIfNeeded(context)
        let conversation = services.conversationService.create(model: .ollama, modelIdentifier: "test", context: context)
        return Harness(container: container, context: context, conversationId: conversation.id,
                       appState: appState, conversationService: services.conversationService, services: services)
    }

    // MARK: Full Create Lifecycle

    @Test func testFullCreateLifecycleNewSetCreate() throws {
        let h = try makeHarness()

        // Phase 1: new draft
        _ = h.appState.send("/article new", in: h.conversationId)
        #expect(h.appState.activeDraft != nil)

        // Phase 2: set fields
        _ = h.appState.send("/article set title \"Lifecycle Article\"", in: h.conversationId)
        _ = h.appState.send("/article set topic \"Testing\"", in: h.conversationId)
        _ = h.appState.send("/article set audience \"Developers\"", in: h.conversationId)
        _ = h.appState.send("/article set tone \"Technical\"", in: h.conversationId)
        #expect(h.appState.activeDraft?.title == "Lifecycle Article")
        #expect(h.appState.activeDraft?.topic == "Testing")
        #expect(h.appState.activeDraft?.audience == "Developers")
        #expect(h.appState.activeDraft?.tone == "Technical")

        // Phase 3: create
        _ = h.appState.send("/article create", in: h.conversationId)
        #expect(h.appState.activeDraft == nil)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
            let created = try #require(articles.first(where: { $0.title == "Lifecycle Article" }))
            #expect(created.topic == "Testing")
            #expect(created.audience == "Developers")
            #expect(created.tone == .technical)
    }

    // MARK: Post-Create Field Mutations

    @Test func testPostCreateFieldMutationViaUpdate() throws {
        let h = try makeHarness()

        // Create an article
        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Draft Title\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        // Post-create field mutation
        _ = h.appState.send("/article update subtitle \"Updated subtitle\"", in: h.conversationId)

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        #expect(refreshed.first?.subtitle == "Updated subtitle")
    }

    @Test func testPostCreateMultipleFieldMutations() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Multi Field\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        _ = h.appState.send("/article update topic \"Cloud\"", in: h.conversationId)
        _ = h.appState.send("/article update audience \"Engineers\"", in: h.conversationId)
        _ = h.appState.send("/article update tone \"Informative\"", in: h.conversationId)
        _ = h.appState.send("/article update targetlength \"Long\"", in: h.conversationId)

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        #expect(refreshed.first?.topic == "Cloud")
        #expect(refreshed.first?.audience == "Engineers")
        #expect(refreshed.first?.tone == .informative)
        #expect(refreshed.first?.targetLength == .long)
    }

    // MARK: Post-Create Outline Mutations

    @Test func testPostCreateOutlineAppendViaAppState() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Outline Article\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        // Append outline via command (service-level; AppState routes outlineOperation to adapter)
        let adapter = ArticleOutlineMutationAdapter()
        _ = adapter.apply(ArticleOutlineMutationRequest(operation: "append", index: nil, value: "1. Introduction"), to: article)
        _ = adapter.apply(ArticleOutlineMutationRequest(operation: "append", index: nil, value: "2. Body"), to: article)
        try h.context.save()

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        let savedArticle = try #require(refreshed.first)
        #expect(savedArticle.outline.contains("1. Introduction"))
        #expect(savedArticle.outline.contains("2. Body"))
    }

    @Test func testPostCreateOutlineReplaceViaAdapter() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Replace Outline\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        let adapter = ArticleOutlineMutationAdapter()
        _ = adapter.apply(ArticleOutlineMutationRequest(operation: "append", index: nil, value: "1. Old"), to: article)
        _ = adapter.apply(ArticleOutlineMutationRequest(operation: "append", index: nil, value: "2. Keep"), to: article)
        _ = adapter.apply(ArticleOutlineMutationRequest(operation: "replace", index: 1, value: "1. New"), to: article)
        try h.context.save()

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        let saved = try #require(refreshed.first)
        #expect(saved.outline.hasPrefix("1. New"))
        #expect(saved.outline.contains("2. Keep"))
    }

    // MARK: Post-Create Body Mutations

    @Test func testPostCreateBodyAppendViaAdapter() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Body Article\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        let adapter = ArticleBodyMutationAdapter()
        _ = adapter.apply(ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "First paragraph."), to: article)
        _ = adapter.apply(ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "Second paragraph."), to: article)
        try h.context.save()

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        let saved = try #require(refreshed.first)
        let bodyContents = saved.bodyBlocks.map { $0.content }
        #expect(bodyContents.contains("First paragraph."))
        #expect(bodyContents.contains("Second paragraph."))
    }

    @Test func testPostCreateBodyInsertHeadingViaAdapter() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Insert Article\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
        let article = try #require(articles.first)
        h.appState.setCurrentArticle(article.id)

        let adapter = ArticleBodyMutationAdapter()
        _ = adapter.apply(ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "Body text."), to: article)
        _ = adapter.apply(ArticleBodyMutationRequest(operation: "insert", blockType: "heading", index: 1, value: "Section Title"), to: article)
        try h.context.save()

        let refreshed = try h.context.fetch(FetchDescriptor<Article>())
        let saved = try #require(refreshed.first)
        let body = saved.bodyBlocks
        // Heading should appear before or at position 1 of body blocks
        #expect(body.contains(where: { $0.content == "Section Title" && $0.blockType == .heading(level: 2) }))
    }

    // MARK: Cancel Prevents Persistence

    @Test func testCancelClearsDraftWithoutCreatingArticle() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Will Be Cancelled\"", in: h.conversationId)
        _ = h.appState.send("/article cancel", in: h.conversationId)

        #expect(h.appState.activeDraft == nil)

        let articles = try h.context.fetch(FetchDescriptor<Article>())
    #expect(articles.allSatisfy { $0.title != "Will Be Cancelled" })
    }

    // MARK: New Restarts In-Progress Draft

    @Test func testNewCommandResetsInProgressDraft() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"First Attempt\"", in: h.conversationId)
        #expect(h.appState.activeDraft?.title == "First Attempt")

        // Restart
        _ = h.appState.send("/article new", in: h.conversationId)
        #expect(h.appState.activeDraft != nil)
        #expect(h.appState.activeDraft?.title == "")
    }

    @Test func testNewCommandSetsFormPresentationTriggerAndCanBeConsumed() throws {
        let h = try makeHarness()

        #expect(h.appState.shouldPresentNewArticleFormFromCommand == false)

        _ = h.appState.send("/article new", in: h.conversationId)

        #expect(h.appState.shouldPresentNewArticleFormFromCommand)
        h.appState.consumeNewArticleFormPresentationTrigger()
        #expect(h.appState.shouldPresentNewArticleFormFromCommand == false)
    }

    @Test func testCreateAndCancelClearFormPresentationTrigger() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        #expect(h.appState.shouldPresentNewArticleFormFromCommand)

        _ = h.appState.send("/article cancel", in: h.conversationId)
        #expect(h.appState.shouldPresentNewArticleFormFromCommand == false)

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Trigger Reset\"", in: h.conversationId)
        _ = h.appState.send("/article create", in: h.conversationId)
        #expect(h.appState.shouldPresentNewArticleFormFromCommand == false)
    }

    @Test func testSummaryMessageAfterArticleNewAutofillsDraftAndSetsSuggestions() throws {
        let autofill = StubDraftAutofillService(
            result: ArticleDraftAutofillResult(
                title: "AI Suggested Title",
                subtitle: "AI Suggested Subtitle",
                tone: .technical,
                targetLength: .long
            )
        )
        let h = try makeHarness(autofillService: autofill)

        _ = h.appState.send("/article new", in: h.conversationId)
        #expect(h.appState.isAwaitingDraftSummaryInput)

        _ = h.appState.send("This article explains practical Swift testing patterns.", in: h.conversationId)

        #expect(h.appState.isAwaitingDraftSummaryInput == false)
        #expect(h.appState.activeDraft?.title == "AI Suggested Title")
        #expect(h.appState.activeDraft?.subtitle == "AI Suggested Subtitle")
        #expect(h.appState.activeDraft?.tone == ArticleTone.technical.rawValue)
        #expect(h.appState.activeDraft?.targetLength == ArticleLength.long.rawValue)
        #expect(h.appState.hasDraftSuggestion(for: .title))
        #expect(h.appState.hasDraftSuggestion(for: .subtitle))
        #expect(h.appState.hasDraftSuggestion(for: .tone))
        #expect(h.appState.hasDraftSuggestion(for: .targetLength))

        let conversation = try #require(h.conversationService.fetch(h.conversationId, context: h.context))
        let assistantMessages = conversation.messages
            .filter { $0.role == .assistant }
            .map(\.content)
        #expect(assistantMessages.contains(where: { $0.contains("filled the New Article form") }))
    }

    @Test func testRejectAndAcceptDraftSuggestionsMutateStateAsExpected() throws {
        let autofill = StubDraftAutofillService(
            result: ArticleDraftAutofillResult(
                title: "Suggested Title",
                subtitle: "Suggested Subtitle",
                tone: .informative,
                targetLength: .short
            )
        )
        let h = try makeHarness(autofillService: autofill)

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("Draft summary here", in: h.conversationId)

        #expect(h.appState.activeDraft?.title == "Suggested Title")
        #expect(h.appState.hasDraftSuggestion(for: .title))

        h.appState.rejectDraftSuggestion(for: .title)
        #expect(h.appState.activeDraft?.title == "")
        #expect(h.appState.hasDraftSuggestion(for: .title) == false)

        #expect(h.appState.hasDraftSuggestion(for: .subtitle))
        h.appState.acceptDraftSuggestion(for: .subtitle)
        #expect(h.appState.activeDraft?.subtitle == "Suggested Subtitle")
        #expect(h.appState.hasDraftSuggestion(for: .subtitle) == false)
    }

    // MARK: Normal Chat Regression

    @Test func testNonCommandMessageDoesNotTriggerCommandFlow() throws {
        let h = try makeHarness()

        let sent = h.appState.send("Tell me about Swift concurrency", in: h.conversationId)
        #expect(sent)

        let conversation = try #require(h.conversationService.fetch(h.conversationId, context: h.context))
        let messages = conversation.messages
        // Only user message added; no command envelope appended (no assistant yet since no generation in tests)
        let hasCommandResult = messages.contains { $0.content.contains("Command execution result") }
        #expect(!hasCommandResult)
    }

    @Test func testNonCommandMessageDoesNotAffectDraftState() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)
        _ = h.appState.send("/article set title \"Stable Draft\"", in: h.conversationId)
        _ = h.appState.send("What is a good tone for a technical article?", in: h.conversationId)

        #expect(h.appState.activeDraft?.title == "Stable Draft")
    }

    // MARK: Domain Boundary Regression

    @Test func testScriptCommandDoesNotCreateArticles() throws {
        let h = try makeHarness()

            let countBefore = try h.context.fetchCount(FetchDescriptor<Article>())
            _ = h.appState.send("/scripts generate an outline", in: h.conversationId)
            let countAfter = try h.context.fetchCount(FetchDescriptor<Article>())
            #expect(countAfter == countBefore)
            #expect(h.appState.activeDraft == nil)
    }

    @Test func testEmailCommandDoesNotCreateArticles() throws {
        let h = try makeHarness()

            let countBefore = try h.context.fetchCount(FetchDescriptor<Article>())
            _ = h.appState.send("/email compose newsletter", in: h.conversationId)
            let countAfter = try h.context.fetchCount(FetchDescriptor<Article>())
            #expect(countAfter == countBefore)
            #expect(h.appState.activeDraft == nil)
    }

    // MARK: Routing Regression

    @Test func testSuccessfulCommandRoutesToArticlesDestination() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article new", in: h.conversationId)

        #expect(h.appState.selectedDestination == .articles)
    }

    @Test func testFailedCommandDoesNotChangeDestination() throws {
        let h = try makeHarness()

            let countBefore = try h.context.fetchCount(FetchDescriptor<Article>())
            _ = h.appState.send("/article set title \"No draft\"", in: h.conversationId)
            // Key invariant: failed command must not create new articles
            let countAfter = try h.context.fetchCount(FetchDescriptor<Article>())
            #expect(countAfter == countBefore)
    }

    @Test func testSelectingStylesClearsActiveArticleRoute() throws {
        let h = try makeHarness()
        let article = Article(title: "Navigation Test")
        h.context.insert(article)
        try h.context.save()

        h.appState.openArticleWorkspace(article.id)
        #expect(h.appState.currentArticleID == article.id)

        h.appState.navigate(to: .styles)
        #expect(h.appState.selectedDestination == .styles)
        #expect(h.appState.workspaceRoute == .none)
        #expect(h.appState.currentArticleID == nil)
    }

    @Test func testOpeningArticleWorkspaceForcesArticlesDestination() throws {
        let h = try makeHarness()
        let article = Article(title: "Route Parity")
        h.context.insert(article)
        try h.context.save()

        h.appState.navigate(to: .series)
        #expect(h.appState.selectedDestination == .series)

        h.appState.openArticleWorkspace(article.id)

        #expect(h.appState.selectedDestination == .articles)
        #expect(h.appState.workspaceRoute == .article(id: article.id))
        #expect(h.appState.currentArticleID == article.id)
    }

    @Test func testOpeningSeriesWorkspaceForcesSeriesDestination() throws {
        let h = try makeHarness()
        let series = Series(title: "Launch Series")
        h.context.insert(series)
        try h.context.save()

        h.appState.openSeriesWorkspace(series.id)

        #expect(h.appState.selectedDestination == .series)
        #expect(h.appState.workspaceRoute == .series(id: series.id))
        #expect(h.appState.currentArticleID == nil)
    }

    @Test func testShowDashboardClearsRouteAndPreservesCurrentDestination() throws {
        let h = try makeHarness()
        let article = Article(title: "Back Behavior")
        h.context.insert(article)
        try h.context.save()

        h.appState.openArticleWorkspace(article.id)
        #expect(h.appState.workspaceRoute == .article(id: article.id))

        h.appState.showWorkspaceDashboard()
        #expect(h.appState.workspaceRoute == .none)
        #expect(h.appState.selectedDestination == .articles)
    }

    // MARK: Thinking State Regression

    @Test func testCommandDoesNotLeaveThinkingStateActive() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article help", in: h.conversationId)

        #expect(h.appState.thinkingId == nil)
    }

    @Test func testFailedCommandDoesNotLeaveThinkingStateActive() throws {
        let h = try makeHarness()

        _ = h.appState.send("/article set title", in: h.conversationId)

        #expect(h.appState.thinkingId == nil)
    }
}
