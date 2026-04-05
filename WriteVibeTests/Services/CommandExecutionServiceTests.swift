import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct CommandExecutionServiceTests {

    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let conversationId: UUID
        let appState: AppState
        let conversationService: ConversationService
        let services: ServiceContainer
    }

    private func makeHarness(model: AIModel = .ollama) throws -> Harness {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let services = ServiceContainer()
        let appState = AppState(services: services)
        appState.bindModelContextIfNeeded(context)

        let conversation = services.conversationService.create(model: model, modelIdentifier: "test-model", context: context)
        return Harness(
            container: container,
            context: context,
            conversationId: conversation.id,
            appState: appState,
            conversationService: services.conversationService,
            services: services
        )
    }

    private func makeArticle(title: String = "Existing Article") -> Article {
        let article = Article(title: title, subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        article.blocks = [ArticleBlock(type: .heading(level: 1), content: title, position: 0)]
        return article
    }

    @Test func testNonCommandInputReturnsNotACommand() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "write me a launch summary", conversationId: harness.conversationId, context: harness.context)

        guard case .notACommand = outcome else {
            Issue.record("Expected non-command input to bypass command dispatcher")
            return
        }
    }

    @Test func testArticleHelpReturnsSuccessEnvelope() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "/article help", conversationId: harness.conversationId, context: harness.context)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article help to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.namespace == "article")
        #expect(envelope.command.verb == "help")
        #expect(envelope.result?.summary.contains("Article command reference") == true)
        #expect(envelope.result?.nextSuggestedCommand == "/article new")
    }

    @Test func testScriptsNamespaceIsBoundaryRejected() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "/scripts generate outline", conversationId: harness.conversationId, context: harness.context)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /scripts namespace to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-013-DOMAIN_BOUNDARY_REJECTED")
        #expect(envelope.error?.category == .domain)
    }

    @Test func testUnknownNamespaceIsRejectedDeterministically() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "/foo something", conversationId: harness.conversationId, context: harness.context)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected unknown slash namespace to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-003-UNKNOWN_NAMESPACE")
    }

    @Test func testUnterminatedQuoteReturnsDeterministicParseError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "/article set title \"Missing end", conversationId: harness.conversationId, context: harness.context)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected unterminated quote to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-006-UNTERMINATED_QUOTE")
        #expect(envelope.error?.hint == "Close the quote and retry")
    }

    @Test func testOutlineReplaceRequiresConfirmFlag() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(input: "/article outline replace 2 \"Refined\"", conversationId: harness.conversationId, context: harness.context)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected outline replace without confirm to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-009-CONFIRMATION_REQUIRED")
    }

    @Test func testAppStateInterceptsSlashCommandWithoutGeneration() throws {
        let harness = try makeHarness()

        let sent = harness.appState.send("/article help", in: harness.conversationId)
        #expect(sent)
        #expect(harness.appState.thinkingId == nil)

        let conversation = try #require(harness.conversationService.fetch(harness.conversationId, context: harness.context))
        #expect(conversation.messages.count >= 2)

        let assistant = try #require(conversation.messages.reversed().first { message in
            message.role == .assistant
        })
        #expect(assistant.role == .assistant)
        #expect(assistant.content.contains("Article command reference") == true)
        #expect(assistant.content.contains("Next: /article new") == true)
        #expect(assistant.content.contains("```json") == false)
    }

    @Test func testAppStateNonCommandStillBypassesCommandEnvelope() throws {
        let harness = try makeHarness()

        let sent = harness.appState.send("hello world", in: harness.conversationId)
        #expect(sent)

        let conversation = try #require(harness.conversationService.fetch(harness.conversationId, context: harness.context))
        #expect(conversation.messages.first?.content == "hello world")
        #expect(!(conversation.messages.last?.content.contains("Command execution result") ?? false))
    }

    // MARK: - Draft Session Lifecycle Tests

    @Test func testArticleNewStartsDraftSession() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let draftContext = CommandExecutionService.DraftContext(isActive: false, draftFields: [:])
        let outcome = service.dispatch(input: "/article new", conversationId: harness.conversationId, context: harness.context, draftContext: draftContext)

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article new to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "new")
        #expect(envelope.draftAction == "start")
        #expect(envelope.result?.summary.contains("Share a short summary") == true)
        #expect(envelope.result?.nextSuggestedCommand?.contains("article summary") == true)
    }

    @Test func testArticleSetMutatesDraftFields() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let activeDraft = CommandExecutionService.DraftContext(isActive: true, draftFields: [:])
        let outcome = service.dispatch(
            input: "/article set title \"My Article\"",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: activeDraft
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article set to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "set")
        #expect(envelope.draftAction == "set:title=My Article")
        #expect(envelope.result?.summary.contains("title") == true)
        #expect(envelope.result?.summary.contains("My Article") == true)
    }

    @Test func testArticleSetWithoutDraftReturnsStateError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let noDraft = CommandExecutionService.DraftContext(isActive: false, draftFields: [:])
        let outcome = service.dispatch(
            input: "/article set title \"Test\"",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: noDraft,
            articleContext: CommandExecutionService.ArticleContext(hasArticleContext: false, articleId: nil, articleTitle: nil)
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article set without draft to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-010-STATE_ERROR")
        #expect(envelope.error?.category == .state)
        #expect(envelope.error?.message.contains("No active draft or article context") == true)
        #expect(envelope.error?.hint == "/article new or open an article")
    }

    @Test func testArticleSetWithArticleContextReturnsArticleMutation() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService
        let article = makeArticle(title: "Current")
        harness.context.insert(article)
        try harness.context.save()

        let outcome = service.dispatch(
            input: "/article update audience \"Technical leaders\"",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: CommandExecutionService.DraftContext(isActive: false, draftFields: [:]),
            articleContext: CommandExecutionService.ArticleContext(
                hasArticleContext: true,
                articleId: article.id.uuidString,
                articleTitle: article.title
            )
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article update with article context to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "update")
        #expect(envelope.target?.articleId == article.id.uuidString)
        #expect(envelope.target?.articleTitle == "Current")
        #expect(envelope.mutation?.domain == .article)
        #expect(envelope.articleMutation == CommandEnvelopeArticleMutation(field: "audience", value: "Technical leaders"))
    }

    @Test func testArticleSetWithUnavailableArticleContextReturnsStateError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(
            input: "/article set title \"Recovered\"",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: CommandExecutionService.DraftContext(isActive: false, draftFields: [:]),
            articleContext: CommandExecutionService.ArticleContext(hasArticleContext: true, articleId: nil, articleTitle: nil)
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected stale article context to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-010-STATE_ERROR")
        #expect(envelope.error?.message.contains("Current article context is unavailable") == true)
    }

    @Test func testArticleSetWithInvalidToneReturnsValidationError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let outcome = service.dispatch(
            input: "/article set tone \"Loud\"",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: CommandExecutionService.DraftContext(isActive: false, draftFields: [:]),
            articleContext: CommandExecutionService.ArticleContext(hasArticleContext: true, articleId: UUID().uuidString, articleTitle: "Current")
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected invalid tone value to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-011-VALIDATION_FAILED")
        #expect(envelope.error?.message.contains("Invalid value for field 'tone'") == true)
    }

    @Test func testArticleCreateValidatesRequiredFields() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let draftNoTitle = CommandExecutionService.DraftContext(isActive: true, draftFields: [:])
        let outcome = service.dispatch(
            input: "/article create",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: draftNoTitle
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article create to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-011-VALIDATION_FAILED")
        #expect(envelope.error?.message.contains("title is required") == true)
    }

    @Test func testArticleCreateSucceedsWithTitle() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let draftWithTitle = CommandExecutionService.DraftContext(
            isActive: true,
            draftFields: ["title": "My Great Article"]
        )
        let outcome = service.dispatch(
            input: "/article create",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: draftWithTitle
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article create to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "create")
        #expect(envelope.draftAction == "create")
        #expect(envelope.result?.summary.contains("My Great Article") == true)
        #expect(envelope.target?.scope == "article")
    }

    @Test func testArticleCreateAcceptsFreeformTitleWhenDraftTitleMissing() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let draftNoTitle = CommandExecutionService.DraftContext(
            isActive: true,
            draftFields: ["topic": "AI"]
        )
        let outcome = service.dispatch(
            input: "/article create i need to write an article about swift concurrency",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: draftNoTitle
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected freeform /article create to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "create")
        #expect(envelope.draftAction == "create:title=i need to write an article about swift concurrency")
        #expect(envelope.target?.articleTitle == "i need to write an article about swift concurrency")
        #expect(envelope.error == nil)
    }

    @Test func testArticleCreateFreeformDoesNotOverrideExistingDraftTitle() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let draftWithTitle = CommandExecutionService.DraftContext(
            isActive: true,
            draftFields: ["title": "Explicit Title"]
        )
        let outcome = service.dispatch(
            input: "/article create rough working note",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: draftWithTitle
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article create with existing title to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.draftAction == "create")
        #expect(envelope.target?.articleTitle == "Explicit Title")
    }

    @Test func testArticleCreateWithoutDraftReturnsStateError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let noDraft = CommandExecutionService.DraftContext(isActive: false, draftFields: [:])
        let outcome = service.dispatch(
            input: "/article create",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: noDraft
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article create without draft to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-010-STATE_ERROR")
    }

    @Test func testArticleCancelClearsDraftSession() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let activeDraft = CommandExecutionService.DraftContext(isActive: true, draftFields: ["title": "Test"])
        let outcome = service.dispatch(
            input: "/article cancel",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: activeDraft
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article cancel to be handled")
            return
        }

        #expect(envelope.ok)
        #expect(envelope.command.verb == "cancel")
        #expect(envelope.draftAction == "cancel")
        #expect(envelope.result?.summary.contains("cancelled") == true)
    }

    @Test func testArticleCancelWithoutDraftReturnsStateError() throws {
        let harness = try makeHarness()
        let service = harness.appState.services.commandExecutionService

        let noDraft = CommandExecutionService.DraftContext(isActive: false, draftFields: [:])
        let outcome = service.dispatch(
            input: "/article cancel",
            conversationId: harness.conversationId,
            context: harness.context,
            draftContext: noDraft
        )

        guard case .handled(let envelope) = outcome else {
            Issue.record("Expected /article cancel without draft to be handled")
            return
        }

        #expect(!envelope.ok)
        #expect(envelope.error?.code == "CMD-010-STATE_ERROR")
        #expect(envelope.error?.message.contains("No active draft session to cancel") == true)
    }

    // MARK: - AppState Draft Lifecycle Integration Tests

    @Test func testAppStateIntegrationArticleNewStartsDraft() throws {
        let harness = try makeHarness()

        let sent = harness.appState.send("/article new", in: harness.conversationId)
        #expect(sent)
        #expect(harness.appState.activeDraft != nil)
        #expect(harness.appState.activeDraft?.title.isEmpty == true)
    }

    @Test func testAppStateIntegrationArticleSetMutatesDraft() throws {
        let harness = try makeHarness()

        // Start draft
        let sentNew = harness.appState.send("/article new", in: harness.conversationId)
        #expect(sentNew)
        #expect(harness.appState.activeDraft != nil)

        // Set title
        let sentSet = harness.appState.send("/article set title \"Test Article\"", in: harness.conversationId)
        #expect(sentSet)
        #expect(harness.appState.activeDraft?.title == "Test Article")

        // Set audience
        let sentAudience = harness.appState.send("/article set audience \"Tech Readers\"", in: harness.conversationId)
        #expect(sentAudience)
        #expect(harness.appState.activeDraft?.audience == "Tech Readers")
    }

    @Test func testAppStateIntegrationArticleCreatePersistsArticle() throws {
        let harness = try makeHarness()

        // Start draft and set required fields
        _ = harness.appState.send("/article new", in: harness.conversationId)
        _ = harness.appState.send("/article set title \"Tech Article\"", in: harness.conversationId)
        _ = harness.appState.send("/article set topic \"Machine Learning\"", in: harness.conversationId)

        // Create article
        let sentCreate = harness.appState.send("/article create", in: harness.conversationId)
        #expect(sentCreate)

        // Verify draft is cleared
        #expect(harness.appState.activeDraft == nil)

        // Verify article was persisted
        let articles = try harness.context.fetch(FetchDescriptor<Article>())
        let created = articles.first { $0.title == "Tech Article" }
        #expect(created != nil)
        #expect(created?.topic == "Machine Learning")
    }

    @Test func testAppStateIntegrationArticleCreatePersistsFreeformTitle() throws {
        let harness = try makeHarness()

        _ = harness.appState.send("/article new", in: harness.conversationId)

        let sentCreate = harness.appState.send("/article create write an onboarding guide for distributed systems", in: harness.conversationId)
        #expect(sentCreate)
        #expect(harness.appState.activeDraft == nil)

        let articles = try harness.context.fetch(FetchDescriptor<Article>())
        let created = articles.first { $0.title == "write an onboarding guide for distributed systems" }
        #expect(created != nil)
    }

    @Test func testAppStateIntegrationArticleCancelClearsDraft() throws {
        let harness = try makeHarness()

        // Start draft
        _ = harness.appState.send("/article new", in: harness.conversationId)
        #expect(harness.appState.activeDraft != nil)

        // Set some fields
        _ = harness.appState.send("/article set title \"To Cancel\"", in: harness.conversationId)
        #expect(harness.appState.activeDraft?.title == "To Cancel")

        // Cancel
        let sentCancel = harness.appState.send("/article cancel", in: harness.conversationId)
        #expect(sentCancel)
        #expect(harness.appState.activeDraft == nil)
    }

    @Test func testAppStateIntegrationArticleUpdateMutatesCurrentArticle() throws {
        let harness = try makeHarness()
        let article = makeArticle(title: "Current")
        harness.context.insert(article)
        try harness.context.save()
        harness.appState.setCurrentArticle(article.id)

        let sent = harness.appState.send("/article update tone \"Technical\"", in: harness.conversationId)

        #expect(sent)
        let updated = try #require((try harness.context.fetch(FetchDescriptor<Article>())).first { $0.id == article.id })
        #expect(updated.tone == .technical)
        #expect(updated.updatedAt != updated.createdAt)
    }

    @Test func testAppStateIntegrationArticleUpdateKeepsTitleBlockInSync() throws {
        let harness = try makeHarness()
        let article = makeArticle(title: "Original")
        harness.context.insert(article)
        try harness.context.save()
        harness.appState.setCurrentArticle(article.id)

        let sent = harness.appState.send("/article set title \"Renamed\"", in: harness.conversationId)

        #expect(sent)
        let storedArticle = try #require((try harness.context.fetch(FetchDescriptor<Article>())).first { $0.id == article.id })
        #expect(storedArticle.title == "Renamed")
        #expect(storedArticle.sortedBlocks.first?.content == "Renamed")
    }

    @Test func testAppStateIntegrationUnavailableCurrentArticleShowsError() throws {
        let harness = try makeHarness()
        harness.appState.setCurrentArticle(UUID())

        let sent = harness.appState.send("/article set audience \"Builders\"", in: harness.conversationId)
        #expect(sent)

        let conversation = try #require(harness.conversationService.fetch(harness.conversationId, context: harness.context))
        let assistant = try #require(conversation.messages.reversed().first { message in
            message.role == .assistant
        })
        #expect(assistant.role == .assistant)
        #expect(assistant.content.contains("Current article context is unavailable") == true)
        #expect(assistant.content.contains("Try: Open the target article and retry") == true)
        #expect(assistant.content.contains("```json") == false)
    }

    @Test func testAppStateIntegrationSetWithoutDraftShowsError() throws {
        let harness = try makeHarness()

        // Try set without starting draft
        let sent = harness.appState.send("/article set title \"Test\"", in: harness.conversationId)
        #expect(sent)

        // Verify error message was added
        let conversation = try #require(harness.conversationService.fetch(harness.conversationId, context: harness.context))
        let assistant = try #require(conversation.messages.reversed().first { message in
            message.role == .assistant
        })
        #expect(assistant.role == .assistant)
        #expect(assistant.content.contains("No active draft or article context") == true)
        #expect(assistant.content.contains("Try: /article new or open an article") == true)
        #expect(assistant.content.contains("```json") == false)
    }
}

