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
        onIssue: @escaping (RuntimeIssue?) -> Void,
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
                guard model != .appleIntelligence else {
                    let issue = RuntimeIssue.appleIntelligenceUnavailable()
                    self.appendRecoveryMessage(issue, to: conversationId, context: context)
                    onIssue(issue)
                    return
                }

                guard let route = self.services.route(for: model, modelIdentifier: modelIdentifier) else {
                    let issue = model.isLocal
                        ? RuntimeIssue.ollamaModelSelectionRequired()
                        : RuntimeIssue.modelConfigurationIncomplete()
                    self.appendRecoveryMessage(issue, to: conversationId, context: context)
                    onIssue(issue)
                    return
                }

                if isSearchEnabled { onSearchFetchingChanged(true) }
                defer { if isSearchEnabled { onSearchFetchingChanged(false) } }

                try await self.services.streamingService.streamReply(
                    provider: route.provider,
                    modelName: route.modelName,
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
                onIssue(error.runtimeIssue)
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: error.localizedDescription),
                    to: conversationId,
                    context: context
                )
            } catch {
                let issue = RuntimeIssue.unexpectedRequestFailure(error.localizedDescription)
                onIssue(issue)
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: issue.guidanceText),
                    to: conversationId,
                    context: context
                )
            }
        }

        activeTasks[conversationId] = task
    }

    private func appendRecoveryMessage(_ issue: RuntimeIssue, to conversationId: UUID, context: ModelContext) {
        services.conversationService.appendMessage(
            Message(role: .assistant, content: issue.guidanceText),
            to: conversationId,
            context: context
        )
    }
}
