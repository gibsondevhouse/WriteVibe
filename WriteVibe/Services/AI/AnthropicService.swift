//
//  AnthropicService.swift
//  WriteVibe
//

import Foundation

struct AnthropicService: AIStreamingProvider {
    static let apiBase = URL(string: "https://api.anthropic.com/v1/messages")!

    func stream(
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = KeychainService.load(key: "anthropic_api_key") else {
                        throw WriteVibeError.missingAPIKey(provider: "Anthropic")
                    }

                    var request = URLRequest(url: Self.apiBase)
                    request.httpMethod = "POST"
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(AppConstants.anthropicAPIVersion, forHTTPHeaderField: "anthropic-version")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": AppConstants.maxOutputTokens,
                        "stream": true,
                        "system": systemPrompt,
                        "messages": messages
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (result, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw WriteVibeError.decodingFailed(context: "Invalid response from Anthropic")
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorBody = ""
                        for try await line in result.lines {
                            errorBody += line
                            if errorBody.count > 4096 { break }
                        }
                        throw WriteVibeError.apiError(
                            provider: "Anthropic",
                            statusCode: httpResponse.statusCode,
                            message: Self.parseErrorMessage(from: errorBody)
                        )
                    }

                    for try await line in result.lines {
                        try Task.checkCancellation()

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
                                continuation.yield(text)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func parseErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String
        else {
            return body.isEmpty ? nil : String(body.prefix(200))
        }
        return message
    }
}
