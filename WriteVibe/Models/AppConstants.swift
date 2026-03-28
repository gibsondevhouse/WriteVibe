//
//  AppConstants.swift
//  WriteVibe
//

import Foundation

enum AppConstants {
    /// Maximum tokens requested from cloud AI providers.
    static let maxOutputTokens = 2048

    /// Maximum characters accepted from document ingestion.
    static let maxInputChars = 8_000

    /// Number of tokens buffered before flushing to the SwiftData model.
    /// Prevents per-token SwiftUI re-renders.
    static let tokenBatchSize = 6

    /// Base URL for a locally running Ollama server.
    static let ollamaBaseURL = URL(string: "http://localhost:11434")!

    /// Anthropic API version header.
    static let anthropicAPIVersion = "2024-10-22"

    // MARK: - Token usage thresholds (fraction of context window)

    /// Show usage indicator.
    static let tokenWarningThreshold: Double = 0.5
    /// Turn usage indicator orange.
    static let tokenCautionThreshold: Double = 0.8
    /// Turn usage indicator red.
    static let tokenDangerThreshold: Double = 0.95
    /// Disable send button.
    static let tokenLimitThreshold: Double = 0.98

    // MARK: - Article word ceilings

    /// Target word counts per ArticleLength setting.
    static let wordCeilings: [String: Int] = [
        "brief": 300,
        "short": 500,
        "medium": 1_000,
        "standard": 2_000,
        "long": 5_000
    ]
}
