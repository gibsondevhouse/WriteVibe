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
@available(macOS 26, *)
@MainActor
enum AppleIntelligenceService {

    /// True when Apple Intelligence is enabled and this hardware is eligible.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Temperature Constants

    /// Analytical tasks need low variance; creative tasks need high variance.
    enum GenerationTemperature {
        static let analytical: Double = 0.2   // titles, outlines, analysis
        static let balanced: Double   = 0.5   // summarize, suggestions
        static let creative: Double   = 0.9   // variants, improvements
    }

    // MARK: - Structured Generation

    @Generable
    struct ConversationTitle {
        var title: String
    }

    /// Generates a concise title for a conversation based on the first user message.
    static func generateTitle(userMessage: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a helpful assistant. Generate a short, concise title (3-6 words) for the user's message. Do not use quotes."
        )
        let response = try await session.respond(
            to: "Generate a title for this text: \(userMessage)",
            generating: ConversationTitle.self,
            options: options
        )
        return response.content.title
    }

    // MARK: - Utility Tasks

    /// Summarizes the given text concisely.
    static func summarize(_ text: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.balanced)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a helpful assistant. Summarize the following text concisely, capturing the main points."
        )
        let response = try await session.respond(to: text, options: options)
        return response.content
    }

    /// Provides writing suggestions for the given text.
    static func suggestImprovements(for text: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.balanced)
        let session = LanguageModelSession(
            instructions: "You are a helpful writing assistant. Provide 3-5 concise, actionable suggestions to improve the following text for clarity, tone, and impact. Format as a bulleted list."
        )
        let response = try await session.respond(to: text, options: options)
        return response.content
    }

    /// Analyzes the writing for tone, reading level, word count, readability, and suggestions.
    static func analyzeWriting(text: String) async throws -> WritingAnalysis {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            instructions: "You are a helpful writing assistant. Analyze the provided text and return a structured analysis including tone, reading level, word count, sentence count, average words per sentence, passive voice percentage (0–100), a Flesch-Kincaid readability score label, and actionable suggestions for improvement."
        )
        let response = try await session.respond(
            to: text,
            generating: WritingAnalysis.self,
            options: options
        )
        return response.content
    }

    // MARK: - Article Outline

    /// Generates a structured `ArticleOutline` from article metadata using Apple Intelligence.
    static func generateOutline(
        title: String,
        topic: String,
        audience: String,
        targetLength: String
    ) async throws -> ArticleOutline {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a professional content strategist. Generate a clear, logical article outline."
        )
        let prompt = "Article title: \(title)\nTopic: \(topic)\nTarget audience: \(audience)\nTarget length: \(targetLength)"
        let response = try await session.respond(
            to: prompt,
            generating: ArticleOutline.self,
            options: options
        )
        return response.content
    }

    // MARK: - Draft Variants

    /// Generates three distinct rewrites of the given passage, suitable for the Variants picker.
    static func generateVariants(for text: String, tone: String) async throws -> DraftVariants {
        let options = GenerationOptions(temperature: GenerationTemperature.creative)
        let session = LanguageModelSession(
            instructions: "You are a creative writing assistant. Generate exactly 3 distinct rewrites of the given text. Vary sentence structure, vocabulary, and phrasing significantly between each variant. Tone: \(tone)."
        )
        let response = try await session.respond(
            to: text,
            generating: DraftVariants.self,
            options: options
        )
        return response.content
    }

    // MARK: - Word Count Plan

    /// Estimates per-section word counts for an article given its outline and target length.
    static func generateWordCountPlan(
        title: String,
        outline: String,
        targetLength: String
    ) async throws -> WordCountPlan {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            instructions: "You are a professional editor. Estimate word counts per section for an article."
        )
        let prompt = "Article title: \(title)\nOutline:\n\(outline)\nTarget length: \(targetLength)"
        let response = try await session.respond(
            to: prompt,
            generating: WordCountPlan.self,
            options: options
        )
        return response.content
    }

    // MARK: - Streaming Analysis (progress indicator)

    /// Streams raw text tokens during writing analysis so the UI can show a typing indicator
    /// while the structured `analyzeWriting()` call completes in parallel.
    static func analyzeWritingStreaming(text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession(
                        instructions: "You are a helpful writing assistant. Briefly describe the writing style and key observations about the following text."
                    )
                    let stream = session.streamResponse(to: text)
                    for try await chunk in stream {
                        continuation.yield(chunk.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Prewarm

    /// Touches the default language model to encourage the OS to load its context into memory,
    /// reducing cold-start latency on the next structured generation call.
    /// Safe to call speculatively — fire-and-forget.
    static func prewarm(prefix: String = "") async {
        // FoundationModels does not yet expose a public prewarm API.
        // Accessing the model object is the closest available approximation.
        _ = SystemLanguageModel.default
    }
}
