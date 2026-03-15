# WriteVibe: AI Writing Assistant

WriteVibe is a macOS AI writing assistant built with SwiftUI. It supports multiple AI backends — on-device Apple Intelligence, local Ollama models, and cloud providers via OpenRouter and direct Anthropic SSE — giving users a fully offline or cloud-connected writing experience.

## 🚀 Project Overview

- **Platform**: macOS 26+
- **UI Framework**: SwiftUI
- **AI Backends**: Apple Intelligence (FoundationModels), Ollama (localhost), Anthropic (direct SSE), OpenRouter gateway (14+ models including Claude, GPT-4o, Gemini, DeepSeek, Perplexity Sonar)
- **Storage**: SwiftData (Conversation, Message, Article, ArticleBlock, ArticleDraft)
- **Architecture**: Protocol-based AI abstraction (`AIStreamingProvider`) + `ServiceContainer` DI singleton
- **Core Features** (all live as of v1.3+):
  - Multi-turn streaming conversations persisted via SwiftData
  - Writing action chips: Improve, Expand, Shorten, Rephrase, Continue — injected into system prompt
  - Capability chips: Tone, Length, Format, Memory, Web Search
  - Perplexity Sonar web search context injection
  - AI-generated conversation titles via `@Generable`
  - Block-based Article editor with AI-powered diff edits (`ArticleAIService`)
  - Writing analysis panel (tone, reading level, suggestions via `AppleIntelligenceService.analyzeWriting()`)
  - AI Copilot side panel for parallel conversations
  - Keychain API key storage for all cloud providers
  - Export: clipboard + Markdown file via NSSavePanel
  - Document ingestion (.txt, .md, .rtf via NSOpenPanel; URL fetch + HTML strip)
  - Context window usage indicator with color-stage warnings

## 🛠 Tech Stack & Architecture

### State Management
- **`AppState`** (`State/AppState.swift`): Central `@Observable` controller. Manages conversation lifecycle, message appending, AI task tracking (`activeTasks: [UUID: Task<Void, Never>]`), capability chip state, search fetching flag, and writing analysis result.
- **`ServiceContainer`** (`Services/ServiceContainer.swift`): Singleton DI container. All AI providers and services are instantiated here. Route handlers call `provider(for: AIModel)` — never instantiate providers directly.

### AI Provider Protocol
All backends conform to `AIStreamingProvider`:
```swift
protocol AIStreamingProvider: Sendable {
    func stream(model: String, messages: [[String: String]], systemPrompt: String) -> AsyncThrowingStream<String, Error>
}
```

| Provider | Backend | Auth | File |
|---|---|---|---|
| `OllamaService` | localhost:11434 | None | `Services/AI/OllamaService.swift` |
| `OpenRouterService` | api.openrouter.ai | Keychain Bearer | `Services/AI/OpenRouterService.swift` |
| `AnthropicService` | api.anthropic.com | Keychain x-api-key | `Services/AI/AnthropicService.swift` |
| `AppleIntelligenceService` | FoundationModels (on-device) | None | `Services/AI/AppleIntelligenceService.swift` |

**Single-import rule**: Only `AppleIntelligenceService.swift` imports `FoundationModels`. No other file may import it.

### Data Models (`Models/`)
- `Conversation` (@Model) — title, model, modelIdentifier, createdAt, updatedAt → messages (cascade)
- `Message` (@Model) — role, content, timestamp, modelUsed, tokenCount, feedback
- `Article` (@Model) — title, subtitle, tone, targetLength, publishStatus → blocks, drafts (cascade)
- `ArticleBlock` (@Model) — position, typeTag, typeMetadata, content
- `ArticleDraft` (@Model) — title, content snapshot

### Services (`Services/`)
| File | Responsibility |
|---|---|
| `StreamingService.swift` | Orchestrates streaming: capability chip prompt augmentation, search context injection, token batching (6 tokens), SwiftData writes |
| `ConversationService.swift` | CRUD + in-memory cache for Conversation/Message; auto-triggers title generation |
| `DocumentIngestionService.swift` | NSOpenPanel (.txt/.md/.rtf) + URL fetch with HTML stripping, 8000-char truncation |
| `ExportService.swift` | Clipboard + NSSavePanel markdown export |
| `KeychainService.swift` | Generic Keychain save/load/delete (service: "com.writevibe.app") |
| `DiffEngine.swift` | Word-level LCS diff — powers block-level change tracking in Article editor |
| `MarkdownParser.swift` | Streaming-safe line-by-line markdown parser for chat message rendering |
| `ArticleAIService.swift` | JSON-structured edit proposals via OpenRouter; maps to ProposedBlockEdit operations |

### System Prompt
Defined in `Resources/SystemPrompt.swift` as `writeVibeSystemPrompt`. Injected by `StreamingService`.

### UI Components
- `ContentView.swift` — root `NavigationSplitView` (220–320pt sidebar)
- `SidebarView.swift` — time-grouped conversation list, search, collapsible Apps/Library sections
- `WelcomeView.swift` — brand header + 3-column `WritingModeCard` grid + `InputBar`
- `ChatView.swift` — message list, model picker toolbar, writing action chips, `InputBar`
- `InputBar.swift` — multi-line field, send/stop, capability chips, search spinner (`isSearchFetching`)
- `MessageBubble.swift` — markdown rendering, hover actions (copy/feedback/regenerate/analyze), `WritingAnalysisPanelView` toggle
- `CopilotPanel.swift` — parallel AI conversation panel with its own `ChatScrollContainer`
- `ArticlesDashboardView.swift` / `ArticleWorkspaceView.swift` / `ArticleEditorView.swift` — full article pipeline
- `ModelPickerView.swift` — two-pane provider/model picker (640×380 popover)
- `OllamaModelBrowserView.swift` — live Ollama connection status, install/delete/download-with-progress

## 🏗 Building and Running

### Prerequisites
- Xcode on macOS 26+ (FoundationModels requires macOS 26)
- Ollama installed locally for local model features (optional)
- OpenRouter API key for cloud models (optional; enter in Settings)
- Anthropic API key for direct Claude SSE (optional; enter in Settings)

### Build Commands
```bash
# Open in Xcode
open WriteVibe.xcodeproj

# CLI build
xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -configuration Debug

# CLI tests
xcodebuild test -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS'
```

## 📝 Development Conventions

- **State access**: `@Environment(AppState.self)` from any view. Never pass `AppState` as a plain init argument.
- **AI providers**: All calls go through `ServiceContainer`. Never instantiate `OllamaService`, `OpenRouterService`, etc. directly outside the container.
- **FoundationModels**: Only `AppleIntelligenceService` may import it.
- **Concurrency**: All UI mutations on `@MainActor`. Streaming uses `Task` + `AsyncThrowingStream`. In-flight tasks tracked in `AppState.activeTasks`, cancelled on stop/delete.
- **Keychain**: API keys are always stored via `KeychainService`. Never use `UserDefaults` or hardcoded strings for secrets.
- **Styling**: SwiftUI semantic colours only (`.primary`, `.secondary`, `.tint`). `glassEffect(in:)` for interactive surfaces. No hardcoded hex.
- **File size**: Target ≤ 250 lines per file. Split if growing past that.
- **No barrel files, no summary markdown** unless explicitly requested.

## 🗺 Roadmap

See `docs/dev-maps/dev-map-003.md` for the current sprint plan and full prioritised backlog.

**Current version: v1.3+ (March 2026)**

**What's live:**
- ✅ All 4 AI backends (Apple Intelligence, Ollama, Anthropic, OpenRouter w/ 14+ models)
- ✅ Perplexity Sonar web search context injection
- ✅ Block-based Article editor with AI diff edits
- ✅ Writing analysis panel
- ✅ Capability chips (tone, length, format, memory, search)
- ✅ AI Copilot panel
- ✅ SwiftData persistence, Keychain key storage, export, document ingestion

**Known bugs (fix before new features):**
- ⚠️ Ollama download cancellation clears UI only — network task keeps running
- ⚠️ Search layer silently fails in Ollama-only mode (missing OpenRouter key guard)
- ⚠️ Duplicate input bar files (`ChatInputBar.swift` ≈ `InputBar.swift`) — delete the stale copy
- ⚠️ Anthropic API version header `"2023-06-01"` is stale — update in `AppConstants`

**Next priorities (in sprint order):**
1. Bug fixes above
2. Search grounding improvement (structured `[SearchResult]` injection, local model grounding prompt)
3. Diff view in chat `MessageBubble` (DiffEngine already exists — wire it)
4. Drag-and-drop file import
5. `DateTimeTool` + `ClipboardTool` for Apple Intelligence
6. App Intents + Spotlight indexing
7. Draft variants + writing analysis chip
8. Voice input + Writing Tools system extension

---
*Last Updated: March 15, 2026*
