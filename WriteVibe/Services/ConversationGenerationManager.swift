//
//  ConversationGenerationManager.swift
//  WriteVibe
//

import Foundation
import SwiftData

/// Manages in-flight AI generation tasks. Owned by `AppState` as an
/// internal implementation detail — views never interact with this directly.
@MainActor
final class ConversationGenerationManager {
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    func cancel(for conversationId: UUID) {
        activeTasks[conversationId]?.cancel()
        activeTasks.removeValue(forKey: conversationId)
    }

    // swiftlint:disable:next function_parameter_count
    func generateReply(
        to conversationId: UUID,
        context: ModelContext,
        isSearchEnabled: Bool,
        tone: String,
        length: String,
        format: String,
        isMemoryEnabled: Bool,
        onSearchFetchingChanged: @escaping (Bool) -> Void,
        onFinish: @escaping () -> Void
    ) {
        guard let conv = services.conversationService.fetch(conversationId, context: context) else {
            onFinish()
            return
        }

        let model = conv.model
        let modelIdentifier = conv.modelIdentifier

        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.activeTasks.removeValue(forKey: conversationId)
                onFinish()
            }
            do {
                let modelName: String
                let provider: AIStreamingProvider

                guard model != .appleIntelligence else {
                    self.services.conversationService.appendMessage(
                        Message(role: .assistant, content: "Apple Intelligence is not available here. Select a different model."),
                        to: conversationId, context: context
                    )
                    return
                }

                if model.isLocal {
                    guard let name = modelIdentifier, !name.isEmpty else {
                        self.services.conversationService.appendMessage(
                            Message(role: .assistant, content: "No Ollama model selected. Choose a model from Settings."),
                            to: conversationId, context: context
                        )
                        return
                    }
                    modelName = name
                    provider = self.services.ollamaProvider
                } else if let openRouterID = model.openRouterModelID {
                    modelName = openRouterID
                    provider = self.services.provider(for: model)
                } else {
                    self.services.conversationService.appendMessage(
                        Message(role: .assistant, content: "This model is not yet configured."),
                        to: conversationId, context: context
                    )
                    return
                }

                if isSearchEnabled { onSearchFetchingChanged(true) }
                defer { if isSearchEnabled { onSearchFetchingChanged(false) } }
                try await self.services.streamingService.streamReply(
                    provider: provider,
                    modelName: modelName,
                    conversationId: conversationId,
                    context: context,
                    isSearchEnabled: isSearchEnabled,
                    tone: tone,
                    length: length,
                    format: format,
                    isMemoryEnabled: isMemoryEnabled
                )
            } catch is CancellationError {
                // User tapped stop
            } catch let error as WriteVibeError {
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: error.localizedDescription),
                    to: conversationId, context: context
                )
            } catch {
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: "⚠️ \(error.localizedDescription)"),
                    to: conversationId, context: context
                )
            }
        }
        activeTasks[conversationId] = task
    }
}
