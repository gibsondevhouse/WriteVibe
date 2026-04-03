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
    struct ProviderRoute {
        let provider: AIStreamingProvider
        let modelName: String
    }

    let ollamaProvider: OllamaService
    let openRouterProvider: OpenRouterService
    let anthropicProvider: AnthropicService
    let conversationService: ConversationService
    let streamingService: StreamingService
    let commandExecutionService: CommandExecutionService
    let articleDraftAutofillService: any ArticleDraftAutofillServicing
    let articleContextMutationAdapter: ArticleContextMutationAdapter
    let articleOutlineMutationAdapter: ArticleOutlineMutationAdapter
    let articleBodyMutationAdapter: ArticleBodyMutationAdapter
    private let hasOpenRouterKey: @Sendable () -> Bool

    init(
        ollamaProvider: OllamaService? = nil,
        openRouterProvider: OpenRouterService? = nil,
        anthropicProvider: AnthropicService? = nil,
        conversationService: ConversationService? = nil,
        articleDraftAutofillService: (any ArticleDraftAutofillServicing)? = nil,
        webSearchProvider: (any SearchContextProviding)? = nil,
        hasSearchAPIKey: (@Sendable () -> Bool)? = nil
    ) {
        let ollamaProvider = ollamaProvider ?? OllamaService()
        let openRouterProvider = openRouterProvider ?? OpenRouterService()
        let anthropicProvider = anthropicProvider ?? AnthropicService()
        let conversationService = conversationService ?? ConversationService()
        let hasOpenRouterKey = hasSearchAPIKey ?? {
            KeychainService.load(key: "openrouter_api_key") != nil
        }

        self.ollamaProvider = ollamaProvider
        self.openRouterProvider = openRouterProvider
        self.anthropicProvider = anthropicProvider
        self.conversationService = conversationService
        self.hasOpenRouterKey = hasOpenRouterKey
        self.commandExecutionService = CommandExecutionService()
        self.articleDraftAutofillService = articleDraftAutofillService ?? ArticleDraftAutofillService()
        self.articleContextMutationAdapter = ArticleContextMutationAdapter()
        self.articleOutlineMutationAdapter = ArticleOutlineMutationAdapter()
        self.articleBodyMutationAdapter = ArticleBodyMutationAdapter()
        self.streamingService = StreamingService(
            conversationService: conversationService,
            searchProvider: openRouterProvider,
            webSearchProvider: webSearchProvider,
            hasSearchAPIKey: hasOpenRouterKey
        )
    }

    func route(for model: AIModel, modelIdentifier: String?) -> ProviderRoute? {
        switch model {
        case .ollama:
            guard let modelIdentifier, !modelIdentifier.isEmpty else { return nil }
            return ProviderRoute(provider: ollamaProvider, modelName: modelIdentifier)
        case .appleIntelligence:
            return nil
        default:
            if model.provider == .anthropic, !hasOpenRouterKey(), let anthropicModelID = model.anthropicModelID {
                return ProviderRoute(provider: anthropicProvider, modelName: anthropicModelID)
            }
            if let openRouterModelID = model.openRouterModelID {
                return ProviderRoute(provider: openRouterProvider, modelName: openRouterModelID)
            }
            if let anthropicModelID = model.anthropicModelID {
                return ProviderRoute(provider: anthropicProvider, modelName: anthropicModelID)
            }
            return nil
        }
    }

    /// Returns the appropriate `AIStreamingProvider` for the given model.
    func provider(for model: AIModel) -> AIStreamingProvider {
        switch model {
        case .ollama:
            return ollamaProvider
        case .appleIntelligence:
            return openRouterProvider
        default:
            return route(for: model, modelIdentifier: "route-probe")?.provider ?? openRouterProvider
        }
    }
}
