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

    private struct ConversationFixture {
        let container: ModelContainer
        let context: ModelContext
        let conversationService: ConversationService
        let conversationID: UUID
    }

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

    actor AttemptCounter {
        private var value = 0

        func increment() -> Int {
            value += 1
            return value
        }

        func currentValue() -> Int {
            value
        }
    }

    struct RetryThenSucceedAIProvider: AIStreamingProvider {
        let attemptCounter: AttemptCounter

        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    let attempt = await attemptCounter.increment()
                    if attempt == 1 {
                        continuation.finish(
                            throwing: WriteVibeError.apiError(
                                provider: "OpenRouter",
                                statusCode: 429,
                                message: "rate limited"
                            )
                        )
                        return
                    }
                    continuation.yield("Recovered")
                    continuation.finish()
                }
            }
        }
    }

    struct PartialThenTransientFailureAIProvider: AIStreamingProvider {
        let attemptCounter: AttemptCounter

        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    _ = await attemptCounter.increment()
                    continuation.yield("partial")
                    continuation.finish(
                        throwing: WriteVibeError.apiError(
                            provider: "OpenRouter",
                            statusCode: 503,
                            message: "service unavailable"
                        )
                    )
                }
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

    actor PromptCaptureBox {
        private(set) var value: String = ""

        func store(_ prompt: String) {
            value = prompt
        }
    }

    struct PromptCapturingProvider: AIStreamingProvider {
        let tokens: [String]
        let onPromptCaptured: @Sendable (String) async -> Void

        init(tokens: [String] = [], onPromptCaptured: @escaping @Sendable (String) async -> Void) {
            self.tokens = tokens
            self.onPromptCaptured = onPromptCaptured
        }

        func stream(model: String, messages: [[String: String]], systemPrompt: String) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    await onPromptCaptured(systemPrompt)
                    for token in tokens {
                        continuation.yield(token)
                    }
                    continuation.finish()
                }
            }
        }
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

    private func makeContextAndConversation(model: AIModel = .ollama) throws -> ConversationFixture {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let conversationService = ConversationService()
        let conversation = conversationService.create(model: model, modelIdentifier: "test-model", context: context)
        conversationService.appendMessage(Message(role: .user, content: "Hello"), to: conversation.id, context: context)
        return ConversationFixture(
            container: container,
            context: context,
            conversationService: conversationService,
            conversationID: conversation.id
        )
    }

    @Test func testDefaultAdapterPersistsAssistantMessageOnSuccess() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
        let provider = MockAIProvider(tokens: ["A", "B", "C", "D", "E"])
        let streamingService = StreamingService(conversationService: conversationService, searchProvider: OpenRouterService())

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: context
        )

        let updatedConversation = try #require(conversationService.fetch(fixture.conversationID, context: context))
        #expect(updatedConversation.messages.count == 2)
        let assistantMessage = try #require(updatedConversation.messages.last)
        #expect(assistantMessage.role == .assistant)
        #expect(assistantMessage.content == "ABCDE")
        #expect(assistantMessage.tokenCount == 1)
    }

    @Test func testFeatureFlagOffUsesInMemoryAdapterFallback() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
        let provider = MockAIProvider(tokens: ["A", "B", "C"])
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            usePersistenceAdapter: false
        )

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: context
        )

        let updatedConversation = try #require(conversationService.fetch(fixture.conversationID, context: context))
        #expect(updatedConversation.messages.count == 1)
        #expect(updatedConversation.messages.last?.role == .user)
    }

    @Test func testFeatureFlagOnUsesSwiftDataAdapter() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
        let provider = MockAIProvider(tokens: ["A", "B", "C"])
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            usePersistenceAdapter: true
        )

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: context
        )

        let updatedConversation = try #require(conversationService.fetch(fixture.conversationID, context: context))
        #expect(updatedConversation.messages.count == 2)
        #expect(updatedConversation.messages.last?.role == .assistant)
        #expect(updatedConversation.messages.last?.content == "ABC")
    }

    @Test func testAdapterLifecycleOnSuccess() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
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
            conversationId: fixture.conversationID,
            context: context
        )

        #expect(adapter.beganRuns.count == 1)
        #expect(adapter.appendedChunks == ["ABCDEF", "G"])
        #expect(adapter.finalizedOutcomes == [.succeeded])
    }

    @Test func testAdapterLifecycleOnCancellation() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
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
                conversationId: fixture.conversationID,
                context: context
            )
        }

        #expect(adapter.appendedChunks == ["partial"])
        #expect(adapter.finalizedOutcomes == [.cancelled])
    }

    @Test func testAdapterLifecycleOnProviderFailure() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
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
                conversationId: fixture.conversationID,
                context: context
            )
        }

        #expect(adapter.appendedChunks == ["partial"])
        #expect(adapter.finalizedOutcomes == [.failed])
    }

    @Test func testTransientFailureRetriesOnceBeforeAnyTokenAndSucceeds() async throws {
        let fixture = try makeContextAndConversation()
        let adapter = RecordingPersistenceAdapter()
        let attemptCounter = AttemptCounter()
        let provider = RetryThenSucceedAIProvider(attemptCounter: attemptCounter)
        let streamingService = StreamingService(
            conversationService: fixture.conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: fixture.context
        )

        #expect(await attemptCounter.currentValue() == 2)
        #expect(adapter.appendedChunks == ["Recovered"])
        #expect(adapter.finalizedOutcomes == [.succeeded])
    }

    @Test func testTransientFailureDoesNotRetryAfterPartialTokenEmission() async throws {
        let fixture = try makeContextAndConversation()
        let adapter = RecordingPersistenceAdapter()
        let attemptCounter = AttemptCounter()
        let provider = PartialThenTransientFailureAIProvider(attemptCounter: attemptCounter)
        let streamingService = StreamingService(
            conversationService: fixture.conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        await #expect(throws: WriteVibeError.self) {
            try await streamingService.streamReply(
                provider: provider,
                modelName: "test-model",
                conversationId: fixture.conversationID,
                context: fixture.context
            )
        }

        #expect(await attemptCounter.currentValue() == 1)
        #expect(adapter.appendedChunks == ["partial"])
        #expect(adapter.finalizedOutcomes == [.failed])
    }

    @Test func testEmptyStreamFailsDeterministicallyInsteadOfSilentSuccess() async throws {
        let fixture = try makeContextAndConversation()
        let adapter = RecordingPersistenceAdapter()
        let streamingService = StreamingService(
            conversationService: fixture.conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter
        )

        do {
            try await streamingService.streamReply(
                provider: MockAIProvider(tokens: []),
                modelName: "test-model",
                conversationId: fixture.conversationID,
                context: fixture.context
            )
            Issue.record("Expected empty stream to fail deterministically.")
        } catch let error as WriteVibeError {
            guard case .decodingFailed(let context) = error else {
                Issue.record("Expected decodingFailed for empty stream, got \(error)")
                return
            }
            #expect(context.contains("no readable text"))
        }

        #expect(adapter.appendedChunks.isEmpty)
        #expect(adapter.finalizedOutcomes == [.failed])
    }

    @Test func testChipPromptAugmentation() async throws {
        let fixture = try makeContextAndConversation(model: .gpt4o)
        let context = fixture.context
        let conversationService = fixture.conversationService

        let promptCapture = PromptCaptureBox()
        let provider = PromptCapturingProvider(tokens: ["ok"]) { prompt in
            await promptCapture.store(prompt)
        }
        let streamingService = StreamingService(conversationService: conversationService, searchProvider: OpenRouterService())

        try await streamingService.streamReply(
            provider: provider,
            modelName: "gpt-4o",
            conversationId: fixture.conversationID,
            context: context,
            tone: "Professional",
            length: "Short",
            format: "JSON"
        )

        let capturedPrompt = await promptCapture.value
        #expect(capturedPrompt.contains("professional"))
        #expect(capturedPrompt.contains("brief"))
        #expect(capturedPrompt.contains("JSON"))
    }

    @Test func testSystemPromptEnforcesArticleOnlySlashCommandBoundary() async throws {
        let fixture = try makeContextAndConversation(model: .gpt4o)
        let context = fixture.context
        let conversationService = fixture.conversationService

        let promptCapture = PromptCaptureBox()
        let provider = PromptCapturingProvider(tokens: ["ok"]) { prompt in
            await promptCapture.store(prompt)
        }
        let streamingService = StreamingService(conversationService: conversationService, searchProvider: OpenRouterService())

        try await streamingService.streamReply(
            provider: provider,
            modelName: "gpt-4o",
            conversationId: fixture.conversationID,
            context: context
        )

        let capturedPrompt = await promptCapture.value
        #expect(capturedPrompt.contains("Treat only /article slash commands as in-domain command behavior for this app."))
        #expect(capturedPrompt.contains("Command domain boundary: WriteVibe only supports /article commands in this app."))
        #expect(capturedPrompt.contains("For non-command requests (no slash command), continue with normal helpful generation behavior."))
    }

    @Test func testOllamaSearchMissingKeyAddsSoftWarningAndContinues() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
        let adapter = RecordingPersistenceAdapter()
        let promptCapture = PromptCaptureBox()
        let provider = PromptCapturingProvider(tokens: ["fallback"]) { prompt in
            await promptCapture.store(prompt)
        }
        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter,
            hasSearchAPIKey: { false }
        )

        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: context,
            isLocalModelOverride: true,
            isSearchEnabled: true
        )

        let capturedPrompt = await promptCapture.value
        #expect(capturedPrompt.contains("Web search is unavailable for this Ollama request"))
        #expect(capturedPrompt.contains("no OpenRouter API key is configured"))
        #expect(adapter.beganRuns.count == 1)
        #expect(adapter.appendedChunks == ["fallback"])
        #expect(adapter.finalizedOutcomes == [.succeeded])
    }

    @Test func testOllamaSearchProviderFailureAddsSoftWarningAndContinues() async throws {
        let fixture = try makeContextAndConversation()
        let context = fixture.context
        let conversationService = fixture.conversationService
        let adapter = RecordingPersistenceAdapter()
        let promptCapture = PromptCaptureBox()

        let streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: OpenRouterService(),
            messagePersistenceAdapter: adapter,
            webSearchProvider: MockSearchContextProvider(
                result: .failure(WriteVibeError.apiError(provider: "OpenRouter", statusCode: 503, message: nil))
            ),
            hasSearchAPIKey: { true }
        )

        try await streamingService.streamReply(
            provider: PromptCapturingProvider(tokens: ["ok"]) { prompt in
                await promptCapture.store(prompt)
            },
            modelName: "test-model",
            conversationId: fixture.conversationID,
            context: context,
            isLocalModelOverride: true,
            isSearchEnabled: true
        )

        let capturedPrompt = await promptCapture.value
        #expect(capturedPrompt.contains("Web search is unavailable for this Ollama request"))
        #expect(capturedPrompt.contains("OpenRouter search failed with HTTP 503"))
        #expect(adapter.finalizedOutcomes == [.succeeded])
    }
}
