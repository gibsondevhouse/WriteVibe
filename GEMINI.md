# WriteVibe: AI Writing Assistant

WriteVibe is a modern, privacy-focused macOS AI writing assistant built with SwiftUI. It leverages on-device **Apple Intelligence** (via the `FoundationModels` framework) to provide fast, private, and offline-capable text generation and editing. The application helps users draft, improve, and refine writing across formats — essays, stories, articles, emails, outlines, and more.

## 🚀 Project Overview

- **Platform**: macOS (Targeting macOS 26+)
- **UI Framework**: SwiftUI
- **AI Engine**: Apple Intelligence (`FoundationModels`) with extensibility for cloud models (Claude, GPT-4o, Gemini)
- **Storage**: SwiftData (`better-sqlite3` swap not applicable — this is native macOS)
- **Core Features**:
  - Multi-turn on-device AI conversations, persisted across restarts via SwiftData
  - Writing action chips: Improve, Expand, Shorten, Rephrase, Continue
  - Streaming responses with real-time UI updates
  - AI-generated conversation titles via structured `@Generable` output
  - Sidebar with time-grouped conversation history, search, and inline renaming
  - 3-column writing mode grid (Essay, Story, Article, Email, Edit, Outline) on home and chat empty states

## 🛠 Tech Stack & Architecture

### Data Model & State Management
- **`AppState`** (`Item.swift`): Central `@Observable` controller. Manages conversation lifecycle, message appending, AI task tracking (`activeTasks`), and coordination of streaming generation.
- **`Conversation` & `Message`**: `@Model` SwiftData classes with cascade deletion. `Conversation` stores title, selected AI model, timestamps, and a message relationship.
- **`AIModel`**: Enum representing supported models. Non-Apple-Intelligence models are currently stubbed.

### AI Services
- **`AppleIntelligenceService.swift`**: Sole importer of `FoundationModels`. Manages `LanguageModelSession` instances per conversation ID (multi-turn history), handles prewarming, token streaming, and structured title generation via `@Generable`.
- **Writing Agent System Prompt**: Defined in `Item.swift`, injected into every `LanguageModelSession`.

### UI Components
- **`ContentView.swift`**: Root `NavigationSplitView` layout. Sidebar column width constrained to 220–320 pt (ideal 260 pt).
- **`SidebarView.swift`**: Time-grouped conversation list with search. `ConversationRow` shows title, relative timestamp, and message preview in a two-line typographic layout.
- **`WelcomeView.swift`**: Home screen shown when no conversation is selected. Features a brand wordmark header and a 3-column `WritingModeCard` grid (6 writing formats), followed by the full `ChatInputBar`.
- **`ChatView.swift`**: Active conversation view — message list, model picker toolbar, writing action chips, and floating `ChatInputBar`. Empty state mirrors the home screen mode grid.
- **`InputBar.swift`**: `ChatInputBar` — multi-line text field, send/stop button, accent-border focus ring. Attach and web search buttons are present but gated as `// TODO` stubs.
- **`MessageBubble.swift`**: User bubbles (accent gradient, right-aligned) and assistant turns (markdown rendered via `MarkdownMessageText`, left-aligned). Hover reveals copy/thumbs/regenerate actions. `ThinkingIndicator` uses animated dots.

## 🏗 Building and Running

### Prerequisites
- **Xcode**: Standard macOS development environment.
- **macOS Version**: macOS 26 or later required for `FoundationModels` / Apple Intelligence support.

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

- **State access**: Use `@Environment(AppState.self)` to reach shared state from any view. Never pass `AppState` as a plain init argument.
- **AI integration**: All `FoundationModels` calls are routed through `AppleIntelligenceService`. Views and `AppState` must not import `FoundationModels` directly.
- **Concurrency**: All UI mutations on `@MainActor`. Streaming uses `Task` + `AsyncSequence`. Cancellable tasks are stored in `AppState.activeTasks` and cancelled on stop or delete.
- **Styling**: Tailwind-style utility layout in SwiftUI. `glassEffect(in:)` for interactive surfaces. No hardcoded colour hex values — use semantic colours (`.primary`, `.secondary`, `.tint`, `.accentColor`) and system materials.
- **No barrel files, no summary markdown** unless explicitly requested.

## 🗺 Roadmap (high-level)

See `docs/writevibe-roadmap.md` for the full backlog.

**Completed:**
- ✅ SwiftData persistence
- ✅ AI auto-titling (`@Generable`)
- ✅ Conversation rename (context menu + alert)
- ✅ UI polish pass: surface hierarchy, sidebar row design, WritingModeCard grid, unified header system

**Next priorities:**
- Cloud model API connectors (Claude, GPT-4o, Gemini)
- Diff view for Improve / Rephrase actions
- Context window usage indicator
- Attachment + file import pipeline
- Export (markdown to clipboard / NSSavePanel)

---
*Last Updated: March 11, 2026*
