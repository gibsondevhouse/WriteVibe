//
//  OpenRouterService.swift
//  WriteVibe
//

import Foundation

// MARK: - OpenRouterError

enum OpenRouterError: Error {
    case missingAPIKey
    case httpError(Int)
    case decodingFailed
}

// MARK: - OpenRouterService

@MainActor
enum OpenRouterService {
    static let chatEndpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// Streams a chat completion from OpenRouter using the OpenAI-compatible SSE format.
    /// - Parameters:
    ///   - modelID: OpenRouter model identifier, e.g. "anthropic/claude-3-7-sonnet"
    ///   - messages: Conversation history as role/content pairs
    ///   - systemPrompt: System instruction prepended to the message array
    ///   - onToken: Called on @MainActor with each streamed text delta
    static func stream(
        modelID: String,
        messages: [[String: String]],
        systemPrompt: String,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let apiKey = KeychainService.load(key: "openrouter_api_key"), !apiKey.isEmpty else {
            throw OpenRouterError.missingAPIKey
        }

        var request = URLRequest(url: chatEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenRouter recommends these headers for request attribution
        request.setValue("https://writevibe.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("WriteVibe", forHTTPHeaderField: "X-Title")

        var fullMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        fullMessages.append(contentsOf: messages)

        let body: [String: Any] = [
            "model": modelID,
            "messages": fullMessages,
            "stream": true,
            "max_tokens": 2048
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OpenRouterError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // OpenRouter uses the same SSE format as OpenAI
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataString = String(line.dropFirst(6))
            if dataString == "[DONE]" { break }

            guard let data = dataString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            try Task.checkCancellation()
            onToken(content)
        }
    }
}
