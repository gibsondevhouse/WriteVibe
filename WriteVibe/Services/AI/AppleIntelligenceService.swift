//
//  AppleIntelligenceService.swift
//  WriteVibe
//
//  Sole file that imports FoundationModels. Used only for utility generation tasks
//  (e.g. auto-title). Chat routing goes through OllamaService or OpenRouterService.
//  AppState calls in via the static methods below.
//

import Foundation
import FoundationModels

// MARK: - AppleIntelligenceService

/// Static namespace wrapping FoundationModels for on-device utility generation.
/// Currently used only for conversation auto-title. Not used for chat responses.
/// All members are @MainActor-isolated — safe to call from AppState without dispatch.
@available(macOS 26, *)
@MainActor
enum AppleIntelligenceService {

    /// True when Apple Intelligence is enabled and this hardware is eligible.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Structured Generation

    @Generable
    struct ConversationTitle {
        var title: String
    }

    /// Generates a concise title for a conversation based on the first user message.
    /// Uses a temporary session to avoid polluting any persistent chat history.
    static func generateTitle(userMessage: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You are a helpful assistant. Generate a short, concise title (3-6 words) for the user's message. Do not use quotes.")
        let response = try await session.respond(
            to: "Generate a title for this text: \(userMessage)",
            generating: ConversationTitle.self
        )
        return response.content.title
    }
}

