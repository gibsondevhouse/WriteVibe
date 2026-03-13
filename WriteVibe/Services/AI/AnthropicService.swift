//
//  AnthropicService.swift
//  WriteVibe
//

import Foundation

enum AnthropicError: Error {
    case missingAPIKey
    case httpError(Int)
    case decodingFailed
}

@MainActor
enum AnthropicService {
    static let apiBase = URL(string: "https://api.anthropic.com/v1/messages")!

    static func stream(
        messages: [[String: String]],
        model: String,
        systemPrompt: String,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let apiKey = KeychainService.load(key: "anthropic_api_key") else {
            throw AnthropicError.missingAPIKey
        }

        var request = URLRequest(url: apiBase)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "stream": true,
            "system": systemPrompt,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.decodingFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AnthropicError.httpError(httpResponse.statusCode)
        }

        for try await line in result.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataString = String(line.dropFirst(6))
            if dataString == "[DONE]" { break }

            guard let data = dataString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            if let type = json["type"] as? String {
                if type == "message_stop" { break }
                if type == "content_block_delta",
                   let delta = json["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String,
                   deltaType == "text_delta",
                   let text = delta["text"] as? String {
                    onToken(text)
                }
            }
        }
    }
}
