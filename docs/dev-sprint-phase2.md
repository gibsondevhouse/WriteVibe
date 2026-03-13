# WriteVibe — Phase 2 Development Sprint
_Coding agent prompt. Execute all tasks in order. Do not skip sections._

---

## Context & Architecture Rules

Before writing any code, internalize these constraints:

- **`FoundationModels` is only imported in `AppleIntelligenceService.swift`**. No other file may import it.
- **All UI mutations must be on `@MainActor`**. Async work uses `Task` + `await`.
- **Cloud API keys are stored in Keychain**, never in `UserDefaults`, plist, or hardcoded strings.
- **`AppState` is the single logic controller**. Views call into `AppState` and use `@Query` for reactive data. Views do not own business logic.
- **Do not break existing Apple Intelligence streaming**. The `AppleIntelligenceService.generate()` path is production-working — treat it as read-only unless a task explicitly requires modifying it.
- All new Swift files go in the `WriteVibe/` source directory unless noted otherwise.
- After each task, the app must build cleanly with no warnings promoted to errors.

---

## Task 1 — Export: Markdown to Clipboard & File

### What exists
The Export button in the sidebar footer is a UI stub that does nothing (`// TODO`).

### What to build

#### 1a. Export last assistant message to clipboard
In `SidebarView.swift`, wire the Export footer button to call a new `AppState` method:

```swift
func exportLastAssistantMessage(from conversationId: UUID) -> String?
```

This method fetches the conversation, finds the last `Message` where `role == .assistant`, and returns its `content` string. If no assistant message exists, return `nil`.

In the view, on button tap:
- Call the method
- If a string is returned, write it to `NSPasteboard.general` using `.setString(_:forType: .string)`
- Show a brief success confirmation — a `.overlay` toast or a `.sheet` is acceptable; a simple `NSAlert` is not (too disruptive)
- If `nil`, show a disabled state or a "Nothing to export yet" message

#### 1b. Export full conversation as markdown file
Add a second export option: "Save as Markdown File". When tapped:
- Build a markdown string from the full conversation: iterate `conv.messages` in order, formatting each as:
  ```
  **You:** {content}

  ---

  **WriteVibe:** {content}

  ---
  ```
- Present `NSSavePanel` with `allowedContentTypes: [.plainText]`, default filename `"{conv.title}.md"`
- Write the string to the selected URL using `String.write(to:atomically:encoding:)`

#### 1c. AppState method signature (add to `Item.swift` AppState extension or directly in AppState)
```swift
func buildMarkdownExport(for conversationId: UUID) -> String
```
Returns the formatted markdown string described in 1b.

---

## Task 2 — Context Window Usage Indicator

### What exists
`ChatInputBar` in `InputBar.swift` has no token awareness. The error only surfaces after generation fails.

### What to build

The on-device model has an approximate 4096-token context limit. Tokens ≈ characters / 4 (rough but acceptable heuristic for a UI indicator).

#### 2a. Token budget calculation in AppState
Add a computed property to `AppState`:

```swift
func estimatedTokenUsage(for conversationId: UUID) -> Double
```

- Fetch the conversation
- Sum `message.content.count` for all messages
- Divide by 4 to get estimated tokens
- Return as a `Double` (for use as a progress value 0.0–1.0 against a 4096 limit)
- Return `0.0` if conversation not found

#### 2b. Pass token usage into ChatInputBar
`ChatInputBar` currently takes: `text`, `isThinking`, `focused`, `onSend`, `onStop`.

Add a new parameter: `tokenUsage: Double` (0.0 to 1.0).

In the call site (`ChatView.swift`), compute and pass:
```swift
appState.estimatedTokenUsage(for: conversationId) / 4096.0
```
Clamp to `0.0...1.0`.

#### 2c. Visual indicator in ChatInputBar
Inside `ChatInputBar.body`, above the `HStack` that holds the text field, add a thin progress bar:

- Only visible when `tokenUsage > 0.5`
- Use a `GeometryReader` or fixed-width `Rectangle` fill proportional to `tokenUsage`
- Color logic:
  - `tokenUsage < 0.8` → `Color.accentColor.opacity(0.5)`
  - `0.8..<0.95` → `Color.orange`
  - `>= 0.95` → `Color.red`
- At `>= 0.95`, also show a small caption label below the progress bar: `"Context nearly full — start a new chat to continue"`
- At `>= 0.98`, disable the send button and replace the caption with: `"Context full — please start a new chat"`

The bar should be subtle — max height 3pt, full width, `cornerRadius(1.5)`, with a light gray background track.

---

## Task 3 — Claude API Backend (Anthropic)

### What exists
In `Item.swift`, `AIModel` has `.claude35Sonnet` and `.claude3Opus` cases. In `AppState.generateReply()`, the `else` branch for non-Apple-Intelligence models returns a hardcoded stub string.

### What to build

#### 3a. Settings screen for API key entry
Create `SettingsView.swift`:

```swift
struct SettingsView: View { ... }
```

- A `Form` with a `Section("API Keys")`
- A `SecureField("Anthropic API Key", text: $anthropicKey)` bound to a `@State` that reads/writes from Keychain on appear/change
- A save confirmation (inline checkmark or toast — no `NSAlert`)
- Wire the Settings footer button in `SidebarView` to present this view as a `.sheet`

**Keychain helper** — create `KeychainService.swift`:

```swift
enum KeychainService {
    static func save(key: String, value: String)
    static func load(key: String) -> String?
    static func delete(key: String)
}
```

Use `kSecClassGenericPassword` with `kSecAttrService = "com.writevibe.app"` and `kSecAttrAccount = key`. Standard `SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete` implementation.

Key name constant: `"anthropic_api_key"`.

#### 3b. AnthropicService.swift
Create `AnthropicService.swift`. This file handles all Anthropic API calls. **Do not import FoundationModels here.**

```swift
@MainActor
enum AnthropicService {
    static let apiBase = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Streams a response from the Anthropic Messages API using SSE.
    /// - Parameters:
    ///   - messages: Array of prior conversation turns as `[["role": String, "content": String]]`
    ///   - model: The Anthropic model string, e.g. "claude-sonnet-4-6" or "claude-opus-4-6"
    ///   - systemPrompt: Injected as the `system` field
    ///   - onToken: Called on @MainActor with each streamed text delta
    static func stream(
        messages: [[String: String]],
        model: String,
        systemPrompt: String,
        onToken: @MainActor @escaping (String) -> Void
    ) async throws
}
```

**Implementation details:**

- Retrieve the API key from `KeychainService.load(key: "anthropic_api_key")`. If nil, throw a `AnthropicError.missingAPIKey` error.
- Build a `URLRequest` to `apiBase`:
  - Method: `POST`
  - Headers: `"x-api-key": apiKey`, `"anthropic-version": "2023-06-01"`, `"Content-Type": "application/json"`
  - Body:
    ```json
    {
      "model": "<model>",
      "max_tokens": 2048,
      "stream": true,
      "system": "<systemPrompt>",
      "messages": <messages array>
    }
    ```
- Use `URLSession.shared.bytes(for:)` to stream the response
- Parse Server-Sent Events line by line:
  - Lines beginning with `data: ` — strip prefix, parse JSON
  - Event type `content_block_delta` with `delta.type == "text_delta"` — call `onToken(delta.text)`
  - Event type `message_stop` — break the loop
  - Lines `data: [DONE]` — break
- Define `AnthropicError: Error` with cases: `missingAPIKey`, `httpError(Int)`, `decodingFailed`

#### 3c. Wire Claude models into AppState
In `AppState.generateReply()`, replace the cloud stub block:

```swift
} else {
    // Cloud stub — replace this entire block
}
```

With:

```swift
} else if model == .claude35Sonnet || model == .claude3Opus {
    try await self.streamAnthropicReply(for: conversationId)
} else {
    // Other cloud models not yet implemented
    self.appendMessage(
        Message(role: .assistant, content: "This model is not yet configured. Add your API key in Settings."),
        to: conversationId
    )
}
```

Add the private method to `AppState`:

```swift
private func streamAnthropicReply(for conversationId: UUID) async throws {
    guard let conv = fetchConversation(conversationId) else { return }

    // Map AIModel enum to Anthropic model string
    let modelString: String
    switch conv.model {
    case .claude35Sonnet: modelString = "claude-sonnet-4-6"
    case .claude3Opus:    modelString = "claude-opus-4-6"
    default: return
    }

    // Build message history in Anthropic format
    let messages = conv.messages
        .filter { !$0.content.isEmpty }
        .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

    let placeholder = Message(role: .assistant, content: "")
    appendMessage(placeholder, to: conversationId)
    let placeholderId = placeholder.id

    try await AnthropicService.stream(
        messages: messages,
        model: modelString,
        systemPrompt: writeVibeSystemPrompt, // expose this constant or pass it
        onToken: { [weak self] delta in
            guard let self,
                  let conv = self.fetchConversation(conversationId),
                  let msg = conv.messages.first(where: { $0.id == placeholderId })
            else { return }
            msg.content += delta
            conv.updatedAt = Date()
        }
    )
}
```

Note: `writeVibeSystemPrompt` is currently `private` in `Item.swift`. Change it to `internal` (remove the `private` modifier) so `AppState` can reference it.

#### 3d. Error handling for Claude
In `AppState.generateReply()`'s catch chain, add:

```swift
} catch AnthropicError.missingAPIKey {
    self.appendMessage(
        Message(role: .assistant, content: "No Anthropic API key found. Add your key in Settings → API Keys."),
        to: conversationId
    )
} catch AnthropicError.httpError(let code) {
    self.appendMessage(
        Message(role: .assistant, content: "Anthropic API error (HTTP \(code)). Check your API key and try again."),
        to: conversationId
    )
}
```

---

## Task 4 — Document Ingestion (Text & Markdown Files)

### What exists
The "Upload Document" option in `AttachMenu` in `InputBar.swift` is a UI stub — the button's action closure is empty.

### What to build

#### 4a. DocumentIngestionService.swift
Create `DocumentIngestionService.swift`:

```swift
enum DocumentIngestionService {
    /// Presents NSOpenPanel and returns the extracted plain-text content of the selected file.
    /// Supported types: .txt, .md, .rtf
    /// Returns nil if the user cancels or the file cannot be read.
    @MainActor
    static func pickAndExtract() async -> String?
}
```

Implementation:
- Present `NSOpenPanel` with:
  - `allowsMultipleSelection = false`
  - `canChooseDirectories = false`
  - `allowedContentTypes: [.plainText, .rtf]`
  - Also allow `.md` by adding `UTType(filenameExtension: "md") ?? .plainText`
- On `.OK` response, read the selected URL:
  - `.txt` / `.md`: `String(contentsOf: url, encoding: .utf8)`
  - `.rtf`: `NSAttributedString(url:options:documentAttributes:)` then `.string`
- Return the extracted string, trimmed of leading/trailing whitespace
- If the string exceeds 8000 characters, truncate to 8000 and append `"\n\n[Document truncated to fit context window]"`

#### 4b. Wire into InputBar and AppState
`InputBar` needs to trigger ingestion and inject the result into the text field or send it as a prefilled message. Because `InputBar` should not own business logic, add a callback:

```swift
// In ChatInputBar:
var onDocumentAttached: ((String) -> Void)? = nil
```

In `AttachMenu`, pass the callback down and wire the "Upload Document" button:

```swift
Button {
    Task { @MainActor in
        if let text = await DocumentIngestionService.pickAndExtract() {
            onDocumentAttached?(text)
        }
    }
} label: { ... }
```

In the call site (`ChatView.swift`), implement `onDocumentAttached`:

```swift
onDocumentAttached: { extractedText in
    // Prepend a clear instruction so the model knows what to do
    appState.inputText = "Please read the following document and help me improve it:\n\n\(extractedText)"
}
```

Note: This assumes `ChatView` owns an `@State var inputText` that is bound to `ChatInputBar`. If the text binding is structured differently in the current `ChatView.swift`, adapt accordingly — the principle is to pre-fill the text field with the extracted content so the user can review it before sending.

#### 4c. AttachMenu needs the callback threaded through
`AttachMenu` is currently a standalone `View` with no external callbacks. Refactor it to accept:

```swift
struct AttachMenu: View {
    var onDocumentAttached: ((String) -> Void)? = nil
    // future: var onImageAttached: ...
    // future: var onURLAttached: ...
}
```

And update `ChatInputBar` to pass `onDocumentAttached` through to `AttachMenu` in the `.popover`.

---

## Task 5 — Prewarm Improvement (Low effort, high impact)

### What exists
In `AppState.newConversation()`:
```swift
AppleIntelligenceService.prewarm(conversationId: conv.id, systemPrompt: writeVibeSystemPrompt)
```
This prewarming passes no prefix — the cache is seeded with just the system prompt.

### What to build
In `WelcomeView.swift` and the chat empty state in `ChatView.swift`, when the user taps a `WritingModeCard`, call a new method before sending:

```swift
// In AppleIntelligenceService:
static func prewarmWithPrefix(conversationId: UUID, systemPrompt: String, prefix: String) {
    guard sessions[conversationId] == nil else { return }
    let session = LanguageModelSession(instructions: systemPrompt)
    sessions[conversationId] = session
    session.prewarm(promptPrefix: prefix)
}
```

Map each `WritingModeCard` to an appropriate prefix string:
- Essay → `"Write a well-structured essay about "`
- Story → `"Write a compelling short story about "`
- Article → `"Write an engaging article about "`
- Email → `"Write a professional email that "`
- Edit → `"Please review and improve the following text: "`
- Outline → `"Create a detailed outline for "`

When a card is tapped, call `appState.prewarmWithPrefix(...)` with the matching prefix, then inject the prefix into the text field as a starting prompt hint.

---

## Acceptance Criteria

Before considering this sprint complete, verify:

- [x] Tapping Export copies the last assistant message to clipboard with a visible toast confirmation
- [x] "Save as Markdown" presents `NSSavePanel` and writes a correctly formatted `.md` file
- [x] Context bar appears at 50%+ usage, turns orange at 80%, red at 95%, and blocks send at 98%
- [x] Selecting Claude 3.5 Sonnet or Claude Opus and sending a message calls the Anthropic API (not the stub)
- [x] Without an API key set, the assistant returns a helpful "Add your key in Settings" message
- [x] Settings sheet opens, accepts a key, saves to Keychain, and the key persists across app restarts
- [x] "Upload Document" opens a file picker, reads `.txt`, `.md`, and `.rtf` files, and pre-fills the input bar
- [x] Documents over 8000 characters are truncated with a visible note
- [x] Apple Intelligence path is completely unaffected by all of the above changes
- [x] App builds cleanly on macOS 26+ with no new warnings

---

## File Change Summary

| File | Action |
|---|---|
| `AnthropicService.swift` | **Create** |
| `KeychainService.swift` | **Create** |
| `DocumentIngestionService.swift` | **Create** |
| `SettingsView.swift` | **Create** |
| `Item.swift` | Modify — change `writeVibeSystemPrompt` to `internal`, add `streamAnthropicReply`, extend error handling, add export/token methods to AppState |
| `InputBar.swift` | Modify — wire document attach callback, re-enable attach button |
| `AppleIntelligenceService.swift` | Modify — add `prewarmWithPrefix` method |
| `SidebarView.swift` | Modify — wire Export button, wire Settings button |
| `ChatView.swift` | Modify — pass token usage to InputBar, handle document attach callback |

---
_Last updated: March 11, 2026_
