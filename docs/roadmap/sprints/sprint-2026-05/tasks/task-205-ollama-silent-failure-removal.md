# Task Card: TASK-205 Ollama Silent Failure Removal

- Workstream: WS-202
- Owner: `@backend-developer`
- Priority: High
- Status: Complete

## Objective

Eliminate silent search failure in Ollama-only mode and ensure user-visible fallback guidance.

## Acceptance Criteria

- [x] Ollama-only failure path is deterministic and observable.
- [x] Recovery action text is surfaced to users.

## Dependencies

- Depends on TASK-204 taxonomy mapping.

## Implementation Notes

- Ollama-plus-search requests now fail with typed recovery guidance instead of hidden prompt-only fallback behavior.
- Recovery text is surfaced through the app generation path and runtime issue state, while valid OpenRouter-backed search flows remain intact.
- `WriteVibeError.localSearchUnavailable(reason:)` maps to `RuntimeIssue` with deterministic title, message, and next-step fields.
- Soft-warning path in `StreamingService.buildSearchAugmentation` ensures Ollama requests continue with prompt-only fallback rather than hard failure when no key is present.

## QA Closure Evidence — 2026-04-02

B-204 is Closed. `AppStateProviderRecoveryTests` executed in isolation:

```text
xcodebuild ... test -only-testing:WriteVibeTests/AppStateProviderRecoveryTests
** TEST SUCCEEDED **
Test case 'AppStateProviderRecoveryTests/testLocalSearchUnavailableRecoveryGuidanceRemainsActionable()' passed (0.000 seconds)
```

Additional evidence from gate pack run (same session):

- `StreamingServiceTests/testOllamaSearchMissingKeyAddsSoftWarningAndContinues` — PASS
- `StreamingServiceTests/testOllamaSearchProviderFailureAddsSoftWarningAndContinues` — PASS

All acceptance criteria satisfied. No code gaps found. Task is Complete.
