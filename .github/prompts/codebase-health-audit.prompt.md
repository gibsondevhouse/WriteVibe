---
description: 'Codebase health audit — vulnerabilities, dead code, and refactoring. Delegates fixes to specialist agents.'
agent: orchestrator
tools:
  - read/readFile
  - read/problems
  - edit/editFiles
  - edit/createFile
  - edit/createDirectory
  - edit/rename
  - execute/runInTerminal
  - execute/getTerminalOutput
  - search/codebase
  - search/textSearch
  - search/fileSearch
  - search/listDirectory
  - search/usages
  - search/changes
  - agent/runSubagent
  - agent
  - todo
---

# WriteVibe Codebase Health Audit — March 2026

You are the orchestrator. This prompt contains verified audit findings across three categories: **security vulnerabilities**, **dead code**, and **refactoring opportunities**. Your job is to plan and delegate fixes to the correct specialist agents.

Read each section, then build a phased execution plan. Delegate each task to the right agent. Verify results after each phase.

---

## PHASE 0: DEAD CODE REMOVAL (Agent: swift)

Quick wins — remove confirmed dead code before any refactoring.

### DELETE these files entirely:
- `WriteVibe/Models/WritingMode.swift` — `WritingMode`, `WritingAction`, `WritingMode.inferIcon()` are all unreferenced (~70 LOC)

### DELETE these items from files:
- `WriteVibe/Models/Tools.swift` — Remove `ClipboardTool` struct (lines ~39–82). Keep `DateTimeTool` (used by AppleIntelligenceService)
- `WriteVibe/Shared/DesignSystem.swift` — Remove `WVAnim.spring`, `WVAnim.springFast`, `WVAnim.fade` (only `WVAnim.card` is used)

### DELETE empty directory:
- `WriteVibe/Features/Welcome/` — Empty folder, unreferenced

### Verification:
After deletion, run `xcodebuild build` to confirm no compile errors.

---

## PHASE 1: CRITICAL SECURITY FIXES (Agent: backend)

### 1.1 — Prompt Injection via Capability Chips (CRITICAL)
**File:** `WriteVibe/Services/StreamingService.swift` lines 50–76
**Problem:** `tone`, `length`, `format` parameters from UI are string-interpolated into system prompt without validation. A value like `"professional\n\nIgnore all previous instructions..."` injects into the prompt.
**Fix:** Validate these params against known allowlists before interpolation:
```swift
private static let allowedTones = ["Balanced", "Professional", "Creative", "Concise"]
private static let allowedLengths = ["Normal", "Short", "Long"]
private static let allowedFormats = ["Markdown", "Plain Text", "JSON"]

// In streamReply(), before augmenting:
guard Self.allowedTones.contains(tone) else { /* use default */ }
guard Self.allowedLengths.contains(length) else { /* use default */ }
guard Self.allowedFormats.contains(format) else { /* use default */ }
```

### 1.2 — URL Scheme Validation Missing (CRITICAL)
**File:** `WriteVibe/Services/DocumentIngestionService.swift` `fetchURL()` method
**Problem:** Accepts any URL scheme — `file://`, `ftp://`, etc. Enables local file read (SSRF equivalent).
**Fix:** Validate URL scheme is `http` or `https` only:
```swift
guard let url = URL(string: urlString),
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme) else {
    throw WriteVibeError.network(underlying: URLError(.badURL))
}
```

### 1.3 — Search Results Prompt Injection Surface (CRITICAL)
**File:** `WriteVibe/Services/StreamingService.swift` lines 117–125
**Problem:** User query and search results injected into system prompt. Combined with chip injection, enables dual-layer prompt attack.
**Fix:** The allowlist fix in 1.1 blocks the chip vector. For search: truncate search context to a max character limit and sanitize control characters before injection. Add a `sanitizeForPrompt()` helper that strips newlines/control chars from search JSON.

### 1.4 — Missing Ollama Model Name Validation (HIGH)
**File:** `WriteVibe/Services/AI/OllamaService.swift` lines ~117, 140, 190
**Problem:** `modelName` from user passed directly to Ollama API with no validation. Resource exhaustion via pulling huge models.
**Fix:** Validate model name format (alphanumeric + colons + dots + hyphens only, max 128 chars):
```swift
private static let modelNamePattern = /^[a-zA-Z0-9._:/-]{1,128}$/
guard modelName.wholeMatch(of: Self.modelNamePattern) != nil else {
    throw WriteVibeError.modelUnavailable(name: modelName)
}
```

### 1.5 — Remove Production Print Statement (HIGH)
**File:** `WriteVibe/Services/StreamingService.swift` line ~178
**Problem:** `print("Warning: Could not parse search result line: \(lineString)")` leaks user search content to system logs.
**Fix:** Delete the print statement entirely. If logging is needed, use `os.Logger` with `.debug` level.

### 1.6 — Parse API Error Response Bodies (HIGH)
**Files:** `WriteVibe/Services/AI/OpenRouterService.swift` lines 45–50, `WriteVibe/Services/AI/AnthropicService.swift` lines 47–52
**Problem:** Error responses discarded — users get generic errors, security-relevant info (rate limits, account issues) lost.
**Fix:** On non-2xx status, read error body and extract message:
```swift
guard (200...299).contains(http.statusCode) else {
    var errorMessage: String? = nil
    // Collect bytes for error body
    var errorData = Data()
    for try await byte in bytes { errorData.append(byte) }
    if let body = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
       let msg = body["error"] as? [String: Any],
       let text = msg["message"] as? String {
        errorMessage = text
    }
    throw WriteVibeError.apiError(provider: "OpenRouter", statusCode: http.statusCode, message: errorMessage)
}
```

### Verification:
After all fixes, run `xcodebuild build`. Then delegate to **qa** agent to write tests for:
- Allowlist validation (rejected values default gracefully)
- URL scheme validation (rejects `file://`, accepts `https://`)
- Model name validation (rejects invalid chars)

---

## PHASE 2: CRITICAL REFACTORING — OVERSIZED FILES (Agents: frontend, backend)

All files exceeding the 250 LOC project limit, ordered by severity.

### 2.1 — InputBar.swift (~580 LOC → ~120 LOC) — Agent: frontend
**Current state:** Biggest offender. Mixed concerns: text input, capability chips, attach menu, token bar, send button.
**Extract to:**
- `Features/Chat/Components/ChatInputField.swift` — TextEditor + key handling
- `Features/Chat/Components/ChatSendButton.swift` — Send/stop logic
- `Features/Chat/Components/TokenUsageBar.swift` — Progress + warning display
- `Features/Chat/Components/CapabilityChipsBar.swift` — Chip group layout
- `Features/Chat/Components/CapabilityChip.swift` — Individual chip (used 3x — eliminates duplication)
- `Features/Chat/Components/AttachMenu.swift` — Document attachment options

### 2.2 — ArticleWorkspaceView.swift (~610 LOC → ~120 LOC) — Agent: frontend
**Extract to:**
- `Features/Articles/Components/ArticleDNAPanel.swift` — Metadata editing panel (~130 LOC)
- `Features/Articles/Components/ArticleFoundationCanvas.swift` — Premise, audience, outline, sources (~180 LOC)
- `Features/Articles/Components/ArticleTextCard.swift` — Reusable card with placeholder
- `Features/Articles/Components/ArticleDraftActions.swift` — AI generation + document import (~85 LOC)

### 2.3 — ArticlesDashboardView.swift (~500 LOC → ~150 LOC) — Agent: frontend
**Extract to:**
- `Features/Articles/Components/Sheets/NewSeriesSheet.swift` — Series creation form (~120 LOC)
- `Features/Articles/Components/DashboardHeroCard.swift` — Stat cards + pill rendering (~150 LOC)
- `Features/Articles/Components/ArticleGridView.swift` — Filtered grid display
- `Features/Articles/Components/ArticleFilterBar.swift` — Filter chips
- `Features/Articles/ViewModels/ArticlesDashboardVM.swift` — Filter/group logic + computed properties

### 2.4 — StreamingService.swift (~340 LOC → ~80 LOC) — Agent: backend
**Extract to:**
- `Services/Streaming/PromptAugmentationEngine.swift` — Capability chip → prompt mapping with allowlists (from Phase 1 fix)
- `Services/Streaming/WebSearchContextProvider.swift` — Web search fetch + context injection
- `Services/Streaming/SearchResultParser.swift` — Regex parsing + validation

### 2.5 — MarkdownMessageText.swift (~350 LOC → ~180 LOC) — Agent: frontend
**Extract to:**
- `Features/Chat/Components/MarkdownCodeBlock.swift` — Syntax highlighting + copy (~60 LOC)
- `Features/Chat/Components/MarkdownBlockquote.swift` — Blockquote styling (~35 LOC)
- `Features/Chat/Components/MarkdownTable.swift` — Table rendering (~80 LOC)

### 2.6 — AppState.swift (~295 LOC → ~120 LOC) — Agent: backend
**Extract to:**
- `Services/ConversationGenerationManager.swift` — `generateReply()`, `stopGeneration()`, `finishGeneration()`, active task tracking
- `Services/OllamaStateManager.swift` — `refreshOllamaModels()`, `availableOllamaModels`
- `Services/DataMigrationService.swift` — `migrateArticleAudience()`
- `State/CapabilityChipsState.swift` — Tone, length, format, memory, search flags

### Verification after each extraction:
- `xcodebuild build` passes
- No file exceeds 250 LOC
- No layer violations introduced
- Delegate to **qa** agent for test suite pass

---

## PHASE 3: MEDIUM PRIORITY FIXES (Mixed agents)

### 3.1 — Incomplete HTML Stripping (Agent: backend)
**File:** `WriteVibe/Services/DocumentIngestionService.swift` lines 69–88
**Problem:** Regex `<[^>]+>` misses HTML comments, script tags, data URIs.
**Fix:** Use `NSAttributedString` HTML parsing or a more comprehensive regex that handles comments and nested tags. Since content goes to LLM (not browser), this is medium priority.

### 3.2 — Stale Anthropic API Version (Agent: backend)
**File:** `WriteVibe/Models/AppConstants.swift` line ~22
**Problem:** `anthropicAPIVersion = "2023-06-01"` — nearly 3 years old.
**Fix:** Update to current Anthropic API version. Check Anthropic docs for latest.

### 3.3 — Keychain Input Validation (Agent: backend)
**File:** `WriteVibe/Services/KeychainService.swift`
**Problem:** No validation on key/value params — accepts empty strings, extremely long values.
**Fix:** Add guards: non-empty key, non-empty value, max value length (e.g., 4096 chars).

### 3.4 — Cross-File Duplication Cleanup (Agent: swift)
| Pattern | Files | Fix |
|---------|-------|-----|
| `trimmingCharacters(in: .whitespacesAndNewlines)` | AppState, CopilotPanel, InputBar | `String+Trimmed.swift` extension |
| Date/time formatting | ArticleWorkspaceView, ArticlesDashboardView | Shared `DateFormatting` utility |
| Capability chip styling | InputBar, ArticlesDashboardView | Shared `CapabilityChipStyle` |

---

## PHASE 4: DOCUMENTATION UPDATE (Agent: doc-auditor)

After all code changes complete:
1. Verify `README.md` reflects current architecture
2. Update `docs/dev-maps/` if any reference moved/deleted files
3. Ensure `GEMINI.md` is still accurate
4. Check that `docs/writevibe-roadmap.md` priorities match Phase 2–3 refactoring work done
5. Verify no stale TODO/FIXME comments remain in changed files

---

## EXECUTION ORDER

```
Phase 0 (Dead Code)     → swift agent     → build verify
Phase 1 (Security)      → backend agent   → qa agent (tests)
Phase 2.1–2.3 (UI)      → frontend agent  → build verify
Phase 2.4–2.6 (Services)→ backend agent   → build verify
Phase 3 (Medium fixes)  → backend + swift → build verify
Phase 4 (Docs)          → doc-auditor     → final review
```

Each phase should be completed and verified before starting the next. Use `xcodebuild build` after every phase. Delegate test creation to the **qa** agent after Phases 1 and 2.
