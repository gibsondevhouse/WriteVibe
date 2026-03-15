Now I have a thorough picture of the entire codebase. Let me compile the development plan.

***

## WriteVibe — Development Plan (March 2026)

### Architecture Snapshot

WriteVibe is a macOS SwiftUI app targeting macOS 26+ with a clean, well-structured layered architecture:[1][2]

- **State layer**: `AppState` (single `@Observable` controller) + `ServiceContainer` dependency injection
- **Service layer**: `StreamingService`, `ConversationService`, `OllamaService`, `AnthropicService`, `OpenRouterService`, `AppleIntelligenceService`
- **Data layer**: SwiftData (`Conversation`, `Message`, `Article`, `ArticleBlock`)
- **Feature layer**: Chat, Articles, Settings, Sidebar, Welcome — each self-contained
- **Protocol boundary**: `AIStreamingProvider` unifies all backends behind one `stream()` contract[3]

***

## What's Live (v1.3)

| Area | Status |
|---|---|
| Apple Intelligence on-device streaming | ✅ Live |
| Ollama local model full stack (list, pull, delete, stream) | ✅ Live |
| Anthropic (Claude Sonnet/Opus) via direct SSE | ✅ Live |
| OpenRouter gateway (14+ models in picker) | ✅ Live |
| Perplexity Sonar/Sonar Pro web search layer | ✅ Live |
| SwiftData persistence (conversations + messages) | ✅ Live |
| Article/block editor with AI Copilot panel | ✅ Live |
| Capability chips: tone, length, format, memory | ✅ Live (UI + system prompt injection) |
| Keychain API key storage | ✅ Live |
| Export: clipboard + markdown file | ✅ Live |
| Context window usage indicator | ✅ Live |
| AI auto-titling via `@Generable` | ✅ Live |
| Document ingestion (.txt/.md/.rtf) | ✅ Live |

***

## Critical Bugs & Immediate Fixes

These should be resolved before any new features are added.[4]

### 1. Ollama download cancellation is broken
- **Problem**: Tapping "Cancel" in `OllamaModelBrowserView` clears UI state only; the underlying `URLSession` network task keeps running.[4]
- **Fix**: `OllamaService.pullModel()` returns an `AsyncThrowingStream`. Store the owning `Task` in a `@State` variable in `OllamaModelBrowserView` and call `.cancel()` on it — this triggers `Task.checkCancellation()` and tears down the stream.

### 2. Search layer passes local Ollama model names to OpenRouter
- **Problem**: In `StreamingService.fetchWebSearchContext()`, when `isSearchEnabled` is true but the selected model is not Sonar-native, `searchLayerModel` falls back to `perplexity/sonar-pro` — but this only works if the OpenRouter key is stored. If it's missing and the user is in Ollama-only mode, the fetch silently fails.[5]
- **Fix**: Gate `fetchWebSearchContext` with a Keychain presence check for `openrouter_api_key` before attempting the call; surface a clear inline error if missing.

### 3. `AppleIntelligenceService` — `migrateLegacyModels` silently converts valid AI conversations to Ollama
- **Problem**: `ConversationService.migrateLegacyModels()` converts any `.appleIntelligence` model to `.ollama`, but Apple Intelligence is still a valid backend. This is a leftover from an earlier removal that was reversed.[2]
- **Fix**: Remove the migration or gate it behind a specific version flag.

***

## Phase 4 — Cloud Backend Completion (High Priority)

The routing infrastructure in `AppState.generateReply()` is ready; only the service implementations are missing.[2][4]

### 4.1 OpenAI / GPT-4o Backend
- `OpenRouterService` already handles GPT-4o via OpenRouter — **this is already live**. The "not yet configured" message fires only for models whose `openRouterModelID` returns `nil`.
- **Action**: Audit `AIModel.openRouterModelID` for `gpt4o`, `gpt4oMini`, `o3Mini` — verify the OpenRouter model IDs are correct strings (e.g. `"openai/gpt-4o"`).[3]

### 4.2 Gemini Backend
- `geminiFlash` and `geminiPro` return `.openRouterModelID` but are flagged as "stubbed" in the roadmap.[4]
- **Action**: Verify the OpenRouter model ID strings for `"google/gemini-flash-1.5"` and `"google/gemini-pro-1.5"` — these should already work through the existing `OpenRouterService` without a new service file.

### 4.3 DeepSeek R1 / V3
- Same situation as Gemini — routed through OpenRouter, likely just needs correct model ID strings verified.[3]

***

## Phase 5 — Search Quality Improvement (High Priority)

This directly caused the Gemma3:4b accuracy failures you observed today.[5]

### 5.1 Structured search result injection
- **Problem now**: Search context is injected as a raw string blob: `"WebResearchContext (from sonar-pro): [bullet list]"`. Small local models like Gemma3:4b don't reliably bind facts from this blob to the answer — they pattern-match around it.[5]
- **Fix**: Parse Sonar's bullet response into a structured `[SearchResult]` array (title, URL, snippet) and inject it as a JSON object the system prompt explicitly references field-by-field. Force-cite each claim by appending `[Source: {url}]` inline in the context.

### 5.2 Grounding instruction for local models
- Add a dedicated "grounding mode" system prompt suffix when `model.isLocal == true` and search is enabled:[3][5]
```
IMPORTANT: Your only sources for dates, names, titles, and roles 
are the WebResearchContext above. If a fact is not in the context, 
say "I don't have current data on this" rather than guessing.
```

### 5.3 Search toggle visual feedback
- The web search toggle is in `InputBar` but gives no feedback when the Sonar fetch is in progress.[4]
- **Fix**: Add a `.task`-driven `isSearchFetching: Bool` state to `AppState`; show a spinner on the search button while `fetchWebSearchContext` runs.

***

## Phase 6 — Apple Intelligence Deep Integration (Medium Priority)

Several FoundationModels capabilities are unused.[4]

### 6.1 Tool calling
- Implement `DateTimeTool` first (trivial — returns `Date()`) so any local or Apple Intelligence conversation knows today's date without relying on search.
- `ClipboardTool` second — lets "improve what I just copied" work as a one-tap action from the writing action chips.
- Wire both to `AppleIntelligenceService` session setup.

### 6.2 Structured tone/reading-level analysis panel
- Use `@Generable` to return `WritingAnalysis { tone, readingLevel, wordCount, suggestions }` on demand.
- Surface as a collapsible panel below any assistant message — toggle via a new action chip "Analyze."

### 6.3 Multiple draft variants
- `@Generable` returning `DraftVariants { drafts: [String] }` — render as tabbed cards the user picks between.
- Add a "Variants" chip alongside Improve/Expand/Shorten.

### 6.4 `prewarm(promptPrefix:)` on writing mode card tap
- Currently called with no prefix.[4]
- When user taps a `WritingModeCard`, immediately call `prewarm(promptPrefix: card.seedPrompt)` to pre-warm the KV cache before the user types.

***

## Phase 7 — Writing Surface Improvements (Medium Priority)

### 7.1 Diff view for Improve/Rephrase
- Store previous `Message.content` before a rewrite chip fires.
- Compute a word-level diff using a simple LCS algorithm (no external dependency needed).
- Render added words in `.green`, removed words in red strikethrough inside `MessageBubble`.[4]
- `DiffEngine.swift` already exists in Services — check if it's wired.[6]

### 7.2 Drag-and-drop file import
- Attachment menu button in `ChatInputBar` is UI-only.[4]
- Add SwiftUI `onDrop(of: [.fileURL])` to `ChatInputBar`, route `.txt`/`.md`/`.rtf` through `DocumentIngestionService` (already implemented).[6]
- Show a "File attached" chip above the text field with a dismiss button.

### 7.3 Voice input
- Wire `SFSpeechRecognizer` + `AVAudioEngine` to the microphone stub in `AttachMenu`.
- On-device, Apple Silicon — no network required.
- Live transcription streams into the text field.

***

## Phase 8 — System Integration (Lower Priority)

### 8.1 App Intents (Siri/Shortcuts)
- `NewWritingSessionIntent(topic: String?)` — opens app with a seeded prompt.
- `ImproveClipboardIntent` — headless: reads clipboard, runs Improve, writes back.
- These are high-value, low-effort system integrations.[4]

### 8.2 Spotlight indexing via CoreSpotlight
- Index conversation titles + first message snippet on each `context.save()`.
- Tap-through opens the app to that conversation.[4]

### 8.3 Writing Tools system extension
- Register WriteVibe as a system Writing Tools provider so selected text in any app can flow in.
- Highest effort of this group — requires a separate App Extension target.[4]

***

## Phase 9 — Polish & Infrastructure

### 9.1 `Item.swift` cleanup
- `Item.swift` currently holds unrelated model code (the legacy default filename from Xcode project template). The `writeVibeSystemPrompt` string is also defined here.
- Move system prompt into a dedicated `SystemPrompts.swift` under `Resources/` for cleaner separation.

### 9.2 Error handling audit
- `WriteVibeError` is well-defined but `AppState.generateReply()` catches generic `Error` and wraps it in a user-facing message. Add specific handling for `URLError.timedOut` (Ollama not responding) vs. `WriteVibeError.missingAPIKey` vs. decode failures.[2]

### 9.3 Test coverage
- `WriteVibeTests/` and `WriteVibeUITests/` directories exist but contents are unknown.[7]
- Priority test targets: `StreamingService.fetchWebSearchContext`, `ConversationService.appendMessage`, `OllamaService.isRunning`.

***

## Recommended Sprint Order

| Sprint | Focus | Why |
|---|---|---|
| **Now** | Bug fixes (§Critical) + OpenRouter model ID audit | Unblocks all cloud models with zero new code |
| **Next** | Search grounding improvement (§5.1–5.2) | Directly fixes the Gemma3 accuracy problem |
| **Sprint 3** | Diff view + drag-and-drop (§7.1–7.2) | High-impact writing UX, self-contained |
| **Sprint 4** | DateTimeTool + ClipboardTool (§6.1) | Low effort, high reliability gain for local models |
| **Sprint 5** | App Intents + Spotlight (§8.1–8.2) | Platform depth, low risk |
| **Sprint 6** | Draft variants + analysis panel (§6.2–6.3) | Differentiating AI features |
| **Sprint 7** | Voice input + Writing Tools extension (§7.3, §8.3) | Longest implementation, saves for last |

***

## Audit Addendum (March 15, 2026)

Full file-by-file codebase audit completed. The following are findings not captured above.

---

### Status Corrections

**Bug #3 is already resolved.** `ConversationService.swift` contains a comment confirming `migrateLegacyModels` was removed. No action needed.

**Phase 9.1 is already resolved.** `Item.swift` is now an empty placeholder file with comments only. `writeVibeSystemPrompt` lives in `Resources/SystemPrompt.swift`. No action needed.

---

### New Bugs

#### B4. Duplicate input bar files — dead code risk
- **File**: `ChatInputBar.swift` and `InputBar.swift` in `Features/Chat/`
- **Problem**: Both files are nearly identical. `InputBar.swift` is the wired version (includes the `isSearchFetching` spinner). `ChatInputBar.swift` is a near-duplicate that lacks the spinner. Risk of the wrong version being used in a new context or being edited out of sync.
- **Fix**: Delete `ChatInputBar.swift`. All call sites should reference `InputBar.swift`. Rename `InputBar.swift` → `ChatInputBar.swift` for clarity if desired.

#### B5. Anthropic API version is 2+ years stale
- **File**: `AppConstants.swift` → `anthropicAPIVersion = "2023-06-01"`
- **Problem**: It is March 2026. Anthropic has made multiple API versions since June 2023. Using a legacy version may miss error formats, tool calling improvements, and model features. Anthropic rejects unknown versions with a 400.
- **Fix**: Update `anthropicAPIVersion` to the latest stable string. Verify against Anthropic's versioning docs. Since it's an `AppConstants` constant, one-line change.

#### B6. Article AI edits silently fail in Ollama-only mode
- **File**: `ArticleAIService.swift`
- **Problem**: `proposeEdits()` calls `OpenRouterService` directly. If the user has no OpenRouter API key saved (e.g., Ollama-only mode), the service throws `missingAPIKey`, which is caught in `ArticleEditorViewModel.requestAIEdits()` — it sets `aiErrorMessage` but this is only shown in a red banner inside `ArticleEditorView`. If `ArticlesDashboardView` triggers "AI Edit" from the dashboard-level button (outside the editor), there is no error surface.
- **Fix**: Same key-presence guard as Bug #2 fix. Additionally, route Article AI edits through `ServiceContainer.provider(for:)` using the active `defaultModel` so Ollama-capable models work without a cloud key.

---

### New UX Improvements

#### U1. No search citations panel — user never sees what was retrieved
- Search results are fetched from Perplexity Sonar, injected into the system prompt as a JSON array, and consumed invisibly. The user has no way to verify sources, check URLs, or audit what the model was given.
- **Fix**: After a search-augmented reply renders, display a collapsible "Sources" footer below the assistant message in `MessageBubble`. Tap to expand a compact list of `SearchResult` cards (title + URL as tappable link). No new state needed — attach `[SearchResult]` to the `Message` model (add optional `searchSources: [SearchResult]?` field, `@Transient` if not persisting).

#### U2. Error handling surfaces as in-message `⚠️` text — no alert state
- **File**: `AppState.generateReply()`
- **Problem**: When generation fails, `AppState` appends a Message with `"⚠️ [error description]"` as content. This is indistinguishable from a real assistant message in the history, pollutes conversation exports, and gives the user no action to take.
- **Fix**: Add `var alertError: AppError?` to `AppState`. In the catch block, set it instead of appending a message. Bind it to a `.alert()` modifier in `ChatView`. Keep the `⚠️` fallback only for `CancellationError` (user-initiated stop).

---

### Tech Debt

#### T1. `migrateArticleAudience()` uses sentinel string parsing — fragile
- **File**: `AppState.swift`
- **Problem**: Migration reads sentinel strings embedded in the `quickNotes` field to detect legacy audience values. If a user types a string that matches a sentinel, it will be misinterpreted and data will be silently corrupted on next launch.
- **Fix**: Use SwiftData's native schema migration (`VersionedSchema` + `MigrationStage`) to handle field additions instead of string-sentinel hacks. Mark the current schema as v1 and the migrated schema as v2.

#### T2. `SearchResult.id` UUID is dead code
- **File**: `Models/SearchResult.swift`
- **Problem**: `id: UUID = UUID()` is declared on `SearchResult` but is never decoded from the Sonar JSON response (`CodingKeys` doesn't include it). It's a meaningless auto-generated value that wastes 16 bytes per result and creates a false identity contract.
- **Fix**: Either make `SearchResult` conform to `Identifiable` explicitly using `url` as the stable identifier, or remove the `id` field entirely and use `[SearchResult].enumerated()` for list rendering.

---

### Test Coverage — Specific Gaps

The §9.3 entry says contents were "unknown" — they are now known:

| Test File | Status | Action |
|---|---|---|
| `WriteVibeTests.swift` | Empty placeholder only | Delete or fill — empty files mislead CI coverage reports |
| `WriteVibeUITests.swift` | Boilerplate launch test only | At minimum: test that welcome screen renders, model picker opens |
| `DocumentIngestionServiceTests.swift` | 2 test functions exist but are unimplemented (commented stubs) | Implement using `URLProtocol` mock for `fetchURL`, temp files for `pickAndExtract` text path |

Priority test additions beyond §9.3:
- `ArticleAIService.proposeEdits()` — test the JSON-parse-fail path returns a safe empty result with error summary
- `AppState.estimatedTokenUsage()` — trivial but guards against regression on the usage bar
- `KeychainService` — save/load/delete round trip in a test keychain

---

### Phase 10 — Sidebar Feature Roadmap (Future)

Ten sidebar items are currently marked "Soon" (opacity 0.7, non-interactive). These are future feature shells, not bugs. Capturing them here so they have a home in the plan.

**Apps section (4 items):**
- **Images**: Generate or attach images to conversations. Likely DALL-E / Stable Diffusion via OpenRouter's image endpoints.
- **Canvas**: Freeform whiteboard. Likely a PencilKit surface — macOS has limited Apple Pencil support; this may become a rich text/diagram canvas instead.
- **Templates**: Pre-seeded prompts/conversation starters. Low effort — just a list of `WritingModeCard`-style items that pre-fill `AppState.pendingPrompt`.
- **Mood Board**: Visual inspiration collection. Unclear scope — could be image grid + tag system.

**Library section (6 items):** Emails, Stories, Essays, Poetry, Scripts, Research
- These appear to be Article sub-types or dedicated writing surfaces with domain-specific AI prompting.
- **Lowest-effort path**: Add these as first-class `ArticleTone`/writing mode values that change the system prompt suffix, rather than building new screens.
- **Recommended order**: Templates → Emails → Essays → Stories → Scripts → Poetry → Canvas → Images → Mood Board (complexity ascending).

---

### Entitlements & Distribution Readiness

- `WriteVibe.entitlements` has 3 entitlements: sandbox, network client, user-selected file read-write. This is minimal for current features.
- **FoundationModels / Apple Intelligence**: May require `com.apple.developer.FoundationModels` entitlement for App Store distribution (pending Apple's developer documentation for macOS 26 release). Verify before submitting.
- **NSBonjourServices**: Not declared in `Info.plist`. Will be required if Ollama auto-discovery via mDNS is added (Phase 8 or later). Add `_http._tcp` or Ollama-specific service type proactively.
- **Microphone permission**: `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` strings not yet in `Info.plist`. Must be added before §7.3 voice input ships — App Store review rejects apps that use the microphone without these strings, and the OS will silently deny the permission at runtime.