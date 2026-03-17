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

/// Namespace wrapping FoundationModels for on-device utility generation.
/// Used for conversation auto-title, summarization, and writing suggestions.
/// Also provides a streaming implementation for on-device chat fallback.
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
    static func generateTitle(userMessage: String) async throws -> String {
        // Note: Tools are not typically passed to these utility methods as they are self-contained.
        let session = LanguageModelSession(instructions: "You are a helpful assistant. Generate a short, concise title (3-6 words) for the user's message. Do not use quotes.")
        let response = try await session.respond(
            to: "Generate a title for this text: \(userMessage)",
            generating: ConversationTitle.self
        )
        return response.content.title
    }

    // MARK: - Utility Tasks

    /// Summarizes the given text concisely.
    static func summarize(_ text: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You are a helpful assistant. Summarize the following text concisely, capturing the main points.")
        let response = try await session.respond(to: text)
        return response.content
    }

    /// Provides writing suggestions for the given text.
    static func suggestImprovements(for text: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You are a helpful writing assistant. Provide 3-5 concise, actionable suggestions to improve the following text for clarity, tone, and impact. Format as a bulleted list.")
        let response = try await session.respond(to: text)
        return response.content
    }

    /// Analyzes the writing for tone, reading level, word count, and suggestions.
    static func analyzeWriting(text: String) async throws -> WritingAnalysis {
        let session = LanguageModelSession(instructions: "You are a helpful writing assistant. Analyze the provided text and return a structured analysis including tone, reading level, word count, and actionable suggestions for improvement.")
        let response = try await session.respond(
            to: text,
            generating: WritingAnalysis.self
        )
        return response.content
    }
}
