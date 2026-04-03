//
//  StreamingService.swift
//  WriteVibe
//

import Foundation
import SwiftData

@MainActor
@Observable
final class StreamingService {

    private static let maxTransientStreamRetries = 1

    private let conversationService: ConversationService
    private let messagePersistence: MessagePersistence
    private let tokenBuffering: MessageTokenBuffering
    private let augmentationEngine: PromptAugmentationEngine
    private let webSearchProvider: any SearchContextProviding
    private let hasSearchAPIKey: @MainActor () -> Bool

    init(
        conversationService: ConversationService,
        searchProvider: OpenRouterService,
        messagePersistenceAdapter: MessagePersistenceAdapter? = nil,
        usePersistenceAdapter: Bool? = nil,
        webSearchProvider: (any SearchContextProviding)? = nil,
        hasSearchAPIKey: (@MainActor () -> Bool)? = nil
    ) {
        let usePersistenceAdapter = usePersistenceAdapter ?? AppConstants.useStreamingPersistenceAdapter
        let hasSearchAPIKey = hasSearchAPIKey ?? {
            KeychainService.load(key: "openrouter_api_key") != nil
        }

        self.conversationService = conversationService
        let persistenceAdapter: MessagePersistenceAdapter
        if let messagePersistenceAdapter {
            persistenceAdapter = messagePersistenceAdapter
        } else if usePersistenceAdapter {
            persistenceAdapter = SwiftDataMessagePersistenceAdapter(conversationService: conversationService)
        } else {
            persistenceAdapter = InMemoryPersistenceAdapter()
        }
        self.messagePersistence = persistenceAdapter
        self.tokenBuffering = persistenceAdapter
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

        let handle = try messagePersistence.createAssistantPlaceholder(
            conversationId: conversationId,
            modelName: modelName,
            context: context
        )

        var tokenBuffer = ""
        var tokenCount  = 0
        var didReceiveReadableToken = false
        var attempt = 0

        while true {
            let stream = provider.stream(
                model: modelName,
                messages: contextMessages,
                systemPrompt: augmentedPrompt
            )

            do {
                for try await token in stream {
                    if !token.isEmpty {
                        didReceiveReadableToken = true
                    }
                    tokenBuffer += token
                    tokenCount  += 1
                    if tokenCount >= AppConstants.tokenBatchSize {
                        try tokenBuffering.appendBufferedTokens(tokenBuffer, handle: handle)
                        tokenBuffer = ""
                        tokenCount  = 0
                    }
                }
                break
            } catch is CancellationError {
                if !tokenBuffer.isEmpty {
                    try tokenBuffering.appendBufferedTokens(tokenBuffer, handle: handle)
                }
                try messagePersistence.finalizeAssistantPlaceholder(handle: handle, outcome: .cancelled)
                throw CancellationError()
            } catch {
                if shouldRetryTransientStreamFailure(error, attempt: attempt, didReceiveReadableToken: didReceiveReadableToken) {
                    attempt += 1
                    continue
                }
                if !tokenBuffer.isEmpty {
                    try tokenBuffering.appendBufferedTokens(tokenBuffer, handle: handle)
                }
                try messagePersistence.finalizeAssistantPlaceholder(handle: handle, outcome: .failed(error))
                throw error
            }
        }

        guard didReceiveReadableToken else {
            let decodingError = WriteVibeError.decodingFailed(
                context: "Provider response contained no readable text"
            )
            try messagePersistence.finalizeAssistantPlaceholder(handle: handle, outcome: .failed(decodingError))
            throw decodingError
        }

        if !tokenBuffer.isEmpty {
            try tokenBuffering.appendBufferedTokens(tokenBuffer, handle: handle)
        }
        try messagePersistence.finalizeAssistantPlaceholder(handle: handle, outcome: .succeeded)
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
            : "perplexity/sonar-pro"

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
                return .localSearchUnavailable(reason: error.localizedDescription)
            }
        }

        return .localSearchUnavailable(reason: error.localizedDescription)
    }

    private func localSearchFallbackWarning(reason: String) -> String {
        "\n\nSearch: Web search is unavailable for this Ollama request because \(reason). Continue without external web retrieval and do not claim web verification."
    }

    private func shouldRetryTransientStreamFailure(
        _ error: Error,
        attempt: Int,
        didReceiveReadableToken: Bool
    ) -> Bool {
        guard attempt < Self.maxTransientStreamRetries, !didReceiveReadableToken else {
            return false
        }

        if let writeVibeError = error as? WriteVibeError {
            switch writeVibeError {
            case .network:
                return true
            case .apiError(_, let statusCode, _):
                return isTransientStatusCode(statusCode)
            default:
                return false
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func isTransientStatusCode(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 409 || statusCode == 429 || (500...599).contains(statusCode)
    }
}
