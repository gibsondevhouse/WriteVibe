//
//  StreamingServiceTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@MainActor
struct StreamingServiceTests {

    /// Mock AI provider for testing streaming logic
    struct MockAIProvider: AIStreamingProvider {
        let tokens: [String]
        let delay: TimeInterval
        
        @MainActor
        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    for token in tokens {
                        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
                        continuation.yield(token)
                    }
                    continuation.finish()
                }
            }
        }
    }

    @Test func testTokenBatching() async throws {
        // 1. Setup SwiftData in-memory
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        // 2. Create conversation
        let convService = ConversationService()
        let conv = convService.create(model: .ollama, modelIdentifier: "test-model", context: context)
        convService.appendMessage(Message(role: .user, content: "Hello"), to: conv.id, context: context)
        
        // 3. Setup StreamingService
        let provider = MockAIProvider(tokens: ["A", "B", "C", "D", "E"], delay: 0)
        let streamingService = StreamingService(conversationService: convService, searchProvider: OpenRouterService())
        
        // 4. Run stream
        try await streamingService.streamReply(
            provider: provider,
            modelName: "test-model",
            conversationId: conv.id,
            context: context
        )
        
        // 5. Verify results
    }

    @Test func testChipPromptAugmentation() async throws {
        // 1. Setup SwiftData in-memory
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        
        // 2. Create conversation
        let convService = ConversationService()
        let conv = convService.create(model: .gpt4o, modelIdentifier: "gpt-4o", context: context)
        convService.appendMessage(Message(role: .user, content: "Hello"), to: conv.id, context: context)
        
        // 3. Setup StreamingService with a capturing provider
        var capturedPrompt = ""
        struct PromptCapturingProvider: AIStreamingProvider {
            var onPromptCaptured: (String) -> Void
            func stream(model: String, messages: [[String: String]], systemPrompt: String) -> AsyncThrowingStream<String, Error> {
                onPromptCaptured(systemPrompt)
                return AsyncThrowingStream { $0.finish() }
            }
        }
        
        let provider = PromptCapturingProvider { capturedPrompt = $0 }
        let streamingService = StreamingService(conversationService: convService, searchProvider: OpenRouterService())
        
        // 4. Run stream with chip states
        try await streamingService.streamReply(
            provider: provider,
            modelName: "gpt-4o",
            conversationId: conv.id,
            context: context,
            tone: "Professional",
            length: "Short",
            format: "JSON"
        )
        
        // 5. Verify augmented prompt
        #expect(capturedPrompt.contains("professional"))
        #expect(capturedPrompt.contains("brief"))
        #expect(capturedPrompt.contains("JSON"))
    }
}
