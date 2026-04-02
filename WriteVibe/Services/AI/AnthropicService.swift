//
//  AnthropicService.swift
//  WriteVibe
//

import Foundation

struct AnthropicService: AIStreamingProvider {
    static let apiBase = URL(string: "https://api.anthropic.com/v1/messages")!

    static func makeRequest(
        apiKey: String,
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) throws -> URLRequest {
        var request = URLRequest(url: apiBase)
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
        return request
    }

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

                    let request = try Self.makeRequest(
                        apiKey: apiKey,
                        model: model,
                        messages: messages,
                        systemPrompt: systemPrompt
                    )

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
                        throw Self.mapAPIError(statusCode: httpResponse.statusCode, body: errorBody)
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

    static func mapAPIError(statusCode: Int, body: String) -> WriteVibeError {
        let parsedMessage = parseErrorMessage(from: body)

        let fallbackMessage: String?
        switch statusCode {
        case 400:
            fallbackMessage = "Anthropic rejected the request payload."
        case 401, 403:
            fallbackMessage = "Anthropic authentication failed for this request."
        case 404:
            fallbackMessage = "Anthropic could not find the requested model or endpoint."
        case 429:
            fallbackMessage = "Anthropic rate limited this request."
        case 500...599:
            fallbackMessage = "Anthropic is temporarily unavailable."
        default:
            fallbackMessage = nil
        }

        return .apiError(
            provider: "Anthropic",
            statusCode: statusCode,
            message: parsedMessage ?? fallbackMessage
        )
    }

    private static func parseErrorMessage(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let message = parseErrorMessageFromJSONString(trimmed) {
            return message
        }

        for rawLine in trimmed.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            let payload: String
            if line.hasPrefix("data: ") {
                payload = String(line.dropFirst(6))
            } else {
                payload = line
            }

            if let message = parseErrorMessageFromJSONString(payload) {
                return message
            }
        }

        return String(trimmed.prefix(200))
    }

    private static func parseErrorMessageFromJSONString(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        if let message = json["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        return nil
    }
}
