//
//  ConversationService.swift
//  WriteVibe
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ConversationService {

    // In-memory cache — SwiftData's fetch() can miss just-inserted objects
    private var cache: [UUID: Conversation] = [:]

    func fetch(_ id: UUID, context: ModelContext) -> Conversation? {
        if let cached = cache[id] { return cached }
        let descriptor = FetchDescriptor<Conversation>()
        guard let result = try? context.fetch(descriptor).first(where: { $0.id == id }) else { return nil }
        cache[id] = result
        return result
    }

    @discardableResult
    func create(model: AIModel, ollamaModelName: String?, context: ModelContext) -> Conversation {
        let conv = Conversation(model: model)
        if model == .ollama { conv.ollamaModelName = ollamaModelName }
        context.insert(conv)
        try? context.save()
        cache[conv.id] = conv
        return conv
    }

    func delete(_ id: UUID, context: ModelContext) {
        guard let conv = fetch(id, context: context) else { return }
        context.delete(conv)
        cache.removeValue(forKey: id)
    }

    func rename(_ id: UUID, to newTitle: String, context: ModelContext) {
        guard let conv = fetch(id, context: context) else { return }
        conv.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        conv.updatedAt = Date()
    }

    /// Appends a message and auto-titles on the first user message via Apple Intelligence.
    @discardableResult
    func appendMessage(_ message: Message, to conversationId: UUID, context: ModelContext) -> Bool {
        guard let conv = fetch(conversationId, context: context) else { return false }

        context.insert(message)
        conv.messages.append(message)
        conv.updatedAt = Date()

        if conv.messages.count == 1, message.role == .user {
            let snippet = String(message.content.prefix(45))
            let fallbackTitle = snippet.count < message.content.count ? snippet + "…" : snippet
            conv.title = fallbackTitle

            Task {
                if #available(macOS 26, *) {
                    do {
                        let newTitle = try await AppleIntelligenceService.generateTitle(userMessage: message.content)
                        if conv.title == fallbackTitle { conv.title = newTitle }
                    } catch {
                        // Keep fallback
                    }
                }
            }
        }

        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    /// Merges fetched conversations with in-memory cached ones for stable sidebar display.
    func mergedConversations(from fetched: [Conversation]) -> [Conversation] {
        var mergedByID: [UUID: Conversation] = [:]
        for conversation in fetched { mergedByID[conversation.id] = conversation }
        for (id, conversation) in cache where mergedByID[id] == nil { mergedByID[id] = conversation }
        return mergedByID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func migrateLegacyModels(context: ModelContext, defaultOllamaModelName: String?) {
        let descriptor = FetchDescriptor<Conversation>()
        guard let conversations = try? context.fetch(descriptor) else { return }

        var changed = false
        for conv in conversations where conv.model == .appleIntelligence {
            conv.model = .ollama
            if conv.ollamaModelName == nil || conv.ollamaModelName?.isEmpty == true {
                conv.ollamaModelName = defaultOllamaModelName
            }
            conv.updatedAt = Date()
            changed = true
        }

        if changed { try? context.save() }
    }
}
