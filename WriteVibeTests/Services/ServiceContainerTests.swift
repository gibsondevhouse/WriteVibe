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
    
    @Test func testAppleIntelligenceRouting() async throws {
        let container = ServiceContainer()
        
        let provider = container.provider(for: .appleIntelligence)
        #expect(provider is AppleIntelligenceStreamingProvider)
    }
}
