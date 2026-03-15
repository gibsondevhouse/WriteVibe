//
//  ServiceContainer.swift
//  WriteVibe
//

import Foundation

/// Central dependency container.
///
/// Instantiated once in `WriteVibeApp` / `ContentView` and injected into
/// the SwiftUI environment. Services that need swappable implementations
/// (e.g. AI provider, export) are accessed through this container rather
/// than via static calls.
@MainActor
@Observable
final class ServiceContainer {
    let ollamaProvider: OllamaService
    let openRouterProvider: OpenRouterService
    let anthropicProvider: AnthropicService
    let appleIntelligenceProvider: AppleIntelligenceStreamingProvider
    let conversationService: ConversationService
    let streamingService: StreamingService

    init() {
        self.ollamaProvider = OllamaService()
        self.openRouterProvider = OpenRouterService()
        self.anthropicProvider = AnthropicService()
        self.appleIntelligenceProvider = AppleIntelligenceStreamingProvider()
        self.conversationService = ConversationService()
        self.streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: openRouterProvider
        )
    }

    /// Returns the appropriate `AIStreamingProvider` for the given model.
    func provider(for model: AIModel) -> AIStreamingProvider {
        switch model {
        case .ollama:
            return ollamaProvider
        case .appleIntelligence:
            return appleIntelligenceProvider
        default:
            // Prefer OpenRouter for everything cloud-based if the model has an ID for it.
            // This ensures Claude models use the OpenRouter path as requested.
            if model.openRouterModelID != nil {
                return openRouterProvider
            }
            
            if model.provider == .anthropic {
                return anthropicProvider
            }
            return openRouterProvider
        }
    }
}
