//
//  StreamingService.swift
//  WriteVibe
//

import Foundation
import SwiftData

@MainActor
@Observable
final class StreamingService {

    private let conversationService: ConversationService
    private let messagePersistenceAdapter: MessagePersistenceAdapter
    private let augmentationEngine: PromptAugmentationEngine
    private let webSearchProvider: any SearchContextProviding
    private let hasSearchAPIKey: @Sendable () -> Bool

    init(
        conversationService: ConversationService,
        searchProvider: OpenRouterService,
        messagePersistenceAdapter: MessagePersistenceAdapter? = nil,
        usePersistenceAdapter: Bool? = nil,
        webSearchProvider: (any SearchContextProviding)? = nil,
        hasSearchAPIKey: (@Sendable () -> Bool)? = nil
    ) {
        let usePersistenceAdapter = usePersistenceAdapter ?? AppConstants.useStreamingPersistenceAdapter
        let hasSearchAPIKey = hasSearchAPIKey ?? {
            KeychainService.load(key: "openrouter_api_key") != nil
        }

        self.conversationService = conversationService
        if let messagePersistenceAdapter {
            self.messagePersistenceAdapter = messagePersistenceAdapter
        } else if usePersistenceAdapter {
            self.messagePersistenceAdapter = SwiftDataMessagePersistenceAdapter(conversationService: conversationService)
        } else {
            self.messagePersistenceAdapter = InMemoryPersistenceAdapter()
        }
        self.augmentationEngine = PromptAugmentationEngine()
        self.webSearchProvider = webSearchProvider ?? WebSearchContextProvider(searchProvider: searchProvider)
        self.hasSearchAPIKey = hasSearchAPIKey
    }

    /// Streams an AI reply into a placeholder message using the given provider and model name.
    func streamReply(
        provider: AIStreamingProvider,
        modelName: String,
        conversationId: UUID,
        context: ModelContext,
        isLocalModelOverride: Bool? = nil,
        isSearchEnabled: Bool = false,
        tone: String = "Balanced",
        length: String = "Normal",
        format: String = "Markdown",
        isMemoryEnabled: Bool = true
    ) async throws {
        guard let conv = conversationService.fetch(conversationId, context: context) else { return }

        let contextMessages = conv.messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }
        let isLocalModel = isLocalModelOverride ?? (provider is OllamaService)

        var augmentedPrompt = augmentationEngine.augmentWithCapabilities(
            basePrompt: writeVibeSystemPrompt,
            tone: tone,
            length: length,
            format: format,
            isMemoryEnabled: isMemoryEnabled
        )

        if isSearchEnabled {
            augmentedPrompt = try await buildSearchAugmentation(
                prompt: augmentedPrompt,
                modelName: modelName,
                conversation: conv,
                isLocalModel: isLocalModel
            )
        }

        let runContext = GenerationRunContext(
            conversationId: conversationId,
            modelName: modelName,
            context: context
        )
        let handle = try messagePersistenceAdapter.beginAssistantMessage(run: runContext)

        var tokenBuffer = ""
        var tokenCount  = 0

        let stream = provider.stream(
            model: modelName,
            messages: contextMessages,
            systemPrompt: augmentedPrompt
        )

        do {
            for try await token in stream {
                tokenBuffer += token
                tokenCount  += 1
                if tokenCount >= AppConstants.tokenBatchSize {
                    try messagePersistenceAdapter.appendToken(tokenBuffer, handle: handle)
                    tokenBuffer = ""
                    tokenCount  = 0
                }
            }

            if !tokenBuffer.isEmpty {
                try messagePersistenceAdapter.appendToken(tokenBuffer, handle: handle)
            }
            try messagePersistenceAdapter.finalize(handle: handle, outcome: .succeeded)
        } catch is CancellationError {
            if !tokenBuffer.isEmpty {
                try messagePersistenceAdapter.appendToken(tokenBuffer, handle: handle)
            }
            try messagePersistenceAdapter.finalize(handle: handle, outcome: .cancelled)
            throw CancellationError()
        } catch {
            if !tokenBuffer.isEmpty {
                try messagePersistenceAdapter.appendToken(tokenBuffer, handle: handle)
            }
            try messagePersistenceAdapter.finalize(handle: handle, outcome: .failed(error))
            throw error
        }
    }

    // MARK: - Search Augmentation

    private func buildSearchAugmentation(
        prompt: String,
        modelName: String,
        conversation: Conversation,
        isLocalModel: Bool
    ) async throws -> String {
        var augmented = prompt
        let selectedModelIsSearchNative = modelName.hasPrefix("perplexity/sonar")
        let searchLayerModel = selectedModelIsSearchNative
            ? modelName
            : (AIModel.perplexitySonarPro.openRouterModelID ?? "perplexity/sonar-pro")

        if selectedModelIsSearchNative {
            augmented += "\n\nSearch: Use your built-in web retrieval. Ground factual claims in retrieved sources and include citations/links when possible. If retrieval fails, say that clearly instead of inventing details."
        } else if let query = conversation.messages.reversed().first(where: {
            $0.role == .user && !$0.content.trimmed.isEmpty
        })?.content {
            if isLocalModel && !hasSearchAPIKey() {
                augmented += localSearchFallbackWarning(reason: "no OpenRouter API key is configured")
            } else {
                do {
                    if let searchResults = try await webSearchProvider.fetchContext(query: query, searchModel: searchLayerModel) {
                        augmented = augmentationEngine.appendSearchResults(searchResults, to: augmented, searchModel: searchLayerModel)
                    } else if isLocalModel {
                        augmented += localSearchFallbackWarning(reason: "the search layer returned no usable findings")
                    } else {
                        augmented += "\n\nSearch: The web search layer returned no usable findings. Do not claim verified web results."
                    }
                } catch {
                    if isLocalModel {
                        let localError = mapLocalSearchFailure(error)
                        if case .localSearchUnavailable(let reason) = localError {
                            augmented += localSearchFallbackWarning(reason: reason)
                        } else {
                            augmented += localSearchFallbackWarning(reason: "the web search layer is unavailable")
                        }
                    } else {
                        augmented += "\n\nSearch: The web search layer is unavailable right now (\(error.localizedDescription)). Do not claim web verification."
                    }
                }
            }
        } else {
            if isLocalModel {
                augmented += localSearchFallbackWarning(reason: "no user query was available for web retrieval")
            }
            augmented += "\n\nSearch: No user query was available for web retrieval. Do not claim web verification."
        }

        if isLocalModel {
            augmented = augmentationEngine.appendLocalGrounding(to: augmented)
        }

        return augmented
    }

    private func mapLocalSearchFailure(_ error: Error) -> WriteVibeError {
        if let error = error as? WriteVibeError {
            switch error {
            case .localSearchUnavailable:
                return error
            case .missingAPIKey:
                return .localSearchUnavailable(reason: "no OpenRouter API key is configured")
            case .apiError(let provider, let statusCode, _):
                return .localSearchUnavailable(reason: "\(provider) search failed with HTTP \(statusCode)")
            case .network(let underlying):
                return .localSearchUnavailable(reason: "the web search layer could not be reached (\(underlying.localizedDescription))")
            default:
                return .localSearchUnavailable(reason: error.localizedDescription ?? "the web search layer is unavailable")
            }
        }

        return .localSearchUnavailable(reason: error.localizedDescription)
    }

    private func localSearchFallbackWarning(reason: String) -> String {
        "\n\nSearch: Web search is unavailable for this Ollama request because \(reason). Continue without external web retrieval and do not claim web verification."
    }
}
