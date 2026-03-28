//
//  AppState.swift
//  WriteVibe
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - AppState

@MainActor
@Observable
final class AppState {
    var thinkingId: UUID?                      = nil
    var availableOllamaModels: [OllamaModel]   = []
    var runtimeIssue: String?                  = nil

    // Capability chips / search state
    var isSearchEnabled: Bool = false
    var isSearchFetching: Bool = false

    // Capability selections
    var selectedTone: String = "Balanced"
    var selectedLength: String = "Normal"
    var selectedFormat: String = "Markdown"
    var isMemoryEnabled: Bool = true

    // Sidebar navigation
    var selectedDestination: SidebarDestination = .articles
    var isArticlesSectionExpanded: Bool = true

    // Copilot panel
    var isCopilotOpen: Bool          = false
    var copilotConversationId: UUID? = nil

    let services: ServiceContainer
    private let generationManager: ConversationGenerationManager

    /// Default model applied to every new conversation. Persisted across launches.
    var defaultModel: AIModel = {
        let raw = UserDefaults.standard.string(forKey: "wv.defaultModel") ?? ""
        return AIModel(rawValue: raw) ?? .ollama
    }() {
        didSet { UserDefaults.standard.set(defaultModel.rawValue, forKey: "wv.defaultModel") }
    }

    /// Default model identifier when defaultModel is .ollama. Persisted across launches.
    var defaultModelIdentifier: String? =
        UserDefaults.standard.string(forKey: "wv.defaultModelIdentifier")
        ?? UserDefaults.standard.string(forKey: "wv.defaultOllamaModelName") {
        didSet {
            UserDefaults.standard.set(defaultModelIdentifier, forKey: "wv.defaultModelIdentifier")
            UserDefaults.standard.set(defaultModelIdentifier, forKey: "wv.defaultOllamaModelName")
        }
    }

    var modelContext: ModelContext? = nil

    // MARK: Computed helpers

    var copilotConversation: Conversation? {
        guard let copilotConversationId, let ctx = modelContext else { return nil }
        return services.conversationService.fetch(copilotConversationId, context: ctx)
    }

    var isThinkingInCopilot: Bool { thinkingId != nil && thinkingId == copilotConversationId }

    // MARK: Init

    init(services: ServiceContainer) {
        self.services = services
        self.generationManager = ConversationGenerationManager(services: services)
    }

    // MARK: Context binding

    func bindModelContextIfNeeded(_ context: ModelContext) {
        if modelContext !== context {
            modelContext = context
            do {
                try DataMigrationService.runStartupMigrations(context: context)
            } catch {
                reportIssue("Data migration failed: \(error.localizedDescription)")
            }
        }
        reconcileConversationIDs()
    }

    func reconcileConversationIDs() {
        guard let ctx = modelContext else { return }
        if let id = copilotConversationId, services.conversationService.fetch(id, context: ctx) == nil { copilotConversationId = nil }
    }

    // MARK: Conversation management

    func fetchConversation(_ id: UUID) -> Conversation? {
        guard let ctx = modelContext else { reportIssue("Model context is not attached"); return nil }
        return services.conversationService.fetch(id, context: ctx)
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
        let conv = services.conversationService.create(model: defaultModel, modelIdentifier: defaultModelIdentifier, context: ctx)
        copilotConversationId = conv.id
        return conv.id
    }

    // MARK: Messaging

    @discardableResult
    func send(_ text: String, in conversationId: UUID) -> Bool {
        let trimmed = text.trimmed
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
        generationManager.cancel(for: conversationId)
        if thinkingId == conversationId { thinkingId = nil }
    }

    private func generateReply(to conversationId: UUID) {
        guard let ctx = modelContext else {
            if thinkingId == conversationId { thinkingId = nil }
            return
        }
        generationManager.generateReply(
            to: conversationId,
            context: ctx,
            isSearchEnabled: isSearchEnabled,
            tone: selectedTone,
            length: selectedLength,
            format: selectedFormat,
            isMemoryEnabled: isMemoryEnabled,
            onSearchFetchingChanged: { [weak self] fetching in self?.isSearchFetching = fetching },
            onFinish: { [weak self] in
                if self?.thinkingId == conversationId { self?.thinkingId = nil }
            }
        )
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
}
