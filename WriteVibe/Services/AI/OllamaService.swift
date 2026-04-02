//
//  OllamaService.swift
//  WriteVibe
//

import Foundation

// MARK: - OllamaModel

struct OllamaModel: Identifiable, Decodable {
    let name: String           // e.g. "llama3.2:8b"
    let size: Int64            // bytes
    let modifiedAt: String     // ISO8601 string from API

    var id: String { name }

    var displayName: String {
        name.split(separator: ":").first
            .map { String($0).replacingOccurrences(of: "-", with: " ").capitalized }
            ?? name
    }

    var sizeFormatted: String {
        let gb = Double(size) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(size) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    /// Embedding models don't support /v1/chat/completions — exclude them from the chat picker.
    var isEmbeddingModel: Bool {
        let lower = name.lowercased()
        return lower.contains("embed") || lower.hasPrefix("nomic-")
    }

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case modifiedAt = "modified_at"
    }
}

// MARK: - OllamaPullProgress

struct OllamaPullProgress {
    let status: String       // e.g. "downloading", "verifying sha256", "success"
    let total: Int64?
    let completed: Int64?

    var fraction: Double {
        guard let t = total, let c = completed, t > 0 else { return 0 }
        return Double(c) / Double(t)
    }
}

// MARK: - OllamaService

struct OllamaService: AIStreamingProvider {
    static let baseURL = AppConstants.ollamaBaseURL

    static let modelNamePattern = #"^[a-zA-Z0-9._:/\-]+$"#

    static func validateModelName(_ name: String) throws {
        guard !name.isEmpty,
              name.count <= 128,
              name.range(of: modelNamePattern, options: .regularExpression) != nil
        else {
            throw WriteVibeError.modelUnavailable(name: "Invalid model name")
        }
    }

    // MARK: - Connection

    static func isRunning() async -> Bool {
        let url = Self.baseURL.appendingPathComponent("api/version")
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    // MARK: - Installed Models

    static func installedModels() async throws -> [OllamaModel] {
        let url = Self.baseURL.appendingPathComponent("api/tags")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WriteVibeError.modelUnavailable(name: "Ollama server")
        }
        struct TagsResponse: Decodable { let models: [OllamaModel] }
        guard let result = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            throw WriteVibeError.decodingFailed(context: "Ollama installed models response")
        }
        return result.models
    }

    // MARK: - Pull (Download) a Model

    static func pullModel(modelName: String) -> AsyncThrowingStream<OllamaPullProgress, Error> {
        AsyncThrowingStream { continuation in
            let producerTask = Task {
                do {
                    try Self.validateModelName(modelName)
                    let url = Self.baseURL.appendingPathComponent("api/pull")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["name": modelName, "stream": true])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw WriteVibeError.apiError(
                            provider: "Ollama",
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                            message: "Pull failed for \(modelName)"
                        )
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()

                        guard let data = line.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        let status = json["status"] as? String ?? ""
                        let total = json["total"] as? Int64
                        let completed = json["completed"] as? Int64
                        let progress = OllamaPullProgress(status: status, total: total, completed: completed)
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                producerTask.cancel()
            }
        }
    }

    // MARK: - Delete a Model

    static func deleteModel(modelName: String) async throws {
        try Self.validateModelName(modelName)
        let url = Self.baseURL.appendingPathComponent("api/delete")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": modelName])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WriteVibeError.apiError(
                provider: "Ollama",
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                message: "Delete failed for \(modelName)"
            )
        }
    }

    // MARK: - Chat Streaming (AIStreamingProvider)

    func stream(
        model: String,
        messages: [[String: String]],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let producerTask = Task {
                do {
                    try Self.validateModelName(model)
                    let url = Self.baseURL.appendingPathComponent("v1/chat/completions")

                    guard await Self.isRunning() else {
                        throw WriteVibeError.modelUnavailable(name: "Ollama server is not running")
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    var fullMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
                    fullMessages.append(contentsOf: messages)

                    let body: [String: Any] = [
                        "model": model,
                        "messages": fullMessages,
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw WriteVibeError.apiError(
                            provider: "Ollama",
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

            continuation.onTermination = { @Sendable _ in
                producerTask.cancel()
            }
        }
    }
}
