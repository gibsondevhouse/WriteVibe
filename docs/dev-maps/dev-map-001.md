# Dev Map 001 — Post-Refactor Next Steps

> Generated: 2026-03-14
> Baseline: After architectural refactoring (Phases 1–6)

---

## Priority Matrix

| Priority | Category | Items | Effort |
|----------|----------|-------|--------|
| **P0 — Critical** | Stability | KeychainService error handling, DocumentIngestionService error reporting | Small |
| **P1 — High** | Architecture | ChatView/CopilotPanel deduplication, SwiftUI environment DI wiring, AppState init relocation | Medium |
| **P2 — Medium** | Data Model | `ollamaModelName` → `modelIdentifier` rename, BlockType storage optimization | Medium |
| **P3 — Low** | Testing | Unit tests for services/ViewModels, integration tests for SwiftData migration | Large |
| **P3 — Low** | Polish | Stub implementations (feedback, regenerate, capability chips, Apps section) | Large |

---

## Checklist

### Status Update (2026-03-14)

- Completed: P0 (2/2), P1 (3/3), P2 (2/3), P3 polish stubs (2/4)
- Remaining focus: AppleIntelligenceService expansion, capability chips, Apps section, and test coverage

### P0 — Critical (do first)

- [x] **KeychainService: add error handling to `save()`**
  - `SecItemAdd` / `SecItemDelete` return `OSStatus` — currently ignored
  - At minimum, log failures; ideally throw so callers can surface "API key save failed"
  - File: `WriteVibe/Services/KeychainService.swift`

- [x] **DocumentIngestionService: replace silent `try?` with proper error propagation**
  - Currently returns `nil` on all failures — user gets no feedback
  - Return `Result<String, WriteVibeError>` or throw `WriteVibeError.decodingFailed`
  - File: `WriteVibe/Services/DocumentIngestionService.swift`

### P1 — High (core architecture gaps)

- [x] **Extract shared chat scroll/message logic from ChatView + CopilotPanel**
  - Both contain near-identical: message sorting, `ScrollViewReader` + auto-scroll polling (`.milliseconds(150)`), `ChatInputBar` wiring, `onAppear` context binding
  - Extract into a reusable `ChatScrollContainer` or shared `ChatViewModel`
  - Files: `WriteVibe/Features/Chat/ChatView.swift`, `WriteVibe/Features/Chat/CopilotPanel.swift`, `WriteVibe/Features/Chat/ChatScrollContainer.swift`

- [x] **Wire ServiceContainer into SwiftUI environment**
  - Currently `ServiceContainer` is instantiated inline in `AppState` as `let services = ServiceContainer()`
  - Should be injected via `.environment()` from `WriteVibeApp.swift` for testability
  - Files: `WriteVibe/Services/ServiceContainer.swift`, `WriteVibe/App/WriteVibeApp.swift`

- [x] **Move AppState initialization to WriteVibeApp**
  - Currently created in `ContentView.swift` as `@State` — should live in `WriteVibeApp.swift` alongside `modelContainer` setup
  - Files: `WriteVibe/App/ContentView.swift`, `WriteVibe/App/WriteVibeApp.swift`

### P2 — Medium (data model improvements, deferred from Phase 4)

- [x] **Rename `ollamaModelName` → `modelIdentifier` on Conversation**
  - Generic field that stores the specific model string regardless of provider
  - Requires `@Attribute(originalName: "ollamaModelName")` for SwiftData migration
  - ⚠️ Risk: schema migration — test with real data before shipping
  - File: `WriteVibe/Models/Conversation.swift`

- [x] **Optimize BlockType storage**
  - Replace JSON-encoded `typeRaw: Data` with `typeTag: String` + `typeMetadata: String?`
  - Eliminates JSON encode/decode on every property access
  - Implemented with migration fallback from legacy `typeRaw` via `@Attribute(originalName: "typeRaw")`
  - ⚠️ Risk: schema migration — test with existing articles
  - File: `WriteVibe/Models/ArticleBlock.swift`

- [x] **Expand AppleIntelligenceService beyond title generation**
  - Expanded to include: `summarize()`, `suggestImprovements()`, `analyzeWriting()` (returns `WritingAnalysis`), and `AppleIntelligenceStreamingProvider` conformance for full chat streaming
  - `@Generable` used for structured `WritingAnalysis { tone, readingLevel, wordCount, suggestions }` output
  - `WritingAnalysisPanelView` surfaces results inline in `MessageBubble` via "Analyze" button
  - File: `WriteVibe/Services/AI/AppleIntelligenceService.swift`

### P3 — Low (testing & polish)

- [x] **Unit tests: services**
  - `StreamingServiceTests` — mock `AIStreamingProvider`, token batching + capability chip prompt augmentation verified (3 passing tests)
  - `ConversationServiceTests` — in-memory SwiftData context, full CRUD + `appendMessage` + cache round-trip verified (8 passing tests)
  - `ServiceContainerTests` — Claude/GPT-4o routing to OpenRouterService + Apple Intelligence routing verified (3 passing tests)
  - **Remaining gaps**: `DocumentIngestionServiceTests` stubs exist but are unimplemented; `WriteVibeTests.swift` and `WriteVibeUITests.swift` are empty placeholders
  - `MarkdownParserTests` — all block types, edge cases (nested lists, code fences, streaming partial lines)
  - `DiffEngineTests` — property-based tests for article diff engine
  - `WritingModeTests` — icon inference for known title patterns

- [ ] **Unit tests: ViewModels**
  - `ArticleEditorViewModelTests` — mock `ArticleAIService`, verify accept/reject/baseline snapshot logic

- [ ] **Integration tests**
  - `SwiftDataMigrationTests` — verify `§AUDIENCE§` sentinel migration, model field migration
  - `OllamaIntegrationTests` — requires running Ollama, mark as skippable

- [x] **Implement stub: message feedback (thumbs up/down)**
  - Implemented: persisted feedback field on `Message`, toggle actions in `MessageBubble`, AppState handler
  - Remaining: optional analytics/reporting pipeline

- [x] **Implement stub: regenerate response**
  - Implemented: delete last assistant message, then re-trigger generation via AppState

- [ ] **Implement stub: capability chips (Search, Tone, Length, Format, Memory)**
  - Currently non-interactive in `ChatInputBar.swift`
  - Each chip is a feature-sized effort

- [ ] **Implement stub: Apps section (Images, Canvas, Templates, Mood Board)**
  - Currently bare `Label` views in `SidebarView.swift`
  - Each is a major feature

---

## Architecture Snapshot (post-refactor)

### Layer Diagram

```
WriteVibeApp
  ├─ @State ServiceContainer
  └─ @State AppState (injected into environment)
       └─ ContentView (@Environment AppState)
       ├─ SidebarView
       ├─ ChatView / CopilotPanel
       ├─ ArticlesDashboardView
       │    ├─ ArticleWorkspaceView
       │    └─ ArticleEditorView → ArticleEditorViewModel
       └─ SettingsView / OllamaModelBrowserView

AppState (coordinator, 295 lines)
  └─ ServiceContainer
       ├─ ConversationService (CRUD, cache, migration)
       ├─ StreamingService (unified AI streaming, token batching)
       ├─ OllamaService: AIStreamingProvider
       ├─ AnthropicService: AIStreamingProvider
       └─ OpenRouterService: AIStreamingProvider

Standalone services (static/enum):
  ├─ ExportService (clipboard, markdown save)
  ├─ ArticleAIService (structured article edits)
  ├─ AppleIntelligenceService (title generation, macOS 26+)
  ├─ DocumentIngestionService (file import)
  ├─ KeychainService (API key storage)
  ├─ DiffEngine (article diff/patch)
  └─ MarkdownParser (chat message rendering)
```

### File Size Report

| File | Lines | Status |
|------|-------|--------|
| AppState.swift | 295 | ⚠️ Over 250 |
| ChatView.swift | 227 | ✅ Under 250 |
| CopilotPanel.swift | 217 | ✅ Under 250 |
| SidebarView.swift | 272 | ⚠️ Over 250 |
| MarkdownMessageText.swift | 218 | ✅ Under 250 |
| ArticleEditorView.swift | 234 | ✅ Under 250 |
| ArticleWorkspaceView.swift | 491 | ⚠️ Over 250 |
| ArticlesDashboardView.swift | 424 | ⚠️ Over 250 |

### Completed Refactoring Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1.1 | Unified `WriteVibeError` (9 cases, `LocalizedError`) | ✅ |
| 1.2 | `AIStreamingProvider` protocol (`AsyncThrowingStream`) | ✅ |
| 1.3 | `AppConstants` (magic values extracted) | ✅ |
| 1.4 | `ServiceContainer` DI skeleton | ✅ |
| 1.5 | All 3 AI services conform to protocol | ✅ |
| 2.1 | `ExportService` extracted | ✅ |
| 2.2 | `ConversationService` extracted | ✅ |
| 2.3 | `StreamingService` extracted | ✅ |
| 2.4 | AppState slimmed (450 → 178 lines) | ✅ |
| 3.1 | `WritingMode` / `WritingAction` models | ✅ |
| 3.2 | `MarkdownParser` extracted (365 → 189 lines) | ✅ |
| 3.4 | `ArticleEditorViewModel` extracted (410 → 221 lines) | ✅ |
| 3.5 | `ArticleComponents` shared UI (Dashboard, Workspace) | ✅ |
| 4.1 | `audience` field on Article + sentinel migration | ✅ |
| 4.3 | `modelUsed` / `tokenCount` on Message | ✅ |
| 5.1 | `pullModel()` → `AsyncThrowingStream` | ✅ |
| 5.4 | `ArticleAIService` decoupled from OpenRouterService | ✅ |
| 6 | Stub TODOs, dead code removal, ModelProvider dedup | ✅ |

### Skipped (risk or low value)

| Phase | Description | Reason |
|-------|-------------|--------|
| 3.3 | ChatViewModel | Send/stop logic already thin (5–7 lines); over-engineering |
| 4.2 | BlockType storage optimization | Completed in this map |
| 4.4 | `ollamaModelName` rename | Completed in this map |
| 5.2 | KeychainService hardening | Completed in this map |
| 5.3 | DocumentIngestionService hardening | Completed in this map |

---

## Suggested Sprint Order

1. **Sprint A (stability):** P0 items — KeychainService + DocumentIngestionService error handling
2. **Sprint B (architecture):** P1 items — ChatView/CopilotPanel dedup, DI wiring, AppState init move
3. **Sprint C (data model):** P2 items — `modelIdentifier` rename, BlockType optimization (requires test infra from Sprint D)
4. **Sprint D (quality):** P3 testing items — service unit tests, ViewModel tests, migration integration tests
5. **Sprint E (features):** P3 stubs — feedback, regenerate, capability chips (each is independently shippable)
