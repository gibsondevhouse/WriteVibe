# WriteVibe — Phase 3 Development Sprint
# Ollama Local Models + Additional Cloud Backends
_Coding agent prompt. Execute all tasks in order. Do not skip sections._

---

## Context & Architecture Rules

Before writing any code, re-read these constraints:

- `FoundationModels` is only imported in `AppleIntelligenceService.swift`. No other file may import it.
- All UI mutations must be on `@MainActor`. Async work uses `Task` + `await`.
- `AppState` is the single logic controller. Views call into `AppState` and use `@Query` for reactive data.
- `AnthropicService.swift` and `KeychainService.swift` exist and are working. Do not modify them unless a task explicitly requires it.
- `SettingsView.swift` currently handles one API key (Anthropic). It will be expanded in Task 5.
- `AIModel` is a fixed `enum` in `Item.swift` stored as a `Codable` string on `Conversation`. This must be extended carefully — see Task 1 for the migration strategy.
- After each task, the app must build cleanly with no new warnings.

---

## Background: How Ollama Works

Ollama is a free, open-source local model runner. When installed, it exposes a local REST server at `http://localhost:11434`. WriteVibe communicates with it over localhost — no internet required after models are downloaded.

**Endpoints used:**
- `GET  /api/version`              — check if Ollama is running
- `GET  /api/tags`                 — list installed models
- `POST /api/pull`                 — download a model (streams progress as NDJSON)
- `DELETE /api/delete`             — remove a model
- `POST /v1/chat/completions`      — OpenAI-compatible streaming chat (same SSE format as OpenAI)

The chat endpoint accepts the same JSON shape as OpenAI: `{ model, messages, stream: true }`.
Ollama has no API key, no billing, and no credits. It is entirely free.

---

## Task 1 — Data Model Migration: Support Dynamic Ollama Models

### The problem
`AIModel` is a fixed `enum` with cases like `.appleIntelligence`, `.claude35Sonnet`, etc. Ollama models are dynamic — users can install any model (`llama3.2`, `mistral`, `gemma3`, `phi4`, etc.) and the app cannot know them at compile time.

### Solution: Add `.ollama` case + `ollamaModelName` field on `Conversation`

#### 1a. Extend AIModel in `Item.swift`

Add one new case to the `AIModel` enum:

```swift
case ollama = "Ollama"
```

Update `subtitle`:
```swift
case .ollama: return "Local · Private · Free"
```

Update `icon`:
```swift
case .ollama: return "desktopcomputer"
```

#### 1b. Add `ollamaModelName` to the `Conversation` SwiftData model

In the `Conversation` `@Model` class, add:

```swift
var ollamaModelName: String?
```

This field stores the specific Ollama model string (e.g. `"llama3.2:8b"`) when `model == .ollama`. For all other model cases it is `nil`.

**SwiftData migration note:** Adding an optional property to a `@Model` class is a lightweight migration — SwiftData handles this automatically without a versioned schema. No `VersionedSchema` or `MigrationPlan` is required. Verify this builds cleanly.

#### 1c. Add a helper to AIModel for display

```swift
var isLocal: Bool {
    self == .appleIntelligence || self == .ollama
}

var requiresAPIKey: Bool {
    switch self {
    case .appleIntelligence, .ollama: return false
    default: return true
    }
}
```

---

## Task 2 — OllamaService.swift

Create `OllamaService.swift`. This file handles all communication with the local Ollama server.

```swift
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
    /// - Parameters:
    ///   - modelName: e.g. "llama3.2:8b"
    ///   - onProgress: called on @MainActor with each progress update
    ///   - onComplete: called on @MainActor when download succeeds
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
                onComplete() // stream ended without explicit "success" — treat as done
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

    // MARK: - Chat Streaming (OpenAI-compatible)

    /// Streams a chat response from a locally running Ollama model.
    /// Uses the /v1/chat/completions endpoint (OpenAI-compatible SSE format).
    static func stream(
        modelName: String,
        messages: [[String: String]],
        systemPrompt: String,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw OllamaError.notRunning
        }

        // Verify Ollama is running before attempting generation
        guard await isRunning() else { throw OllamaError.notRunning }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepend system message
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

        // Parse OpenAI-compatible SSE
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
```

---

## Task 3 — Wire Ollama into AppState

In `Item.swift`, add `streamOllamaReply()` to `AppState` and update the routing in `generateReply()`.

#### 3a. Add `streamOllamaReply` to AppState

```swift
private func streamOllamaReply(for conversationId: UUID) async throws {
    guard let conv = fetchConversation(conversationId),
          let modelName = conv.ollamaModelName, !modelName.isEmpty
    else {
        appendMessage(
            Message(role: .assistant, content: "No Ollama model selected. Choose a model from the model picker."),
            to: conversationId
        )
        return
    }

    let messages = conv.messages
        .filter { !$0.content.isEmpty }
        .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

    let placeholder = Message(role: .assistant, content: "")
    appendMessage(placeholder, to: conversationId)
    let placeholderId = placeholder.id

    try await OllamaService.stream(
        modelName: modelName,
        messages: messages,
        systemPrompt: writeVibeSystemPrompt,
        onToken: { [weak self] token in
            guard let self,
                  let conv = self.fetchConversation(conversationId),
                  let msg = conv.messages.first(where: { $0.id == placeholderId })
            else { return }
            msg.content += token
            conv.updatedAt = Date()
        }
    )
}
```

#### 3b. Update generateReply routing

In the `do` block inside `generateReply(to:)`, add the Ollama branch **after** the Apple Intelligence branch and **before** the Anthropic branch:

```swift
} else if model == .ollama {
    try await self.streamOllamaReply(for: conversationId)
} else if model == .claude35Sonnet || model == .claude3Opus {
    // ... existing Anthropic branch
```

#### 3c. Add Ollama error handling to the catch chain

In the same `generateReply` task, add:

```swift
} catch OllamaError.notRunning {
    self.appendMessage(
        Message(role: .assistant, content: "Ollama is not running. Open the Ollama app on your Mac and try again. Download it free at ollama.com"),
        to: conversationId
    )
} catch OllamaError.httpError(let code) {
    self.appendMessage(
        Message(role: .assistant, content: "Ollama returned an error (HTTP \(code)). Make sure the model is fully downloaded and try again."),
        to: conversationId
    )
}
```

---

## Task 4 — OllamaModelBrowserView.swift

Create `OllamaModelBrowserView.swift`. This is the in-app model management UI — users can check Ollama's status, see installed models, download new ones, and delete ones they don't need, all without leaving WriteVibe.

### 4a. Curated model library

Define this static list at the top of the file (outside the View):

```swift
struct CuratedModel {
    let name: String        // Ollama pull name, e.g. "llama3.2:8b"
    let displayName: String
    let description: String
    let sizeLabel: String
    let tags: [String]
}

let curatedModels: [CuratedModel] = [
    CuratedModel(name: "llama3.2:3b",   displayName: "Llama 3.2 3B",   description: "Fast general chat. Great on any Mac.",              sizeLabel: "~2 GB",  tags: ["Fast", "General"]),
    CuratedModel(name: "llama3.2:8b",   displayName: "Llama 3.2 8B",   description: "Solid all-rounder. Best balance of speed/quality.", sizeLabel: "~5 GB",  tags: ["Balanced", "General"]),
    CuratedModel(name: "mistral:7b",    displayName: "Mistral 7B",     description: "Strong instruction following. Great for writing.",  sizeLabel: "~4 GB",  tags: ["Writing", "Balanced"]),
    CuratedModel(name: "gemma3:4b",     displayName: "Gemma 3 4B",     description: "Fast, clean writing quality. Made by Google.",      sizeLabel: "~3 GB",  tags: ["Fast", "Writing"]),
    CuratedModel(name: "phi4:14b",      displayName: "Phi-4 14B",      description: "High quality. Requires M2 or later.",               sizeLabel: "~9 GB",  tags: ["Quality", "M2+"]),
    CuratedModel(name: "qwen2.5:7b",    displayName: "Qwen 2.5 7B",    description: "Strong writing, editing, and summarization.",       sizeLabel: "~5 GB",  tags: ["Writing", "Balanced"]),
]
```

### 4b. View structure

```swift
struct OllamaModelBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ollamaRunning: Bool? = nil        // nil = checking
    @State private var installedModels: [OllamaModel] = []
    @State private var downloadProgress: [String: Double] = [:]   // modelName → 0.0...1.0
    @State private var downloadStatus: [String: String] = [:]     // modelName → status string
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        installedSection
                        librarySection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Local Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshStatus() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .frame(width: 520, height: 620)
        .task { await refreshStatus() }
    }
```

### 4c. Connection banner

```swift
    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Group {
                if let running = ollamaRunning {
                    Image(systemName: running ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(running ? .green : .orange)
                    Text(running ? "Ollama is running" : "Ollama not detected")
                        .font(.callout)
                        .fontWeight(.medium)
                    if !running {
                        Spacer()
                        Link("Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                            .font(.callout)
                    }
                } else {
                    ProgressView().scaleEffect(0.7)
                    Text("Checking for Ollama…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ollamaRunning == false ? Color.orange.opacity(0.08) : Color.clear)
    }
```

### 4d. Installed models section

```swift
    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installed")
                .font(.headline)

            if installedModels.isEmpty {
                Text(ollamaRunning == true ? "No models installed yet. Download one below." : "Start Ollama to see installed models.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(installedModels) { model in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(model.sizeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                try? await OllamaService.deleteModel(modelName: model.name)
                                await refreshStatus()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(model.displayName)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
```

### 4e. Library section

```swift
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommended Models")
                .font(.headline)
            Text("Download once, run forever. No internet required after download.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(curatedModels, id: \.name) { model in
                let isInstalled = installedModels.contains(where: { $0.name == model.name })
                let progress = downloadProgress[model.name]
                let status = downloadStatus[model.name]

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.callout)
                                .fontWeight(.medium)
                            ForEach(model.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.tint)
                            }
                        }
                        Text(model.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(model.sizeLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if let progress, let status {
                            VStack(alignment: .leading, spacing: 3) {
                                ProgressView(value: progress)
                                    .progressViewStyle(.linear)
                                    .frame(maxWidth: 200)
                                Text(status)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    Spacer()
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .help("Installed")
                    } else if progress != nil {
                        Button("Cancel") {
                            // For now — mark as cancelled in state
                            downloadProgress.removeValue(forKey: model.name)
                            downloadStatus.removeValue(forKey: model.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Download") {
                            downloadModel(model.name)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(ollamaRunning != true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
```

### 4f. Actions

```swift
    private func refreshStatus() async {
        isRefreshing = true
        ollamaRunning = await OllamaService.isRunning()
        if ollamaRunning == true {
            installedModels = (try? await OllamaService.installedModels()) ?? []
        }
        isRefreshing = false
    }

    private func downloadModel(_ modelName: String) {
        downloadProgress[modelName] = 0.0
        downloadStatus[modelName] = "Starting download…"

        OllamaService.pullModel(
            modelName: modelName,
            onProgress: { progress in
                downloadProgress[modelName] = progress.fraction
                downloadStatus[modelName] = progress.status.capitalized
            },
            onComplete: {
                downloadProgress.removeValue(forKey: modelName)
                downloadStatus.removeValue(forKey: modelName)
                Task { await refreshStatus() }
            },
            onError: { error in
                downloadProgress.removeValue(forKey: modelName)
                downloadStatus[modelName] = "Download failed"
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    downloadStatus.removeValue(forKey: modelName)
                }
            }
        )
    }
}
```

---

## Task 5 — Model Picker: Dynamic Ollama Models

The current model picker in `ChatView.swift` is a static `Picker` over `AIModel.allCases`. It needs to dynamically show installed Ollama models as selectable options when Ollama is running.

### 5a. Add `ollamaModels` observable state to AppState in `Item.swift`

```swift
// In AppState
var availableOllamaModels: [OllamaModel] = []

func refreshOllamaModels() async {
    guard await OllamaService.isRunning() else {
        availableOllamaModels = []
        return
    }
    availableOllamaModels = (try? await OllamaService.installedModels()) ?? []
}
```

Call `refreshOllamaModels()` in `WriteVibeApp.swift`'s `.task` modifier on the root view so it populates on launch.

### 5b. Update the model picker in `ChatView.swift`

Replace the existing `Picker("Model", selection: Bindable(conv).model)` toolbar item with a custom `Menu` that handles both static models and dynamic Ollama models:

```swift
ToolbarItem {
    if let conv = conversation {
        Menu {
            // Static cloud/on-device models (excluding .ollama placeholder)
            Section("On-Device") {
                Button {
                    conv.model = .appleIntelligence
                    conv.ollamaModelName = nil
                } label: {
                    HStack {
                        Label(AIModel.appleIntelligence.rawValue, systemImage: AIModel.appleIntelligence.icon)
                        if conv.model == .appleIntelligence {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Section("Local (Ollama)") {
                if appState.availableOllamaModels.isEmpty {
                    Button("No models installed") { }
                        .disabled(true)
                    Button("Manage Local Models…") {
                        // set a @State var to show the browser sheet
                        showOllamaModelBrowser = true
                    }
                } else {
                    ForEach(appState.availableOllamaModels) { ollamaModel in
                        Button {
                            conv.model = .ollama
                            conv.ollamaModelName = ollamaModel.name
                        } label: {
                            HStack {
                                Label(ollamaModel.displayName, systemImage: "desktopcomputer")
                                if conv.model == .ollama && conv.ollamaModelName == ollamaModel.name {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Manage Local Models…") {
                        showOllamaModelBrowser = true
                    }
                }
            }

            Section("Cloud") {
                ForEach([AIModel.claude35Sonnet, .claude3Opus, .gpt4o, .mistralLarge, .gemini15Pro], id: \.self) { model in
                    Button {
                        conv.model = model
                        conv.ollamaModelName = nil
                    } label: {
                        HStack {
                            Label(model.rawValue, systemImage: model.icon)
                            if conv.model == model {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: currentModelIcon(for: conv))
                    .font(.system(size: 11))
                Text(currentModelLabel(for: conv))
                    .font(.callout)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .help("Select AI model")
        .sheet(isPresented: $showOllamaModelBrowser) {
            OllamaModelBrowserView()
                .onDisappear {
                    Task { await appState.refreshOllamaModels() }
                }
        }
    }
}
```

Add these helper functions and state to `ChatView`:

```swift
@State private var showOllamaModelBrowser = false

private func currentModelLabel(for conv: Conversation) -> String {
    if conv.model == .ollama, let name = conv.ollamaModelName {
        return name.split(separator: ":").first.map(String.init) ?? name
    }
    return conv.model.rawValue
}

private func currentModelIcon(for conv: Conversation) -> String {
    conv.model.icon
}
```

Also add `.task` to `ChatView.body` to refresh Ollama models when the view appears:

```swift
.task {
    await appState.refreshOllamaModels()
}
```

---

## Task 6 — Expand SettingsView for Ollama and Future Cloud Keys

`SettingsView.swift` currently only handles the Anthropic key. Expand it to:

1. Add a **"Local Models"** section at the top:
   - Ollama connection status indicator (live check on `.task`)
   - A "Manage Models →" button that presents `OllamaModelBrowserView` as a sheet

2. Rename the existing `"API Keys"` section to `"Cloud API Keys"` and add a caption explaining that keys are stored in the macOS Keychain.

3. Add a placeholder `SecureField` for OpenAI API Key (`"openai_api_key"`) below the Anthropic field. Style it identically. This primes the architecture for GPT-4o integration in Phase 4.

Updated `SettingsView` structure:

```swift
Form {
    Section("Local Models") {
        HStack {
            Image(systemName: ollamaRunning ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ollamaRunning ? .green : .secondary)
            Text(ollamaRunning ? "Ollama is running" : "Ollama not detected")
                .font(.callout)
            Spacer()
            Button("Manage Models…") { showOllamaModelBrowser = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .task { ollamaRunning = await OllamaService.isRunning() }
    }

    Section {
        VStack(alignment: .leading, spacing: 12) {
            apiKeyField(label: "Anthropic API Key", text: $anthropicKey, keychainKey: "anthropic_api_key")
            Divider()
            apiKeyField(label: "OpenAI API Key", text: $openAIKey, keychainKey: "openai_api_key")
        }
        Text("Keys are stored securely in the macOS Keychain and never leave your device.")
            .font(.caption)
            .foregroundStyle(.secondary)
    } header: {
        Text("Cloud API Keys")
    }
}
```

Extract a reusable `apiKeyField` helper to keep the form clean:

```swift
@ViewBuilder
private func apiKeyField(label: String, text: Binding<String>, keychainKey: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        SecureField("Paste key here", text: text)
            .textFieldStyle(.roundedBorder)
            .onChange(of: text.wrappedValue) {
                KeychainService.save(key: keychainKey, value: text.wrappedValue)
            }
    }
}
```

Remove the separate Save button — keys now save automatically on change (Keychain writes are fast and synchronous).

Add the necessary `@State` properties:
```swift
@State private var openAIKey: String = ""
@State private var ollamaRunning: Bool = false
@State private var showOllamaModelBrowser = false
```

Load both keys in `.onAppear`:
```swift
.onAppear {
    anthropicKey = KeychainService.load(key: "anthropic_api_key") ?? ""
    openAIKey = KeychainService.load(key: "openai_api_key") ?? ""
}
```

---

## Task 7 — WriteVibeApp.swift: Launch-time Ollama Refresh

Open `WriteVibeApp.swift` and inject a `.task` on the root `WindowGroup` content view to load available Ollama models at startup:

```swift
// In the root view's modifiers:
.task {
    await appState.refreshOllamaModels()
}
```

This ensures the model picker is populated immediately when the app opens, without requiring the user to open Settings first.

---

## Acceptance Criteria

Before considering this sprint complete, verify:

- [x] `AIModel.ollama` case exists and is selectable in the model picker
- [x] `Conversation.ollamaModelName` persists correctly via SwiftData with no migration errors
- [x] When Ollama is not running, selecting an Ollama model and sending a message returns a clear "not running" error with a download link
- [x] When Ollama is running and a model is installed, chat streaming works correctly with token-by-token updates
- [x] `OllamaModelBrowserView` shows the correct connection status within 2 seconds of opening
- [x] Installed models list reflects the actual state of Ollama's installed models
- [x] Tapping "Download" on a curated model shows a real-time progress bar and the model appears in the installed list on completion
- [x] Tapping the trash icon on an installed model removes it from Ollama and updates the list
- [x] The model picker in ChatView correctly shows Ollama models in a "Local" section and cloud models in a "Cloud" section
- [x] Selecting an Ollama model and switching conversations preserves the model selection
- [x] SettingsView shows Ollama connection status and a "Manage Models" button
- [x] OpenAI key field is present in SettingsView and saves to Keychain on change
- [x] Apple Intelligence and Anthropic paths are completely unaffected by all of the above changes
- [x] App builds cleanly on macOS 26+ with no new warnings

---

## File Change Summary

| File | Action |
|---|---|
| `OllamaService.swift` | **Create** |
| `OllamaModelBrowserView.swift` | **Create** |
| `Item.swift` | Modify — add `.ollama` to `AIModel`, add `ollamaModelName` to `Conversation`, add `streamOllamaReply()` and `availableOllamaModels` + `refreshOllamaModels()` to `AppState`, add Ollama error handling to catch chain |
| `ChatView.swift` | Modify — replace static Picker with dynamic Menu, add `showOllamaModelBrowser` state, add `.task` for refresh |
| `SettingsView.swift` | Modify — add Local Models section, add OpenAI key field, auto-save on change, remove Save button |
| `WriteVibeApp.swift` | Modify — add launch-time `refreshOllamaModels()` task |

---

## Notes for Phase 4

Once this sprint is complete, the following are straightforward additions:

- **GPT-4o / OpenAI backend** — the OpenAI key is already in Keychain after Task 6. `OpenAIService.swift` will be nearly identical to `AnthropicService.swift` but targeting `api.openai.com/v1/chat/completions` with `Authorization: Bearer` header and standard OpenAI SSE format.
- **Mistral** — uses the same OpenAI-compatible API format. One service file can cover both.
- **Gemini** — different SSE format but straightforward once the pattern is established.
- **More curated Ollama models** — just extend the `curatedModels` array in `OllamaModelBrowserView.swift`.

---
_Last Updated: March 11, 2026_
