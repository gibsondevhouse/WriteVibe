# Release Notes

---

## v1.3 — Ollama Local Models (March 11, 2026)

Full integration of Ollama as a free, on-device model backend. No cloud required beyond initial model downloads.

### Ollama Backend
- **`OllamaService.swift`** — new service covering all Ollama API interactions: connection check (`/api/version`), installed model listing (`/api/tags`), NDJSON streaming progress pull (`/api/pull`), model deletion (`/api/delete`), and OpenAI-compatible SSE streaming chat (`/v1/chat/completions`).
- **`streamOllamaReply`** in `AppState` — builds the message history, appends a placeholder, and streams tokens into it exactly as the Anthropic path does.
- **Error routing** — `OllamaError.notRunning` and `OllamaError.httpError` are caught in `generateReply` and surface a human-readable assistant message with a download link.

### Local Model Manager
- **`OllamaModelBrowserView`** — in-app sheet for managing local models: live connection status banner, installed models list with delete (🗑), and a curated library of six recommended models (Llama 3.2 3B/8B, Mistral 7B, Gemma 3 4B, Phi-4 14B, Qwen 2.5 7B) each with tags, size estimate, and a real-time download progress bar.
- Download cancel clears UI state only — the underlying network task runs to completion (noted in code).

### Dynamic Model Picker
- Replaced the static `Picker` in `ChatView` toolbar with a custom `Menu` divided into three sections: **On-Device** (Apple Intelligence), **Local (Ollama)** — populated live from `AppState.availableOllamaModels` — and **Cloud** (Anthropic + future providers).
- `AppState.refreshOllamaModels()` is called on app launch (via `ContentView`) and on `ChatView` appear, so the picker is always current.
- Selecting an Ollama model sets `conv.model = .ollama` and records the specific model name in `conv.ollamaModelName` (persisted via SwiftData).

### Data Model
- `AIModel.ollama` case added with `"Local · Private · Free"` subtitle and `desktopcomputer` SF Symbol.
- `Conversation.ollamaModelName: String?` field added — lightweight SwiftData migration, no `VersionedSchema` required.
- `AIModel.isLocal` and `AIModel.requiresAPIKey` computed properties added for use in future UI gating.

### Settings
- **Local Models section** added at the top of `SettingsView` with a live Ollama status indicator and a "Manage Models…" button presenting `OllamaModelBrowserView`.
- **OpenAI API Key** field added to the Cloud API Keys section (Keychain key `"openai_api_key"`), priming the architecture for GPT-4o integration in Phase 4.
- Section renamed from "API Keys" to "Cloud API Keys". Keys auto-save on change; the separate Save button is removed.

### Known Stubs in This Release
- **Download cancellation** — Cancel button in `OllamaModelBrowserView` clears UI state (`downloadProgress`/`downloadStatus`) but does not cancel the underlying `URLSession` task.
- **Apple Intelligence icon** — uses `"cpu"` placeholder; TODO to swap to `"apple.logo"` after SF Symbol availability on macOS 26 is confirmed.

---

## v1.2 — Cloud Backend & Core Utilities (March 11, 2026)

### Export
- **Copy last reply to clipboard** — the Export button in the sidebar footer now copies the last assistant message to `NSPasteboard`. An animated toast confirms success.
- **Save as Markdown file** — a second export option in `ChatView`'s toolbar menu presents `NSSavePanel` and writes the full conversation as formatted Markdown. Each turn is labelled `**You:**` / `**WriteVibe:**` with `---` separators.

### Context Window Usage Indicator
- A 3pt progress bar appears above the input field when the conversation exceeds ~50 % of the estimated 4 096-token limit (heuristic: `totalChars / 4`).
- Color stages: accent (< 80 %), orange (80–95 %), red (≥ 95 %).
- A caption warns "Context nearly full — start a new chat" at 95 % and disables the Send button at 98 %.

### Anthropic Backend (Claude 3.5 Sonnet & Claude 3 Opus)
- **`AnthropicService.swift`** — SSE streaming to `https://api.anthropic.com/v1/messages` with `x-api-key` / `anthropic-version` headers and `content_block_delta` event parsing.
- **`KeychainService.swift`** — generic Keychain helper (`kSecClassGenericPassword`, service `"com.writevibe.app"`) used by all API key storage. Keys are never written to `UserDefaults` or plist.
- API key loaded from Keychain at call time. `AnthropicError.missingAPIKey` surfaces an actionable assistant message directing the user to Settings.

### Document Ingestion
- **`DocumentIngestionService.swift`** — `NSOpenPanel` picker for `.txt`, `.md`, `.rtf`. RTF decoded via `NSAttributedString`. Output truncated to 8 000 characters with a visible notice to fit context.
- Wired to the "Upload Document" option in `AttachMenu`; extracted text is pre-filled into the input bar with a "Please read the following document and help me improve it:" prefix.

### Settings Screen
- **`SettingsView.swift`** created and wired to the sidebar footer Settings button.
- `SecureField` for Anthropic API key auto-saves to Keychain `onChange`. No separate Save button.

---

## v1.1 — UI Design Polish (March 11, 2026)

This release replaces the generic AI-app scaffolding with an opinionated, product-specific visual system.

### Welcome / Home Screen
- **New `WritingModeCard` component** — replaces the old 2-column `SuggestionCard` grid. Cards are taller, icon-anchored at top, with a short descriptor line below the label (e.g., "Essay / Argued & structured").
- **3-column grid layout** — six writing formats: Essay, Story, Article, Email, Edit, Outline. More specific to WriteVibe's identity than the previous "Write a blog post / Draft an email" generics.
- **Brand wordmark header** — replaces the `sparkles` icon-in-circle. A tracked small-caps `WRITEVIBE` eyebrow, a large semibold heading, and a one-line descriptor. No decorative icon.
- **Input area tightened** — input bar and disclaimer are flush to the bottom with consistent horizontal padding.

### Chat Empty State
- Now uses the same `WritingModeCard` grid as the home screen, with inline prompt injection (tapping a card pre-fills the text field rather than immediately starting a chat).

### Sidebar
- **`ConversationRow` redesigned** — two-line layout: title + relative timestamp (right-aligned, `caption2`) on the first line; last message preview truncated with `.tail` on the second line. `.padding(.vertical, 4)` adds breathing room between rows.
- **Footer upgraded** — `Divider` separator above the icon row; background uses `.bar` material instead of `.thinMaterial` for correct macOS toolbar feel.
- **Column width constrained** — `NavigationSplitView` sidebar column width set to `min: 220, ideal: 260, max: 320` pt.

### Removed
- `SuggestionCard` struct — fully removed, replaced by `WritingModeCard`.
- `GlassEffectContainer` wrapping the suggestion grid — cards now use direct `.glassEffect` per item.
- `sparkles` icon-in-circle from both home and chat empty states.

---

## v1.0 — Production Candidate

## Key Features

### 💾 Persistent Storage (SwiftData)
- **Architecture**: Migrated from in-memory arrays to **SwiftData** for robust, offline-capable persistence.
- **Benefits**: Conversations and messages are now saved automatically and persist across app restarts.
- **Schema**: `Conversation` and `Message` are now `@Model` classes with cascade deletion.

### ✍️ AI Auto-Titling
- **Feature**: Automatically generates a concise, relevant title for new conversations based on the first user message.
- **Tech**: Utilizes on-device structured generation (`Generable`) via Apple Intelligence to produce high-quality titles without cloud calls.
- **Fallback**: Gracefully falls back to text truncation if AI generation fails.

### 🏷 Conversation Renaming
- **Feature**: Users can now rename conversations from the sidebar.
- **UI**: Added a "Rename Conversation" option to the context menu, triggering a native macOS alert dialog for input.

### 🛡 UI & Stability Improvements
- **Clean UI**: Hidden non-functional "Attach" and "Web Search" buttons to ensure a polished user experience.
- **Empty States**: Validated the "Welcome" screen flow with persistent conversation creation.
- **Error Handling**: Improved optional unwrapping for conversation IDs to prevent crashes.

## Technical Details
- **Frameworks**: SwiftUI, SwiftData, FoundationModels (Apple Intelligence).
- **Concurrency**: Full `@MainActor` compliance for UI updates; strict `Task` usage for async AI operations.
- **Codebase**: Refactored `AppState` to act as a logic controller over the SwiftData context, while views use `@Query` for reactive updates.

## Known Issues / Future Work
- **Cloud Models**: Stubbed implementation for non-Apple models (Tier 4).
- **Attachments**: UI support exists but backend logic is pending (Tier 1.2).
- **Web Search**: UI support exists but logic is pending.
