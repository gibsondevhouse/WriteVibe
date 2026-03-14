//
//  OpenRouterService.swift
//  WriteVibe
//

import Foundation

// MARK: - OpenRouterService

@MainActor
struct OpenRouterService: AIStreamingProvider {
    static let chatEndpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    nonisolated func stream(
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    guard let apiKey = KeychainService.load(key: "openrouter_api_key"), !apiKey.isEmpty else {
                        throw WriteVibeError.missingAPIKey(provider: "OpenRouter")
                    }

                    var request = URLRequest(url: Self.chatEndpoint)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("https://writevibe.app", forHTTPHeaderField: "HTTP-Referer")
                    request.setValue("WriteVibe", forHTTPHeaderField: "X-Title")

                    var fullMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
                    fullMessages.append(contentsOf: messages)

                    let body: [String: Any] = [
                        "model": model,
                        "messages": fullMessages,
                        "stream": true,
                        "max_tokens": AppConstants.maxOutputTokens
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw WriteVibeError.apiError(
                            provider: "OpenRouter",
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                            message: nil
                        )
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()

                        guard line.hasPrefix("data: ") else { continue }
                        let dataString = String(line.dropFirst(6))
                        if dataString == "[DONE]" { break }

                        guard let data = dataString.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String
                        else { continue }

                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
