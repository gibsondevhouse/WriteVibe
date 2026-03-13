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
        // "llama3.2:8b" → "Llama 3.2 8B"
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

// MARK: - OllamaError

enum OllamaError: Error {
    case notRunning           // Ollama server not detected
    case httpError(Int)
    case decodingFailed
    case modelNotFound(String)
}

// MARK: - OllamaService

@MainActor
enum OllamaService {
    static let baseURL = URL(string: "http://localhost:11434")!

    // MARK: - Connection

    /// Returns true if the Ollama server is running and reachable.
    static func isRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/version") else { return false }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    // MARK: - Installed Models

    /// Returns the list of models currently installed in Ollama.
    static func installedModels() async throws -> [OllamaModel] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { throw OllamaError.notRunning }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.notRunning
        }
        struct TagsResponse: Decodable { let models: [OllamaModel] }
        guard let result = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            throw OllamaError.decodingFailed
        }
        return result.models
    }

    // MARK: - Pull (Download) a Model

    /// Downloads a model, streaming progress updates.
    static func pullModel(
        modelName: String,
        onProgress: @MainActor @escaping (OllamaPullProgress) -> Void,
        onComplete: @MainActor @escaping () -> Void,
        onError: @MainActor @escaping (Error) -> Void
    ) {
        Task {
            do {
                guard let url = URL(string: "\(baseURL)/api/pull") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["name": modelName, "stream": true])

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw OllamaError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
                }

                for try await line in bytes.lines {
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }

                    let status = json["status"] as? String ?? ""
                    let total = json["total"] as? Int64
                    let completed = json["completed"] as? Int64
                    let progress = OllamaPullProgress(status: status, total: total, completed: completed)
                    onProgress(progress)

                    if status == "success" {
                        onComplete()
                        return
                    }
                }
                onComplete()
            } catch {
                onError(error)
            }
        }
    }

    // MARK: - Delete a Model

    static func deleteModel(modelName: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/delete") else { throw OllamaError.notRunning }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": modelName])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Chat Streaming

    /// Streams a chat response from a locally running Ollama model.
    static func stream(
        modelName: String,
        messages: [[String: String]],
        systemPrompt: String,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw OllamaError.notRunning
        }

        guard await isRunning() else { throw OllamaError.notRunning }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var fullMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        fullMessages.append(contentsOf: messages)

        let body: [String: Any] = [
            "model": modelName,
            "messages": fullMessages,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OllamaError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

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
