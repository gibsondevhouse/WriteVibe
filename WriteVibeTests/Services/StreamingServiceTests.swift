//
//  StreamingServiceTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct StreamingServiceTests {

    enum MockStreamError: Error {
        case providerFailure
    }

    struct MockAIProvider: AIStreamingProvider {
        let tokens: [String]

        @MainActor
        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                for token in tokens {
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    struct ThrowingAIProvider: AIStreamingProvider {
        let tokensBeforeError: [String]

        @MainActor
        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                for token in tokensBeforeError {
                    continuation.yield(token)
                }
                continuation.finish(throwing: MockStreamError.providerFailure)
            }
        }
    }

    struct CancellationAIProvider: AIStreamingProvider {
        let tokensBeforeError: [String]

        @MainActor
        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                for token in tokensBeforeError {
                    continuation.yield(token)
                }
                continuation.finish(throwing: CancellationError())
            }
        }
    }

    struct MockSearchContextProvider: SearchContextProviding {
        let result: Result<[SearchResult]?, Error>

        func fetchContext(query: String, searchModel: String) async throws -> [SearchResult]? {
            switch result {
            case .success(let searchResults):
                return searchResults
            case .failure(let error):
                throw error
            }
        }
    }

    enum AdapterOutcome: Equatable {
        case succeeded
        case cancelled
        case failed
    }

    final class RecordingPersistenceAdapter: MessagePersistenceAdapter {
        var beganRuns: [GenerationRunContext] = []
        var appendedChunks: [String] = []
        var finalizedOutcomes: [AdapterOutcome] = []

        func beginAssistantMessage(run: GenerationRunContext) throws -> MessageHandle {
            beganRuns.append(run)
            return MessageHandle(id: UUID())
        }

        func appendToken(_ token: String, handle: MessageHandle) throws {
            appendedChunks.append(token)
        }

        func finalize(handle: MessageHandle, outcome: FinalizationOutcome) throws {
            switch outcome {
            case .succeeded:
                finalizedOutcomes.append(.succeeded)
            case .cancelled:
                finalizedOutcomes.append(.cancelled)
            case .failed:
                finalizedOutcomes.append(.failed)
            }
        }
    }

    private func makeContextAndConversation(model: AIModel = .ollama) throws -> (ModelContext, ConversationService, Conversation) {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let conversationService = ConversationService()
        let conversation = conversationService.create(model: model, modelIdentifier: "test-model", context: context)
        conversationService.appendMessage(Message(role: .user, content: "Hello"), to: conversation.id, context: context)
        return (context, conversationService, conversation)
    }

    @Test func testDefaultAdapterPersistsAssistantMessageOnSuccess() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let provider = MockAIProvider(tokens: ["A", "B", "C", "D", "E"])
        let streamingService = StreamingService(conversationService: conversationService, searchProvider: OpenRouterService())

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: conversation.id,
            context: context
        )

        let updatedConversation = try #require(conversationService.fetch(conversation.id, context: context))
        #expect(updatedConversation.messages.count == 2)
        let assistantMessage = try #require(updatedConversation.messages.last)
        #expect(assistantMessage.role == .assistant)
        #expect(assistantMessage.content == "ABCDE")
        #expect(assistantMessage.tokenCount == 1)
    }

    @Test func testAdapterLifecycleOnSuccess() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let provider = MockAIProvider(tokens: ["A", "B", "C", "D", "E", "F", "G"])
        let adapter = RecordingPersistenceAdapter()
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: conversation.id,
            context: context
        )

        #expect(adapter.beganRuns.count == 1)
        #expect(adapter.appendedChunks == ["ABCDEF", "G"])
        #expect(adapter.finalizedOutcomes == [.succeeded])
    }

    @Test func testAdapterLifecycleOnCancellation() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let provider = CancellationAIProvider(tokensBeforeError: ["partial"])
        let adapter = RecordingPersistenceAdapter()
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        await #expect(throws: CancellationError.self) {
            try await streamingService.streamReply(
                provider: provider,
                modelName: "test-model",
                conversationId: conversation.id,
                context: context
            )
        }

        #expect(adapter.appendedChunks == ["partial"])
        #expect(adapter.finalizedOutcomes == [.cancelled])
    }

    @Test func testAdapterLifecycleOnProviderFailure() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let provider = ThrowingAIProvider(tokensBeforeError: ["partial"])
        let adapter = RecordingPersistenceAdapter()
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        await #expect(throws: MockStreamError.self) {
            try await streamingService.streamReply(
                provider: provider,
                modelName: "test-model",
                conversationId: conversation.id,
                context: context
            )
        }

        #expect(adapter.appendedChunks == ["partial"])
        #expect(adapter.finalizedOutcomes == [.failed])
    }

    @Test func testChipPromptAugmentation() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation(model: .gpt4o)

        var capturedPrompt = ""
        struct PromptCapturingProvider: AIStreamingProvider {
            let onPromptCaptured: (String) -> Void
            func stream(model: String, messages: [[String: String]], systemPrompt: String) -> AsyncThrowingStream<String, Error> {
                onPromptCaptured(systemPrompt)
                return AsyncThrowingStream { $0.finish() }
            }
        }

        let provider = PromptCapturingProvider { capturedPrompt = $0 }
        let streamingService = StreamingService(conversationService: conversationService, searchProvider: OpenRouterService())

        try await streamingService.streamReply(
            provider: provider,
            modelName: "gpt-4o",
            conversationId: conversation.id,
            context: context,
            tone: "Professional",
            length: "Short",
            format: "JSON"
        )

        #expect(capturedPrompt.contains("professional"))
        #expect(capturedPrompt.contains("brief"))
        #expect(capturedPrompt.contains("JSON"))
    }

    @Test func testOllamaSearchFailureThrowsRecoveryGuidanceBeforePlaceholderCreation() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let adapter = RecordingPersistenceAdapter()
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter,
            hasSearchAPIKey: { false }
        )

        await #expect(throws: WriteVibeError.self) {
            try await streamingService.streamReply(
                provider: OllamaService(),
                modelName: "test-model",
                conversationId: conversation.id,
                context: context,
                isSearchEnabled: true
            )
        }

        #expect(adapter.beganRuns.isEmpty)
        #expect(adapter.appendedChunks.isEmpty)
        #expect(adapter.finalizedOutcomes.isEmpty)
    }

    @Test func testOllamaSearchProviderFailureThrowsTypedRecoveryGuidance() async throws {
        let (context, conversationService, conversation) = try makeContextAndConversation()
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            webSearchProvider: MockSearchContextProvider(result: .failure(MockStreamError.providerFailure)),
            hasSearchAPIKey: { true }
        )

        await #expect(throws: WriteVibeError.self) {
            try await streamingService.streamReply(
                provider: OllamaService(),
                modelName: "test-model",
                conversationId: conversation.id,
                context: context,
                isSearchEnabled: true
            )
        }
    }
}
