//
//  AppState.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - AppDestination

enum AppDestination: Equatable {
    case chat
    case articles
}

// MARK: - AppState

@MainActor
@Observable
final class AppState {
    var selectedId: UUID?                      = nil
    var thinkingId: UUID?                      = nil
    var availableOllamaModels: [OllamaModel]   = []
    var pendingPrompt: String?                 = nil
    var destination: AppDestination            = .chat
    var runtimeIssue: String?                  = nil

    // Copilot panel
    var isCopilotOpen: Bool       = false
    var copilotConversationId: UUID? = nil

    let services = ServiceContainer()

    /// Default model applied to every new conversation. Persisted across launches.
    var defaultModel: AIModel = {
        let raw = UserDefaults.standard.string(forKey: "wv.defaultModel") ?? ""
        return AIModel(rawValue: raw) ?? .ollama
    }() {
        didSet { UserDefaults.standard.set(defaultModel.rawValue, forKey: "wv.defaultModel") }
    }

    /// Default Ollama model name when defaultModel is .ollama. Persisted across launches.
    var defaultOllamaModelName: String? = UserDefaults.standard.string(forKey: "wv.defaultOllamaModelName") {
        didSet { UserDefaults.standard.set(defaultOllamaModelName, forKey: "wv.defaultOllamaModelName") }
    }

    var modelContext: ModelContext? = nil

    // In-flight generation tasks keyed by conversation ID
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: Computed helpers

    var selected: Conversation? {
        guard let selectedId, let ctx = modelContext else { return nil }
        return services.conversationService.fetch(selectedId, context: ctx)
    }

    var copilotConversation: Conversation? {
        guard let copilotConversationId, let ctx = modelContext else { return nil }
        return services.conversationService.fetch(copilotConversationId, context: ctx)
    }

    var isThinkingInSelected: Bool { thinkingId != nil && thinkingId == selectedId }
    var isThinkingInCopilot: Bool  { thinkingId != nil && thinkingId == copilotConversationId }

    // MARK: Context binding

    func bindModelContextIfNeeded(_ context: ModelContext) {
        if modelContext !== context {
            modelContext = context
            services.conversationService.migrateLegacyModels(context: context, defaultOllamaModelName: defaultOllamaModelName)
            migrateArticleAudience(context: context)
        }
        reconcileConversationIDs()
    }

    func reconcileConversationIDs() {
        guard let ctx = modelContext else { return }
        if let id = selectedId, services.conversationService.fetch(id, context: ctx) == nil { selectedId = nil }
        if let id = copilotConversationId, services.conversationService.fetch(id, context: ctx) == nil { copilotConversationId = nil }
    }

    func mergedConversations(from fetched: [Conversation]) -> [Conversation] {
        services.conversationService.mergedConversations(from: fetched)
    }

    // MARK: Conversation management

    func fetchConversation(_ id: UUID) -> Conversation? {
        guard let ctx = modelContext else { reportIssue("Model context is not attached"); return nil }
        return services.conversationService.fetch(id, context: ctx)
    }

    @discardableResult
    func newConversation() -> UUID? {
        guard let ctx = modelContext else { reportIssue("Model context is not attached"); return nil }
        let conv = services.conversationService.create(model: defaultModel, ollamaModelName: defaultOllamaModelName, context: ctx)
        selectedId = conv.id
        return conv.id
    }

    func openCopilot() {
        if copilotConversationId == nil || copilotConversation == nil {
            guard newCopilotConversation() != nil else { return }
        }
        isCopilotOpen = true
    }

    @discardableResult
    func newCopilotConversation() -> UUID? {
        guard let ctx = modelContext else { reportIssue("Model context is not attached"); return nil }
        let conv = services.conversationService.create(model: defaultModel, ollamaModelName: defaultOllamaModelName, context: ctx)
        copilotConversationId = conv.id
        return conv.id
    }

    func deleteConversation(_ id: UUID) {
        stopGeneration(for: id)
        guard let ctx = modelContext else { return }
        services.conversationService.delete(id, context: ctx)
        if selectedId == id { selectedId = nil }
    }

    func renameConversation(_ id: UUID, to newTitle: String) {
        guard let ctx = modelContext else { return }
        services.conversationService.rename(id, to: newTitle, context: ctx)
    }

    // MARK: Messaging

    @discardableResult
    func send(_ text: String, in conversationId: UUID) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, thinkingId != conversationId else { return false }
        guard let ctx = modelContext else { reportIssue("Model context is not attached"); return false }

        guard services.conversationService.appendMessage(Message(role: .user, content: trimmed), to: conversationId, context: ctx) else { return false }

        thinkingId = conversationId
        generateReply(to: conversationId)
        clearRuntimeIssue()
        return true
    }

    // MARK: AI Generation

    func stopGeneration(for conversationId: UUID) {
        activeTasks[conversationId]?.cancel()
        finishGeneration(for: conversationId)
    }

    private func generateReply(to conversationId: UUID) {
        guard let ctx = modelContext,
              let conv = services.conversationService.fetch(conversationId, context: ctx) else {
            finishGeneration(for: conversationId)
            return
        }

        let model = conv.model
        let task = Task { [weak self] in
            guard let self, let ctx = self.modelContext else { return }
            defer { self.finishGeneration(for: conversationId) }
            do {
                let modelName: String
                let provider: AIStreamingProvider

                if model.isLocal {
                    guard let name = conv.ollamaModelName, !name.isEmpty else {
                        self.services.conversationService.appendMessage(
                            Message(role: .assistant, content: "No Ollama model selected. Choose a model from the model picker."),
                            to: conversationId, context: ctx
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
                        to: conversationId, context: ctx
                    )
                    return
                }

                try await self.services.streamingService.streamReply(
                    provider: provider,
                    modelName: modelName,
                    conversationId: conversationId,
                    context: ctx
                )
            } catch is CancellationError {
                // User tapped stop
            } catch let error as WriteVibeError {
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: error.localizedDescription),
                    to: conversationId, context: ctx
                )
            } catch {
                self.services.conversationService.appendMessage(
                    Message(role: .assistant, content: "⚠️ \(error.localizedDescription)"),
                    to: conversationId, context: ctx
                )
            }
        }
        activeTasks[conversationId] = task
    }

    private func finishGeneration(for conversationId: UUID) {
        activeTasks.removeValue(forKey: conversationId)
        if thinkingId == conversationId { thinkingId = nil }
    }

    // MARK: Ollama

    func refreshOllamaModels() async {
        guard await OllamaService.isRunning() else { availableOllamaModels = []; return }
        availableOllamaModels = (try? await OllamaService.installedModels()) ?? []
    }

    // MARK: Token Management

    func estimatedTokenUsage(for conversationId: UUID) -> Double {
        guard let conv = fetchConversation(conversationId) else { return 0.0 }
        let charCount = conv.messages.reduce(0) { $0 + $1.content.count }
        return Double(charCount) / 4.0
    }

    // MARK: Helpers

    func clearRuntimeIssue() { runtimeIssue = nil }

    private func reportIssue(_ message: String) { runtimeIssue = message }

    // MARK: - Data migration

    private func migrateArticleAudience(context: ModelContext) {
        let sentinel = "§AUDIENCE§"
        let endSentinel = "§END§"
        let descriptor = FetchDescriptor<Article>()
        guard let articles = try? context.fetch(descriptor) else { return }

        var changed = false
        for article in articles where article.quickNotes.hasPrefix(sentinel) {
            guard let endRange = article.quickNotes.range(of: endSentinel) else { continue }
            let audienceStart = article.quickNotes.index(article.quickNotes.startIndex, offsetBy: sentinel.count)
            article.audience = String(article.quickNotes[audienceStart..<endRange.lowerBound])
            article.quickNotes = String(article.quickNotes[endRange.upperBound...])
            changed = true
        }
        if changed { try? context.save() }
    }
}

