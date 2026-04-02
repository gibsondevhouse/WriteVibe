# Task Card: TASK-204 Provider Failure Taxonomy

- Workstream: WS-202
- Owner: `@backend-lead`
- Priority: High
- Status: Complete

## Objective

Define typed provider failure classes and map each to a deterministic handling and recovery policy.

## Acceptance Criteria

- [x] OpenRouter/Anthropic/Ollama failure classes are documented.
- [x] Each class maps to user state and recovery action.

## Dependencies

- Requires architecture guidance from `@architect`.

---

## Taxonomy — 2026-04-02

All failure classes are expressed as `WriteVibeError` enum cases (defined in `WriteVibe/Models/AppError.swift`).
Each case maps to a `RuntimeIssue` via `.runtimeIssue` and surfaces to the user through the app generation path.
Recovery steps are drawn directly from `providerRecoveryStep(provider:statusCode:)` and `missingAPIKeyNextStep(provider:)`.

### Cross-Provider Failure Classes

These apply regardless of which AI provider is active.

| Class | `WriteVibeError` case | User State | Recovery Action |
| ----- | --------------------- | ---------- | --------------- |
| **User cancellation** | `.cancelled` | Message partial or empty; generation stopped | Resend the request when ready |
| **Network unreachable** | `.network(underlying:)` | Provider not reached; no reply started | Check network connection, retry, or switch providers |
| **Response decode failure** | `.decodingFailed(context:)` | Reply could not be parsed; message may be empty | Retry once; switch models if persistent |
| **Generation stopped early** | `.generationFailed(reason:)` | Provider sent partial or empty response | Retry the request; switch models if it repeats |
| **Persistence save failure** | `.persistenceFailed(operation:)` | Message may not be saved after generation | Retry action; restart app if persists |

---

### OpenRouter Failure Classes

Source: `WriteVibe/Services/AI/OpenRouterService.swift`

| Class | `WriteVibeError` case | HTTP | User State | Recovery Action |
| ----- | --------------------- | ---- | ---------- | --------------- |
| **Missing API key** | `.missingAPIKey(provider: "OpenRouter")` | — | All cloud routes blocked; send fails before request | Settings > Cloud API Keys → add OpenRouter key |
| **Authentication failure** | `.apiError(provider: "OpenRouter", statusCode: 401/403, ...)` | 401, 403 | Request rejected immediately | Check API key in Settings > Cloud API Keys, then retry |
| **Model not found** | `.apiError(provider: "OpenRouter", statusCode: 404, ...)` | 404 | Model unavailable; no reply | Switch to another model and retry |
| **Request conflict/timeout** | `.apiError(provider: "OpenRouter", statusCode: 408/409, ...)` | 408, 409 | Request did not complete | Wait a moment and retry, or switch model |
| **Rate limited** | `.apiError(provider: "OpenRouter", statusCode: 429, ...)` | 429 | Requests throttled by provider | Wait and retry, or switch model |
| **Server error** | `.apiError(provider: "OpenRouter", statusCode: 500–599, ...)` | 5xx | Provider temporarily down | Retry shortly or switch model while service recovers |
| **Bad request** | `.apiError(provider: "OpenRouter", statusCode: 400, ...)` | 400 | Request payload rejected | Retry once; switch models if persistent |

---

### Anthropic Failure Classes

Source: `WriteVibe/Services/AI/AnthropicService.swift`; error mapper: `AnthropicService.mapAPIError(statusCode:body:)`

| Class | `WriteVibeError` case | HTTP | User State | Recovery Action |
| ----- | --------------------- | ---- | ---------- | --------------- |
| **Missing API key** | `.missingAPIKey(provider: "Anthropic")` | — | Direct Claude route unavailable | Add OpenRouter key in Settings > Cloud API Keys to use Claude via OpenRouter; retry or switch to Ollama |
| **Authentication failure** | `.apiError(provider: "Anthropic", statusCode: 401/403, ...)` | 401, 403 | Request rejected; no reply | Add OpenRouter key in Settings > Cloud API Keys to route Claude through OpenRouter |
| **Bad request** | `.apiError(provider: "Anthropic", statusCode: 400, ...)` | 400 | Request rejected by Anthropic | Retry; switch models if persistent |
| **Model not found** | `.apiError(provider: "Anthropic", statusCode: 404, ...)` | 404 | Model or endpoint unavailable | Switch to another model |
| **Rate limited** | `.apiError(provider: "Anthropic", statusCode: 429, ...)` | 429 | Throttled by Anthropic | Wait and retry, or switch model |
| **Server error** | `.apiError(provider: "Anthropic", statusCode: 500–599, ...)` | 5xx | Anthropic temporarily down | Retry shortly or switch model |
| **SSE parse failure** | `.decodingFailed(context:)` | — | Reply stream unreadable | Retry; if same response keeps failing, switch models and capture sample for QA |

---

### Ollama Failure Classes

Source: `WriteVibe/Services/AI/OllamaService.swift`; search fallback: `WriteVibe/Services/StreamingService.swift`

| Class | `WriteVibeError` case | User State | Recovery Action |
| ----- | --------------------- | ---------- | --------------- |
| **Server not running** | `.modelUnavailable(name: "Ollama server")` / `.network(underlying:)` | No response from localhost:11434; send fails | Start the Ollama desktop app, then retry |
| **No model selected** | `RuntimeIssue.ollamaModelSelectionRequired()` (AppError surface) | Ollama selected but no installed model chosen | Open Settings, choose or install an Ollama model, then resend |
| **Model name invalid** | `.modelUnavailable(name: "Invalid model name")` | Model name fails validation; request not sent | Use a valid Ollama model identifier from Settings |
| **Model not installed** | `.modelUnavailable(name:)` from `installedModels()` check | Models list unavailable or model missing | Open Settings, install the required model |
| **Search without API key** | `.localSearchUnavailable(reason: "no OpenRouter API key is configured")` | Search requested in Ollama-only mode; soft fallback applied; generation continues | Turn off Search and resend, or add OpenRouter key in Settings > Cloud API Keys |
| **Search provider failure** | `.localSearchUnavailable(reason: "<provider> search failed with HTTP <N>")` | Search layer failed; soft fallback applied; generation continues | Turn off Search and resend, or add OpenRouter key; captured as soft warning |
| **Search network failure** | `.localSearchUnavailable(reason: "the web search layer could not be reached (...)")` | Search unreachable; soft fallback applied; generation continues | Check network; turn off Search or switch to a cloud model for search |
| **Model download failure** | `.apiError(provider: "Ollama", statusCode: N, message: "Pull failed for <name>")` | Pull stream terminated with error | Retry pull in Settings; choose a different model if download keeps failing |
| **NDJSON parse failure** | `.decodingFailed(context: "Ollama installed models response")` | Model list unreadable | Retry; check Ollama server integrity |

---

## Notes

- All Ollama search failures use the **soft-warning path**: the generation continues with a prompt-level note rather than throwing a hard error. This is the closure confirmed by TASK-205.
- The `RuntimeIssue` struct (title, message, nextStep) is the user-facing surface for all error classes. No failure class silently swallows state — each produces either a `RuntimeIssue` or a soft-warning augmentation in the prompt.
- `MessagePersistenceError` (adapter-layer errors: `missingConversation`, `placeholderCreationFailed`, `invalidHandle`, `contextSaveFailed`) are internal to the streaming persistence boundary and do not escape to users directly; they surface as `persistenceFailed` or are handled in `StreamingService` error path.
