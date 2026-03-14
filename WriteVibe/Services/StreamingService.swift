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

    init(conversationService: ConversationService) {
        self.conversationService = conversationService
    }

    /// Streams an AI reply into a placeholder message using the given provider and model name.
    func streamReply(
        provider: AIStreamingProvider,
        modelName: String,
        conversationId: UUID,
        context: ModelContext
    ) async throws {
        guard let conv = conversationService.fetch(conversationId, context: context) else { return }

        let contextMessages = conv.messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

        let placeholder = Message(role: .assistant, content: "", modelUsed: modelName)
        conversationService.appendMessage(placeholder, to: conversationId, context: context)

        var tokenBuffer = ""
        var tokenCount  = 0

        let stream = provider.stream(
            model: modelName,
            messages: contextMessages,
            systemPrompt: writeVibeSystemPrompt
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
}
