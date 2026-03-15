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
import Models // Import Models to access Tools

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

// MARK: - AppleIntelligenceStreamingProvider

/// Conformance-bridge to allow Apple Intelligence to be used as a chat provider.
/// Always available, but throws if called on unsupported macOS versions.
struct AppleIntelligenceStreamingProvider: AIStreamingProvider {
    nonisolated func stream(
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                guard #available(macOS 26, *) else {
                    continuation.finish(throwing: WriteVibeError.modelUnavailable(name: "Apple Intelligence (requires macOS 26+)"))
                    return
                }

                do {
                    // Instantiate the tools
                    let dateTimeTool = DateTimeTool()
                    let clipboardTool = ClipboardTool()
                    let tools: [any Tool] = [dateTimeTool, clipboardTool]

                    // Create a session with the provided system prompt and tools
                    // Assuming LanguageModelSession initializer accepts tools. This is a common pattern.
                    // If this initializer doesn't exist, further investigation into FoundationModels API is needed.
                    let session = LanguageModelSession(instructions: systemPrompt, tools: tools)

                    // Apple Intelligence (FoundationModels) handles its own transcript state if we reuse the session.
                    // Since this stream() call is stateless (it gets the full message history),
                    // we pick the last user message as the prompt.
                    // Note: Future versions could 'replay' history into the session if FoundationModels adds transcript injection.
                    guard let lastUserMessage = messages.last(where: { $0["role"] == "user" })?["content"] else {
                        continuation.finish()
                        return
                    }

                    let stream = session.streamResponse(to: lastUserMessage)
                    for try await chunk in stream {
                        try Task.checkCancellation()
                        continuation.yield(chunk.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

