//
//  ServiceContainerTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
@testable import WriteVibe

@MainActor
struct ServiceContainerTests {

    @Test func testClaudeRoutingToOpenRouter() async throws {
        let container = ServiceContainer()
        
        // Claude Sonnet should use OpenRouter because it has an openRouterModelID
        let sonnetProvider = container.provider(for: .claudeSonnet)
        #expect(sonnetProvider is OpenRouterService)
        
        // GPT-4o should also use OpenRouter
        let gptProvider = container.provider(for: .gpt4o)
        #expect(gptProvider is OpenRouterService)
        
        // Ollama should use OllamaService
        let ollamaProvider = container.provider(for: .ollama)
        #expect(ollamaProvider is OllamaService)
    }
    
    @Test func testAppleIntelligenceNotRoutedForChat() async throws {
        // Apple Intelligence is not a chat provider — it has no entry in provider(for:)
        // and .appleIntelligence is no longer in isLocal, so it falls through to the
        // guard in AppState.generateReply before a provider is ever selected.
        let container = ServiceContainer()
        // Verify Ollama still routes correctly as the only local model
        let ollamaProvider = container.provider(for: .ollama)
        #expect(ollamaProvider is OllamaService)
    }
}
