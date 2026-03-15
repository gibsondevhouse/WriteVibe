# WriteVibe Roadmap
_Interrogation of unused capabilities and prioritised feature backlog_

---

# WriteVibe Roadmap
_Interrogation of unused capabilities and prioritised feature backlog_

---

## Current state (v1.3 — what is actually wired)

| Area | Status |
|---|---|
| `LanguageModelSession` streaming | ✅ Live |
| Session prewarm on new conversation | ✅ Live |
| Context window exceeded error handling | ✅ Live |
| Multi-turn session history per conversation | ✅ Live |
| Writing action chips (Improve / Expand / Shorten / Rephrase / Continue) | ✅ Live |
| Sidebar with time-grouped conversation list + search | ✅ Live |
| Persistent storage (SwiftData) | ✅ Live |
| AI auto-titling via `@Generable` structured generation | ✅ Live |
| Conversation rename (context menu + alert) | ✅ Live |
| UI polish — WritingModeCard grid, redesigned sidebar rows, brand header | ✅ Live |
| Export: copy last reply to clipboard | ✅ Live |
| Export: save full conversation as Markdown file | ✅ Live |
| Context window usage indicator in input bar | ✅ Live |
| Keychain-based API key storage (`KeychainService`) | ✅ Live |
| Settings screen (Anthropic + OpenAI key entry) | ✅ Live |
| Anthropic SSE backend (Claude 3.5 Sonnet, Claude 3 Opus) | ✅ Live |
| Document ingestion (txt / md / rtf via `NSOpenPanel`) | ✅ Live |
| Ollama local model support (full stack — list, pull, delete, stream) | ✅ Live |
| In-app Ollama model browser (`OllamaModelBrowserView`) | ✅ Live |
| Dynamic model picker (On-Device / Local / Cloud sections) | ✅ Live |
| OpenRouter gateway (14+ models) | ✅ Live |
| GPT-4o, Mistral, DeepSeek, Gemini via OpenRouter | ✅ Live (model ID audit recommended) |
| Perplexity Sonar web search context injection | ✅ Live |
| Capability chips (tone, length, format, memory, search) | ✅ Live — wired to system prompt |
| Block-based Article editor with AI Copilot panel | ✅ Live |
| Writing analysis panel (tone / reading level / suggestions) | ✅ Live |
| Search spinner feedback (`isSearchFetching`) | ✅ Live |
| ServiceContainer DI + full service layer refactor | ✅ Live |
| Ollama download cancellation | ⚠️ Clears UI state only — network task still runs |
| Search layer in Ollama-only mode (no OpenRouter key) | ⚠️ Silently fails — needs key-presence guard |
| Duplicate input bar files (ChatInputBar.swift ≈ InputBar.swift) | ⚠️ Tech debt — stale copy should be deleted |
| Anthropic API version header | ⚠️ `"2023-06-01"` is stale — update in AppConstants |
| Attachment menu — image, URL, voice | ⚠️ URL + document wired; image and voice are UI stubs |
| Settings → Help footer button | ⚠️ UI stub — does nothing |
| Diff view in chat MessageBubble | ❌ Not built (DiffEngine exists, wired in Articles only) |
| Multiple draft variants | ❌ Not built |

---

## Tier 1 — Foundation Models capabilities not yet used

These are API features Apple ships today that WriteVibe can call without any backend or account.

### 1.1 Guided generation (`@Generable`) for structured writing tasks

**What it is:** `LanguageModelSession.respond(generating: SomeType.self, ...)` returns a Swift struct instead of free text. The OS enforces the schema via constrained decoding — the model cannot produce an invalid response.

**WriteVibe opportunities:**
- **Auto-title generation** — instead of truncating the first 45 chars, ask the model to return `struct ConversationTitle { var title: String }` from the first user message. Short, accurate, no truncation bugs.
- **Tone + reading-level analysis** — `struct WritingAnalysis { var tone: String; var readingLevel: String; var wordCount: Int; var suggestions: [String] }` — show as an inline panel below any assistant response.
- **Structured outline generation** — when the user taps "Create Outline", return `struct Outline { var title: String; var sections: [Section] }` and render it as an expandable tree rather than flat markdown.
- **Multiple draft variants** — `struct DraftVariants { var drafts: [String] }` — surface as tabs the user can pick between.

**Effort:** Low. No new infrastructure — just a new session call type and a small SwiftUI component per use case.

---

### 1.2 Tool calling (`Tool` protocol)

**What it is:** You define a struct conforming to `Tool`, attach it to a `LanguageModelSession`, and the model decides when to call it. The framework manages the tool-call graph — you just provide `perform()`.

**WriteVibe opportunities:**
- **`ClipboardTool`** — lets the model read the current clipboard without the user having to paste it. "Improve what I just copied" becomes a real one-tap action.
- **`DateTimeTool`** — gives the model awareness of today's date for "write a newsletter for this week" or "draft a Monday morning email".
- **`WordCountTool`** — lets the model check its own output length mid-generation and self-correct if it's writing too long.
- **`WebSearchTool`** (when cloud models are wired) — the web search toggle in `InputBar` is already in the UI but does nothing. Tools are the right architectural home for this.

**Effort:** Medium. Each tool is a small struct. The main work is registering tools on the session object and adjusting the system prompt to explain when to use them.

---

### 1.3 `prewarm(promptPrefix:)` with a real prefix

**What it is:** Pass an expected prompt prefix to `prewarm()` so the KV-cache is seeded with the most likely start of the next request. The current call passes no prefix.

**WriteVibe opportunity:** After the user clicks a suggestion card (e.g., "Write a blog post"), immediately call `session.prewarm(promptPrefix: "Write a compelling blog post about ")` so the model is loaded and partially warmed before the user even finishes typing.

**Effort:** Trivial — one argument change.

---

### 1.4 `Transcript` export for session inspection / quality analysis

**What it is:** `LanguageModelSession` maintains a `transcript` property. Apple's Python SDK (`apple-fm-sdk`) can load exported transcripts for analysis.

**WriteVibe opportunity:** Wire the Export footer button to serialize `session.transcript` alongside the conversation's `Message` array. Gives you a debugging and quality-testing pipeline: export a session from the app, load it in Python, run batch prompt-quality analysis without rebuilding in Xcode.

**Effort:** Low. Export is already a stub button.

---

## Tier 2 — Writing-specific product surface missing entirely

These don't require new AI capabilities — they're product features a writing tool needs that aren't built yet.

### 2.1 ~~Persistent storage~~ ✅ Done (v1.0)

> SwiftData implemented. Conversations and messages persist across restarts with cascade deletion.

---

### 2.2 Diff view — show what changed

**Current state:** When the user asks "Improve this", the model returns the full rewritten text. The user has to manually read and compare.

**Fix:** When an "Improve", "Rephrase", or "Shorten" action chip fires, store the previous assistant message content and show a side-by-side or inline diff (words added in green, removed in red/strikethrough) before the full replacement. macOS `NSAttributedString` diff rendering or a simple word-level diff algorithm handles this.

**Effort:** Medium. The diff logic is self-contained; the UI change is localized to `MessageBubble`.

---

### 2.3 Multiple draft variants side-by-side

**Current state:** Every generation produces one response.

**Fix:** A "Variants" button in the writing action bar triggers guided generation returning `DraftVariants` (see §1.1), rendered as swipeable/tab-selectable cards. User picks the one they want.

**Effort:** Medium. Depends on §1.1 guided generation.

---

### 2.4 ~~Conversation rename~~ ✅ Done (v1.0)

> Context menu → "Rename Conversation" triggers a native macOS alert with a text field.

---

### 2.5 Context window usage indicator

**Current state:** The user has no visibility into how close they are to the 4096-token limit. The error only fires when it's already too late.

**Fix:** Show a subtle token-budget progress bar or colour change in the input bar as the estimated token count (rough heuristic: `totalCharacters / 4`) approaches the limit. Warn at 80%, disable send at 95%.

**Effort:** Low. No new API calls — just character counting on the message array.

---

### 2.6 Export to markdown / rich text / clipboard

**Current state:** The Export footer button is a stub.

**Fix:** Export the last assistant message (or full conversation) as:
- Plain markdown to clipboard (one tap)
- `.md` file via `NSSavePanel`
- RTF/DOCX via `NSAttributedString` conversion

**Effort:** Low to medium depending on format support.

---

### 2.7 Voice input (Speech framework)

**Current state:** The microphone option in `AttachMenu` is a UI stub.

**Fix:** Wire `SFSpeechRecognizer` with a live `AVAudioEngine` session. Transcribe in real time into the input field. This works entirely on-device on Apple Silicon.

**Effort:** Medium. Requires microphone permission and an `AVAudioSession` setup.

---

### 2.8 Drag-and-drop / file import for text

**Current state:** The "Upload Document" option in `AttachMenu` is a stub. Users can only type or paste.

**Fix:** Accept `.txt`, `.md`, `.rtf`, `.docx` drag-and-drop onto the chat window. Read the text content and pre-fill it as the user message (with a visible "Paste from file" label). Uses `NSOpenPanel` or SwiftUI `onDrop`.

**Effort:** Low for `.txt`/`.md`; Medium for `.docx` (requires `NSAttributedString` RTF or a small parser).

---

## Tier 3 — System integrations not used

### 3.1 App Intents — Siri and Shortcuts

**What it unlocks:** Users can say "Hey Siri, start a new WriteVibe chat about [topic]" or build Shortcuts automations like "Every Monday, open WriteVibe with a newsletter draft prompt."

**Intents to define:**
- `NewWritingSessionIntent(topic: String?)` — opens the app and starts a chat with an optional seed topic
- `ImproveClipboardIntent` — reads clipboard, runs the Improve prompt, writes result back to clipboard (fully headless — no UI needed)
- `GenerateOutlineIntent(topic: String)` — returns text for use in Shortcuts chains

**Effort:** Medium. Well-documented API, no backend required.

---

### 3.2 Writing Tools system integration

**What it is:** macOS Writing Tools (available system-wide) can invoke registered app extensions when the user selects text in any app. WriteVibe could register as a writing tool so it appears in the system Writing Tools popover.

**WriteVibe opportunity:** "Open in WriteVibe" as a Writing Tools action — selected text from any app flows into a new WriteVibe conversation pre-filled with the content. Zero friction for the "improve something I wrote elsewhere" use case.

**Effort:** Medium-high. Requires an App Extension target.

---

### 3.3 Image Playground integration

**What it is:** `ImageCreator` / `imagePlaygroundSheet` — programmatic or system-sheet-based on-device image generation.

**WriteVibe opportunity:** After generating a blog post or social media caption, offer "Generate cover image" — pass keywords extracted from the text (via guided generation) as concepts to Image Playground. Returns a ready-to-use image alongside the copy.

**Effort:** Medium. Requires extracting keywords (guided generation, §1.1) and wiring `imagePlaygroundSheet`.

---

### 3.4 Spotlight / Universal Search indexing

**What it is:** `CoreSpotlight` CSSearchableItem indexing makes conversation titles and snippets searchable from Spotlight.

**WriteVibe opportunity:** Index each conversation so the user can find past writing work from Spotlight without opening the app.

**Effort:** Low. A few lines per conversation save/update.

---

## Tier 4 — Cloud model integration

**Claude 3.5 Sonnet and Claude 3 Opus are fully live as of v1.2.** `AnthropicService.swift` streams via `https://api.anthropic.com/v1/messages` SSE; the key is stored in Keychain and entered via Settings.

The OpenAI API key is stored in Keychain as of v1.3 (Settings → Cloud API Keys), priming the GPT-4o backend for Phase 4.

Remaining providers — GPT-4o, Mistral Large, Gemini 1.5 Pro — still return a "not yet configured" message. The `generateReply` routing and Settings architecture are ready.

**Status as of March 2026:**
- **GPT-4o, Mistral, DeepSeek, Perplexity Sonar** — ✅ Live via `OpenRouterService`. All OpenAI-compatible models route through the same SSE path.
- **Gemini** — ⚠️ Routed through OpenRouter; model ID strings (`"google/gemini-flash-1.5"`, `"google/gemini-pro-1.5"`) need verification against current OpenRouter catalog.
- **Claude** — Routes through OpenRouter by preference; `AnthropicService` available as direct fallback when no OpenRouter key is set.
- App Store privacy disclosure and explicit user opt-in for any provider before text leaves device (App Store Guideline 5.1.2).

**Strategic value:** Cloud models give WriteVibe access to much larger context windows and stronger world-knowledge, covering the on-device model's biggest weakness for long-form editing tasks.

---

## Priority order summary

✅ = shipped · ⚠️ = partial · blank = not started

| # | Item | Tier | Effort | Impact | Status |
|---|---|---|---|---|---|
| 1 | Persistent storage (SwiftData) | 2 | M | 🔴 Critical | ✅ v1.0 |
| 2 | Conversation rename | 2 | S | 🟡 Polish | ✅ v1.0 |
| 3 | Auto-title via guided generation | 1 | S | 🟡 Polish | ✅ v1.0 |
| 4 | Context window usage indicator | 2 | S | 🟡 Reliability | ✅ v1.2 |
| 5 | Export to clipboard / markdown file | 2 | M | 🟠 Core utility | ✅ v1.2 |
| 6 | `prewarm(promptPrefix:)` on suggestion tap | 1 | S | 🟡 Performance | ✅ v1.1 |
| 7 | Anthropic (Claude) backend | 4 | M | 🟠 Expansion | ✅ v1.2 |
| 8 | Document ingestion (txt / md / rtf) | 2 | S | 🟠 Workflow | ✅ v1.2 |
| 9 | Ollama local model backend | 4 | L | 🟠 Expansion | ✅ v1.3 |
| 10 | GPT-4o / OpenAI backend | 4 | M | 🟠 Expansion | ✅ Live via OpenRouter |
| 11 | Mistral backend | 4 | S | 🟠 Expansion | ✅ Live via OpenRouter |
| 12 | Gemini backend | 4 | M | 🟠 Expansion | ⚠️ Via OpenRouter — model ID needs verification |
| 13 | Diff view in chat MessageBubble | 2 | M | 🟠 Differentiator | ⚠️ DiffEngine exists, wired in Articles only |
| 14 | Tone + reading-level analysis panel | 1 | M | 🟠 Differentiator | ✅ Live (WritingAnalysisPanelView) |
| 15 | Multiple draft variants | 2 | M | 🟠 Differentiator | |
| 16 | Tool calling (clipboard, date) | 1 | M | 🟠 AI depth | |
| 17 | App Intents (Siri / Shortcuts) | 3 | M | 🟠 Platform depth | |
| 18 | Voice input via Speech framework | 2 | M | 🟠 Accessibility | |
| 19 | Drag-and-drop file import | 2 | S–M | 🟠 Workflow | |
| 20 | Search citations panel (Sources footer) | 2 | S | 🟠 Trust/UX | |
| 21 | Error alert state (replace ⚠️ messages) | 2 | S | 🟠 UX polish | |
| 22 | Image Playground cover image | 3 | M | 🔵 Delight | |
| 23 | Writing Tools system extension | 3 | H | 🔵 Platform depth | |
| 24 | Spotlight indexing | 3 | S | 🔵 Polish | |
| 25 | Transcript export for Python analysis | 1 | S | 🔵 Dev tooling | |
