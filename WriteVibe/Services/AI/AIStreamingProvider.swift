//
//  AIStreamingProvider.swift
//  WriteVibe
//

import Foundation

/// Unified contract for all AI chat-streaming backends.
///
/// Conformers wrap their provider-specific HTTP/SSE logic and expose a
/// standard `AsyncThrowingStream` of token strings. The caller owns the
/// iteration and can cancel at any time by breaking out of the `for try await`
/// loop, which automatically cancels the underlying task.
protocol AIStreamingProvider: Sendable {
    /// Streams chat-completion token deltas from the provider.
    ///
    /// - Parameters:
    ///   - model: Provider-specific model identifier (e.g. OpenRouter model ID,
    ///            Ollama model name).
    ///   - messages: Conversation history as `[["role": "user", "content": "…"]]`.
    ///   - systemPrompt: System instruction prepended to the message array.
    /// - Returns: An `AsyncThrowingStream` that yields individual token strings.
    func stream(
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error>
}
