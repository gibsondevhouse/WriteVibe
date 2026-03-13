//
//  AppState.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - AppState

@MainActor
@Observable
final class AppState {
    var selectedId: UUID?             = nil
    var thinkingId: UUID?             = nil
    var availableOllamaModels: [OllamaModel] = []
    var pendingPrompt: String? = nil

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

    // In-flight generation tasks keyed by conversation ID — enables stop-button cancellation
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    var selected: Conversation? {
        guard let selectedId, let modelContext else { return nil }
        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == selectedId })
        return try? modelContext.fetch(descriptor).first
    }

    var isThinkingInSelected: Bool {
        thinkingId != nil && thinkingId == selectedId
    }

    // MARK: Conversation management

    func fetchConversation(_ id: UUID) -> Conversation? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    func newConversation() -> UUID? {
        guard let modelContext else { return nil }
        let conv = Conversation(model: defaultModel)
        if defaultModel == .ollama { conv.ollamaModelName = defaultOllamaModelName }
        modelContext.insert(conv)
        selectedId = conv.id
        return conv.id
    }

    func deleteConversation(_ id: UUID) {
        stopGeneration(for: id)
        guard let conv = fetchConversation(id), let modelContext else { return }
        modelContext.delete(conv)
        if selectedId == id { selectedId = nil }
    }

    func renameConversation(_ id: UUID, to newTitle: String) {
        guard let conv = fetchConversation(id) else { return }
        conv.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        conv.updatedAt = Date()
    }

    // MARK: Messaging

    func send(_ text: String, in conversationId: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, thinkingId != conversationId else { return }

        // Append user message
        appendMessage(Message(role: .user, content: trimmed), to: conversationId)

        thinkingId = conversationId
        generateReply(to: conversationId)
    }

    func appendMessage(_ message: Message, to conversationId: UUID) {
        guard let conv = fetchConversation(conversationId) else { return }
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
    }

    // MARK: - AI Generation

    func stopGeneration(for conversationId: UUID) {
        activeTasks[conversationId]?.cancel()
        finishGeneration(for: conversationId)
    }

    private func generateReply(to conversationId: UUID) {
        guard let conv = fetchConversation(conversationId) else { return }
        let model = conv.model
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.finishGeneration(for: conversationId) }
            do {
                if model == .ollama {
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
    }

    func refreshOllamaModels() async {
        guard await OllamaService.isRunning() else {
            availableOllamaModels = []
            return
        }
        availableOllamaModels = (try? await OllamaService.installedModels()) ?? []
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
