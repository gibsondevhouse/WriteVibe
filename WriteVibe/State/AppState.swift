//
//  AppState.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - AppState

// MARK: - AppDestination

enum AppDestination: Equatable {
    case chat          // default — shows WelcomeView / ChatView keyed by selectedId
    case articles      // Articles library dashboard
}

@MainActor
@Observable
final class AppState {
    var selectedId: UUID?             = nil
    var thinkingId: UUID?             = nil
    var availableOllamaModels: [OllamaModel] = []
    var pendingPrompt: String? = nil
    var destination: AppDestination   = .chat
    var runtimeIssue: String? = nil

    // Copilot panel
    var isCopilotOpen: Bool = false
    var copilotConversationId: UUID? = nil

    var copilotConversation: Conversation? {
        guard let copilotConversationId else { return nil }
        return fetchConversation(copilotConversationId)
    }

    var isThinkingInCopilot: Bool {
        thinkingId != nil && thinkingId == copilotConversationId
    }

    func openCopilot() {
        if copilotConversationId == nil || copilotConversation == nil {
            guard newCopilotConversation() != nil else { return }
        }
        isCopilotOpen = true
    }

    @discardableResult
    func newCopilotConversation() -> UUID? {
        guard let modelContext else {
            reportIssue("Model context is not attached")
            return nil
        }
        let conv = Conversation(model: defaultModel)
        if defaultModel == .ollama { conv.ollamaModelName = defaultOllamaModelName }
        modelContext.insert(conv)
        try? modelContext.save()
        conversationCache[conv.id] = conv
        copilotConversationId = conv.id
        return conv.id
    }

    /// Default model applied to every new conversation. Persisted across launches.
    var defaultModel: AIModel = {
        let raw = UserDefaults.standard.string(forKey: "wv.defaultModel") ?? ""
        return AIModel(rawValue: raw) ?? .ollama
    }() {
        didSet { UserDefaults.standard.set(defaultModel.rawValue, forKey: "wv.defaultModel") }
    }

    /// Default Ollama model name applied when defaultModel is .ollama. Persisted across launches.
    var defaultOllamaModelName: String? = UserDefaults.standard.string(forKey: "wv.defaultOllamaModelName") {
        didSet { UserDefaults.standard.set(defaultOllamaModelName, forKey: "wv.defaultOllamaModelName") }
    }

    // We need the modelContext to perform creates/deletes.
    // This should be set by the view hierarchy on launch.
    var modelContext: ModelContext? = nil

    func bindModelContextIfNeeded(_ context: ModelContext) {
        // Always bind to the current environment context. SwiftUI can provide
        // a new ModelContext instance across lifecycle transitions.
        if modelContext !== context {
            modelContext = context
            migrateLegacyConversationModels()
        }
        reconcileConversationIDs()
    }

    func reconcileConversationIDs() {
        if let id = selectedId, fetchConversation(id) == nil {
            selectedId = nil
        }
        if let id = copilotConversationId, fetchConversation(id) == nil {
            copilotConversationId = nil
        }
    }

    func clearRuntimeIssue() {
        runtimeIssue = nil
    }

    private func reportIssue(_ message: String) {
        runtimeIssue = message
    }

    // In-memory cache of conversations we created this session.
    // SwiftData's fetch() sometimes fails to return just-inserted objects even
    // after save(), so we keep them here and check the cache first.
    private var conversationCache: [UUID: Conversation] = [:]

    // In-flight generation tasks keyed by conversation ID — enables stop-button cancellation
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    var selected: Conversation? {
        guard let selectedId else { return nil }
        return fetchConversation(selectedId)
    }

    var isThinkingInSelected: Bool {
        thinkingId != nil && thinkingId == selectedId
    }

    // MARK: Conversation management

    func fetchConversation(_ id: UUID) -> Conversation? {
        // Check in-memory cache first — SwiftData fetch() can miss just-inserted objects.
        if let cached = conversationCache[id] {
            return cached
        }
        guard let modelContext else {
            reportIssue("Model context is not attached")
            return nil
        }
        let descriptor = FetchDescriptor<Conversation>()
        do {
            let result = try modelContext.fetch(descriptor).first(where: { $0.id == id })
            if let result { conversationCache[id] = result }
            return result
        } catch {
            reportIssue("Failed to fetch conversations: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func newConversation() -> UUID? {
        guard let modelContext else {
            reportIssue("Model context is not attached")
            return nil
        }
        let conv = Conversation(model: defaultModel)
        if defaultModel == .ollama { conv.ollamaModelName = defaultOllamaModelName }
        modelContext.insert(conv)
        try? modelContext.save()
        conversationCache[conv.id] = conv
        selectedId = conv.id
        return conv.id
    }

    func deleteConversation(_ id: UUID) {
        stopGeneration(for: id)
        guard let conv = fetchConversation(id), let modelContext else { return }
        modelContext.delete(conv)
        conversationCache.removeValue(forKey: id)
        if selectedId == id { selectedId = nil }
    }

    func renameConversation(_ id: UUID, to newTitle: String) {
        guard let conv = fetchConversation(id) else { return }
        conv.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        conv.updatedAt = Date()
    }

    // MARK: Messaging

    @discardableResult
    func send(_ text: String, in conversationId: UUID) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, thinkingId != conversationId else { return false }

        // Append user message first; only generate if it was actually persisted.
        guard appendMessage(Message(role: .user, content: trimmed), to: conversationId) else { return false }

        thinkingId = conversationId
        generateReply(to: conversationId)
        clearRuntimeIssue()
        return true
    }

    @discardableResult
    func appendMessage(_ message: Message, to conversationId: UUID) -> Bool {
        guard let modelContext else {
            reportIssue("Model context is not attached")
            return false
        }
        guard let conv = fetchConversation(conversationId) else {
            reportIssue("Conversation not found for message append")
            return false
        }

        // Explicitly insert before relating to avoid dropped transient models.
        modelContext.insert(message)
        conv.messages.append(message)
        conv.updatedAt = Date()

        // Auto-title from first user message using Apple Intelligence (all models)
        if conv.messages.count == 1, message.role == .user {
            let snippet = String(message.content.prefix(45))
            let fallbackTitle = snippet.count < message.content.count ? snippet + "…" : snippet
            conv.title = fallbackTitle

            Task {
                if #available(macOS 26, *) {
                    do {
                        let newTitle = try await AppleIntelligenceService.generateTitle(userMessage: message.content)
                        // Only update if title hasn't been changed manually (heuristic: still matches fallback)
                        if conv.title == fallbackTitle {
                            conv.title = newTitle
                        }
                    } catch {
                        // Keep fallback
                    }
                }
            }
        }

        do {
            try modelContext.save()
            clearRuntimeIssue()
        } catch {
            reportIssue("Failed to save message: \(error.localizedDescription)")
            return false
        }
        return true
    }

    // MARK: - AI Generation

    func stopGeneration(for conversationId: UUID) {
        activeTasks[conversationId]?.cancel()
        finishGeneration(for: conversationId)
    }

    private func generateReply(to conversationId: UUID) {
        guard let conv = fetchConversation(conversationId) else {
            // Conversation not found — clear thinkingId so the UI doesn't spin forever.
            finishGeneration(for: conversationId)
            return
        }
        let model = conv.model
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishGeneration(for: conversationId) }
            do {
                if model.isLocal {
                    try await self.streamOllamaReply(for: conversationId)
                } else if let modelID = model.openRouterModelID {
                    try await self.streamOpenRouterReply(for: conversationId, modelID: modelID)
                } else {
                    self.appendMessage(
                        Message(role: .assistant, content: "This model is not yet configured."),
                        to: conversationId
                    )
                }
            } catch is CancellationError {
                // User tapped stop
            } catch OllamaError.notRunning {
                self.appendMessage(
                    Message(role: .assistant, content: "Ollama isn't running. Open the Ollama app on your Mac, then try again. You can download it free at ollama.com — or switch to a cloud model from the model picker above."),
                    to: conversationId
                )
            } catch OllamaError.httpError(let code) {
                self.appendMessage(
                    Message(role: .assistant, content: "Ollama returned an error (HTTP \(code)). Make sure the model is fully downloaded in Settings → Models and try again."),
                    to: conversationId
                )
            } catch OpenRouterError.missingAPIKey {
                self.appendMessage(
                    Message(role: .assistant, content: "No OpenRouter API key found. Add your key in Settings → Cloud API Keys."),
                    to: conversationId
                )
            } catch OpenRouterError.httpError(let code) {
                self.appendMessage(
                    Message(role: .assistant, content: "OpenRouter API error (HTTP \(code)). Check your API key and try again."),
                    to: conversationId
                )
            } catch {
                self.appendMessage(
                    Message(role: .assistant, content: "⚠️ \(error.localizedDescription)"),
                    to: conversationId
                )
            }
        }
        activeTasks[conversationId] = task
    }

    private func streamOpenRouterReply(for conversationId: UUID, modelID: String) async throws {
        guard let conv = fetchConversation(conversationId) else { return }

        let contextMessages = conv.messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

        let placeholder = Message(role: .assistant, content: "")
        appendMessage(placeholder, to: conversationId)

        // Accumulate tokens and flush to the model object in batches.
        // This prevents a per-token SwiftData fetch + full SwiftUI layout pass,
        // which was causing UI freezes and garbled output at high token rates.
        var tokenBuffer = ""
        var tokenCount  = 0
        let batchSize   = 6

        try await OpenRouterService.stream(
            modelID: modelID,
            messages: contextMessages,
            systemPrompt: writeVibeSystemPrompt,
            onToken: { token in
                tokenBuffer += token
                tokenCount  += 1
                if tokenCount >= batchSize {
                    placeholder.content += tokenBuffer
                    tokenBuffer = ""
                    tokenCount  = 0
                }
            }
        )

        // Flush any tokens that didn't fill a complete batch
        if !tokenBuffer.isEmpty { placeholder.content += tokenBuffer }
        // Write timestamp once after the stream finishes, not on every token
        if let c = fetchConversation(conversationId) { c.updatedAt = Date() }
        do {
            try modelContext?.save()
        } catch {
            reportIssue("Failed to save streamed response: \(error.localizedDescription)")
        }
    }

    private func streamOllamaReply(for conversationId: UUID) async throws {
        guard let conv = fetchConversation(conversationId),
              let modelName = conv.ollamaModelName, !modelName.isEmpty
        else {
            appendMessage(
                Message(role: .assistant, content: "No Ollama model selected. Choose a model from the model picker."),
                to: conversationId
            )
            return
        }

        let messages = conv.messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

        let placeholder = Message(role: .assistant, content: "")
        appendMessage(placeholder, to: conversationId)

        // Same batching strategy as streamOpenRouterReply — avoid per-token fetch and re-renders
        var tokenBuffer = ""
        var tokenCount  = 0
        let batchSize   = 6

        try await OllamaService.stream(
            modelName: modelName,
            messages: messages,
            systemPrompt: writeVibeSystemPrompt,
            onToken: { token in
                tokenBuffer += token
                tokenCount  += 1
                if tokenCount >= batchSize {
                    placeholder.content += tokenBuffer
                    tokenBuffer = ""
                    tokenCount  = 0
                }
            }
        )

        if !tokenBuffer.isEmpty { placeholder.content += tokenBuffer }
        if let c = fetchConversation(conversationId) { c.updatedAt = Date() }
        do {
            try modelContext?.save()
        } catch {
            reportIssue("Failed to save streamed response: \(error.localizedDescription)")
        }
    }

    func refreshOllamaModels() async {
        guard await OllamaService.isRunning() else {
            availableOllamaModels = []
            return
        }
        availableOllamaModels = (try? await OllamaService.installedModels()) ?? []
    }

    func migrateLegacyConversationModels() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>()
        guard let conversations = try? modelContext.fetch(descriptor) else {
            reportIssue("Failed to load conversations for migration")
            return
        }

        var changed = false
        for conv in conversations where conv.model == .appleIntelligence {
            conv.model = .ollama
            if conv.ollamaModelName == nil || conv.ollamaModelName?.isEmpty == true {
                conv.ollamaModelName = defaultOllamaModelName
            }
            conv.updatedAt = Date()
            changed = true
        }

        if changed {
            do {
                try modelContext.save()
                clearRuntimeIssue()
            } catch {
                reportIssue("Failed to migrate legacy conversations: \(error.localizedDescription)")
            }
        }
    }

    private func finishGeneration(for conversationId: UUID) {
        activeTasks.removeValue(forKey: conversationId)
        if thinkingId == conversationId { thinkingId = nil }
    }

    // MARK: - Export

    func exportLastAssistantMessage(from conversationId: UUID) -> String? {
        guard let conv = fetchConversation(conversationId) else { return nil }
        return conv.messages.last(where: { $0.role == .assistant })?.content
    }

    func buildMarkdownExport(for conversationId: UUID) -> String {
        guard let conv = fetchConversation(conversationId) else { return "" }
        var markdown = ""
        for (index, msg) in conv.messages.enumerated() {
            let label = msg.role == .user ? "You" : "WriteVibe"
            markdown += "**\(label):** \(msg.content)\n\n"
            if index < conv.messages.count - 1 {
                markdown += "---\n\n"
            }
        }
        return markdown
    }

    // MARK: - Token Management

    func estimatedTokenUsage(for conversationId: UUID) -> Double {
        guard let conv = fetchConversation(conversationId) else { return 0.0 }
        let charCount = conv.messages.reduce(0) { $0 + $1.content.count }
        return Double(charCount) / 4.0
    }
}

