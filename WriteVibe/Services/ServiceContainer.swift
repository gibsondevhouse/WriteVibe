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

    private struct BlockedAppleIntelligenceChatProvider: AIStreamingProvider {
        func stream(
            model: String,
            messages: [[String: String]],
            systemPrompt: String
        ) -> AsyncThrowingStream<String, Error> {
            _ = model
            _ = messages
            _ = systemPrompt
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: WriteVibeError.generationFailed(reason: "Apple Intelligence is limited to structured article workflows and cannot be used as a chat provider."))
            }
        }
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
    let appleStructuredWorkflowService: any AppleStructuredWorkflowServicing
    let appleStructuredWorkflowRouter: any AppleStructuredWorkflowRouting
    let appleStructuredWorkflowCoordinator: any AppleStructuredWorkflowCoordinating
    let appleWorkflowObservabilityService: any AppleWorkflowObservabilityServicing
    private let hasOpenRouterKey: @MainActor () -> Bool
    private let blockedAppleIntelligenceChatProvider = BlockedAppleIntelligenceChatProvider()

    init(
        ollamaProvider: OllamaService? = nil,
        openRouterProvider: OpenRouterService? = nil,
        anthropicProvider: AnthropicService? = nil,
        conversationService: ConversationService? = nil,
        articleDraftAutofillService: (any ArticleDraftAutofillServicing)? = nil,
        appleStructuredWorkflowService: (any AppleStructuredWorkflowServicing)? = nil,
        appleStructuredWorkflowRouter: (any AppleStructuredWorkflowRouting)? = nil,
        appleStructuredWorkflowCoordinator: (any AppleStructuredWorkflowCoordinating)? = nil,
        appleWorkflowObservabilityService: (any AppleWorkflowObservabilityServicing)? = nil,
        webSearchProvider: (any SearchContextProviding)? = nil,
        hasSearchAPIKey: (@MainActor () -> Bool)? = nil
    ) {
        let ollamaProvider = ollamaProvider ?? OllamaService()
        let openRouterProvider = openRouterProvider ?? OpenRouterService()
        let anthropicProvider = anthropicProvider ?? AnthropicService()
        let conversationService = conversationService ?? ConversationService()
        let hasOpenRouterKey = hasSearchAPIKey ?? {
            KeychainService.load(key: "openrouter_api_key") != nil
        }
        let articleDraftAutofillService = articleDraftAutofillService ?? ArticleDraftAutofillService()
        let articleContextMutationAdapter = ArticleContextMutationAdapter()
        let articleOutlineMutationAdapter = ArticleOutlineMutationAdapter()
        let articleBodyMutationAdapter = ArticleBodyMutationAdapter()
        let appleWorkflowObservabilityService = appleWorkflowObservabilityService ?? NoOpAppleWorkflowObservabilityService()
        let appleStructuredWorkflowRouter = appleStructuredWorkflowRouter ?? DefaultAppleStructuredWorkflowRouter()
        let appleStructuredWorkflowService = appleStructuredWorkflowService ?? AppleStructuredWorkflowService(
            heuristicDraftAutofillService: articleDraftAutofillService,
            contextMutationAdapter: articleContextMutationAdapter,
            observabilityService: appleWorkflowObservabilityService
        )
        let appleStructuredWorkflowCoordinator = appleStructuredWorkflowCoordinator ?? AppleStructuredWorkflowCoordinator(
            router: appleStructuredWorkflowRouter,
            service: appleStructuredWorkflowService
        )

        self.ollamaProvider = ollamaProvider
        self.openRouterProvider = openRouterProvider
        self.anthropicProvider = anthropicProvider
        self.conversationService = conversationService
        self.hasOpenRouterKey = hasOpenRouterKey
        self.commandExecutionService = CommandExecutionService()
        self.articleDraftAutofillService = articleDraftAutofillService
        self.articleContextMutationAdapter = articleContextMutationAdapter
        self.articleOutlineMutationAdapter = articleOutlineMutationAdapter
        self.articleBodyMutationAdapter = articleBodyMutationAdapter
        self.appleStructuredWorkflowService = appleStructuredWorkflowService
        self.appleStructuredWorkflowRouter = appleStructuredWorkflowRouter
        self.appleStructuredWorkflowCoordinator = appleStructuredWorkflowCoordinator
        self.appleWorkflowObservabilityService = appleWorkflowObservabilityService
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

    func evaluateAppleStructuredWorkflowRoute(for request: AppleWorkflowRouteRequest) -> AppleWorkflowRouteDecision {
        appleStructuredWorkflowRouter.evaluateRoute(for: request)
    }

    /// Returns the appropriate `AIStreamingProvider` for the given model.
    func provider(for model: AIModel) -> AIStreamingProvider {
        switch model {
        case .ollama:
            return ollamaProvider
        case .appleIntelligence:
            return blockedAppleIntelligenceChatProvider
        default:
            return route(for: model, modelIdentifier: "route-probe")?.provider ?? openRouterProvider
        }
    }
}
