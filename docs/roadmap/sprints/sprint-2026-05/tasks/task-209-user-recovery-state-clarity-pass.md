# Task Card: TASK-209 User Recovery State Clarity Pass

- Workstream: WS-203
- Owner: `@frontend-lead`
- Priority: High
- Status: Complete

## Objective

Replace ambiguous warning text with explicit user recovery actions on critical failure paths.

## Acceptance Criteria

- [x] In-scope failure states provide clear next-step guidance.
- [x] Product and QA review confirms no critical clarity gaps.

## Dependencies

- Depends on provider failure mapping in TASK-204.

## Implementation Notes

- Structured recovery issues now back the top-level runtime banner so chat/provider failures show both the problem and the next recommended action.
- Article AI edit failures now render the same explicit next-step guidance instead of a single ambiguous warning string.
- Chat-adjacent setup warnings were tightened for missing Ollama model selection, incomplete provider configuration, and near-full context guidance.
- B-204 is now Closed. `AppStateProviderRecoveryTests` passes in isolation (TASK-205 confirmed).

## Product and QA Sign-Off (2026-04-02 — @frontend-lead)

Manual UI-path review conducted across all four recovery copy surfaces. TASK-204 provider failure taxonomy used as reference throughout.

### Surface 1: App-level runtime banner (`ContentView.swift`)

Renders three text elements: `issue.title` (bold), `issue.message`, and `"Next step: \(issue.nextStep)"`. Banner is pinned at top and dismissible. All `RuntimeIssue` cases carry a non-empty `nextStep`.

Cases reviewed against TASK-204 taxonomy:

| Failure class | Title | Message | Next step | Status |
| --- | --- | --- | --- | --- |
| modelContextUnavailable | "Workspace not ready" | Still attaching data store | Wait + relaunch if persistent | ✅ Clear |
| dataMigrationFailed | "Local data needs attention" | Migration detail included | Restart + inspect logs | ✅ Clear |
| appleIntelligenceUnavailable | "Apple Intelligence unavailable" | Cannot run in current config | Switch model + resend | ✅ Clear |
| ollamaModelSelectionRequired | "Select an Ollama model" | No model selected | Open Settings + choose/install + resend | ✅ Clear |
| modelConfigurationIncomplete | "Model setup incomplete" | No runnable provider config | Switch model or finish Settings setup | ✅ Clear |
| missingAPIKey (OpenRouter) | "OpenRouter API key required" | Key not configured | Settings > Cloud API Keys + retry | ✅ Clear |
| missingAPIKey (Anthropic) | "Anthropic API key required" | Direct key not configured | Add OpenRouter key or switch to Ollama | ✅ Clear |
| network error | "Connection problem" | Provider unreachable + detail | Check network + retry + switch providers | ✅ Clear |
| apiError 401/403 | "{Provider} request failed" | Authentication failure + HTTP code | Check API key in Settings + retry | ✅ Clear |
| apiError 404 | "{Provider} request failed" | Model/endpoint not found | Switch model + retry | ✅ Clear |
| apiError 429 | "{Provider} request failed" | Rate limiting | Wait + retry or switch provider | ✅ Clear |
| apiError 5xx | "{Provider} request failed" | Provider unavailable | Retry shortly or switch | ✅ Clear |
| generationFailed | "Response failed" | Provider stopped early + reason | Retry + switch if repeats | ✅ Clear |
| decodingFailed | "Response could not be read" | Decode failure + context | Retry once + switch + capture for QA | ✅ Clear |
| persistenceFailed | "Save failed" | Operation detail | Retry + restart if repeats | ✅ Clear |
| cancelled | "Request stopped" | Cancelled before completion | Resend when ready | ✅ Clear |

**No gaps found.** All TASK-204 classified failure classes have corresponding explicit recovery copy.

### Surface 2: Article AI edit error banner (`ArticleEditorView.swift`)

Renders via `errorBanner(_ issue: RuntimeIssue)`. Structure: icon + `issue.title` (bold) + `issue.message` + `"Next step: \(issue.nextStep)"` + Dismiss button. Triggered by `WriteVibeError.runtimeIssue` catch on `requestAIEdits`.

- `articleEditFailure`: "AI edit unavailable" + detail + "Retry AI Edit. If it fails again, switch models or review your provider settings." ✅
- Network/auth/apiError failures surface the same structured `runtimeIssue` from `WriteVibeError` ✅
- Dismiss is always present ✅

**No gaps found.**

### Surface 3: Chat context / token bar (`TokenUsageBar.swift`)

- ≥95% full: "Context nearly full. Start a new chat before sending another long prompt." ✅
- ≥98% full: "Context full. Start a new chat, then resend this request there." ✅
- Send button is disabled at ≥98% so there is no ambiguous state ✅

**No gaps found.**

### Surface 4: `CopilotPanel.swift` + runtime issue routing

The `CopilotPanel` does not surface a duplicate recovery banner. All issues from AI generation calls route through `AppState.runtimeIssue`, which is rendered by the `ContentView` top-level overlay. This is the correct single-responsibility pattern — no duplication, no missed surface.

### QA Sign-Off

- All in-scope failure states from TASK-204 taxonomy have explicit problem statement + next-step action ✅
- No critical clarity gaps found across all four surfaces ✅
- Recovery language is consistent with TASK-204 accepted action taxonomy ✅
- Provider-specific recovery steps (OpenRouter, Anthropic, Ollama) are all addressed ✅

**QA sign-off: CLEAN. TASK-209 is Complete.**
