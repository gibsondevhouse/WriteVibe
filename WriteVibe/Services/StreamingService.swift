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
    private let augmentationEngine: PromptAugmentationEngine
    private let webSearchProvider: WebSearchContextProvider

    init(conversationService: ConversationService, searchProvider: OpenRouterService) {
        self.conversationService = conversationService
        self.augmentationEngine = PromptAugmentationEngine()
        self.webSearchProvider = WebSearchContextProvider(searchProvider: searchProvider)
    }

    /// Streams an AI reply into a placeholder message using the given provider and model name.
    func streamReply(
        provider: AIStreamingProvider,
        modelName: String,
        conversationId: UUID,
        context: ModelContext,
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

        let placeholder = Message(role: .assistant, content: "", modelUsed: modelName)
        conversationService.appendMessage(placeholder, to: conversationId, context: context)

        var augmentedPrompt = augmentationEngine.augmentWithCapabilities(
            basePrompt: writeVibeSystemPrompt,
            tone: tone,
            length: length,
            format: format,
            isMemoryEnabled: isMemoryEnabled
        )

        if isSearchEnabled {
            augmentedPrompt = await buildSearchAugmentation(
                prompt: augmentedPrompt,
                modelName: modelName,
                conversation: conv
            )
        }

        var tokenBuffer = ""
        var tokenCount  = 0

        let stream = provider.stream(
            model: modelName,
            messages: contextMessages,
            systemPrompt: augmentedPrompt
        )

        for try await token in stream {
            tokenBuffer += token
            tokenCount  += 1
            if tokenCount >= AppConstants.tokenBatchSize {
                placeholder.content += tokenBuffer
                tokenBuffer = ""
                tokenCount  = 0
            }
        }

        if !tokenBuffer.isEmpty { placeholder.content += tokenBuffer }
        placeholder.tokenCount = placeholder.content.count / 4
        if let c = conversationService.fetch(conversationId, context: context) { c.updatedAt = Date() }
        try? context.save()
    }

    // MARK: - Search Augmentation

    private func buildSearchAugmentation(
        prompt: String,
        modelName: String,
        conversation: Conversation
    ) async -> String {
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
            do {
                if let searchResults = try await webSearchProvider.fetchContext(query: query, searchModel: searchLayerModel) {
                    augmented = augmentationEngine.appendSearchResults(searchResults, to: augmented, searchModel: searchLayerModel)
                } else {
                    augmented += "\n\nSearch: The web search layer returned no usable findings. Do not claim verified web results."
                }
            } catch {
                augmented += "\n\nSearch: The web search layer is unavailable right now (\(error.localizedDescription)). Do not claim web verification."
            }
        } else {
            augmented += "\n\nSearch: No user query was available for web retrieval. Do not claim web verification."
        }

        let selectedModel = AIModel(rawValue: modelName) ?? .ollama
        if selectedModel.isLocal {
            augmented = augmentationEngine.appendLocalGrounding(to: augmented)
        }

        return augmented
    }
}
