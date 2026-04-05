import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct MessagePersistenceAdapterTests {

    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
        let conversationService: ConversationService
        let conversationID: UUID
    }

    @Test func testBeginAssistantMessageThrowsWhenConversationIsMissing() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)
        let missingRun = GenerationRunContext(conversationId: UUID(), modelName: "model", context: fixture.context)

        do {
            _ = try adapter.beginAssistantMessage(run: missingRun)
            Issue.record("Expected missingConversation error")
        } catch let error as MessagePersistenceError {
            #expect(error == .missingConversation)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testBeginAssistantMessageCreatesPlaceholderMessage() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)
        let run = GenerationRunContext(conversationId: fixture.conversationID, modelName: "model-a", context: fixture.context)

        _ = try adapter.beginAssistantMessage(run: run)

        let conversation = try #require(fixture.conversationService.fetch(fixture.conversationID, context: fixture.context))
        #expect(conversation.messages.count == 2)
        let assistantMessage = try #require(conversation.messages.last(where: { $0.role == .assistant }))
        #expect(assistantMessage.content == "")
        #expect(assistantMessage.modelUsed == "model-a")
    }

    @Test func testAppendTokenThrowsForUnknownHandle() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)

        do {
            try adapter.appendToken("A", handle: MessageHandle(id: UUID()))
            Issue.record("Expected invalidHandle error")
        } catch let error as MessagePersistenceError {
            #expect(error == .invalidHandle)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testFinalizeThrowsForUnknownHandle() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)

        do {
            try adapter.finalize(handle: MessageHandle(id: UUID()), outcome: .succeeded)
            Issue.record("Expected invalidHandle error")
        } catch let error as MessagePersistenceError {
            #expect(error == .invalidHandle)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testFinalizePersistsTokenCountAndConversationTimestamp() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)
        let run = GenerationRunContext(conversationId: fixture.conversationID, modelName: "model-a", context: fixture.context)
        let conversation = try #require(fixture.conversationService.fetch(fixture.conversationID, context: fixture.context))
        conversation.updatedAt = .distantPast

        let handle = try adapter.beginAssistantMessage(run: run)
        try adapter.appendToken("abcdefgh", handle: handle)
        try adapter.finalize(handle: handle, outcome: .succeeded)

        let assistant = try #require(conversation.messages.last(where: { $0.role == .assistant }))
        #expect(assistant.content == "abcdefgh")
        #expect(assistant.tokenCount == 2)
        #expect(conversation.updatedAt > .distantPast)
    }

    @Test func testAppendTokenThrowsAfterFinalize() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)
        let run = GenerationRunContext(conversationId: fixture.conversationID, modelName: "model-a", context: fixture.context)

        let handle = try adapter.beginAssistantMessage(run: run)
        try adapter.appendToken("abc", handle: handle)
        try adapter.finalize(handle: handle, outcome: .cancelled)

        do {
            try adapter.appendToken("def", handle: handle)
            Issue.record("Expected invalidHandle error")
        } catch let error as MessagePersistenceError {
            #expect(error == .invalidHandle)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testFinalizeIsIdempotentAfterFirstCompletion() throws {
        let fixture = try makeFixture()
        let adapter = SwiftDataMessagePersistenceAdapter(conversationService: fixture.conversationService)
        let run = GenerationRunContext(conversationId: fixture.conversationID, modelName: "model-a", context: fixture.context)
        let conversation = try #require(fixture.conversationService.fetch(fixture.conversationID, context: fixture.context))

        let handle = try adapter.beginAssistantMessage(run: run)
        try adapter.appendToken("abcd", handle: handle)
        try adapter.finalize(handle: handle, outcome: .failed(NSError(domain: "test", code: 1)))
        try adapter.finalize(handle: handle, outcome: .succeeded)

        #expect(conversation.messages.count == 2)
        #expect(conversation.messages.last(where: { $0.role == .assistant })?.tokenCount == 1)
    }

    @Test func testMessagePersistenceErrorDescriptionsExist() {
        #expect(MessagePersistenceError.missingConversation.errorDescription == "Conversation not found for stream persistence.")
        #expect(MessagePersistenceError.placeholderCreationFailed.errorDescription == "Could not create assistant placeholder message.")
        #expect(MessagePersistenceError.invalidHandle.errorDescription == "Streaming persistence handle is no longer valid.")
        #expect(MessagePersistenceError.contextSaveFailed.errorDescription == "Could not persist streaming message updates.")
    }

    private func makeFixture() throws -> Fixture {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let conversationService = ConversationService()
        let conversation = conversationService.create(model: .ollama, modelIdentifier: "test-model", context: context)
        _ = conversationService.appendMessage(Message(role: .user, content: "Hello"), to: conversation.id, context: context)
        return Fixture(
            container: container,
            context: context,
            conversationService: conversationService,
            conversationID: conversation.id
        )
    }
}