# TASK-106 - Fix Ollama Cancel and Search Fallback

## Owner

`@backend-lead`

## Status

Complete (validated 2026-04-02)

## Description

Resolve Ollama cancel behavior and implement soft-warning fallback behavior for Ollama-only search failure.

## Acceptance Criteria

- [x] Cancel behavior consistently stops in-flight Ollama operations.
- [x] Ollama-only search failure surfaces a soft warning with fallback behavior.
- [x] Silent-fail path is removed from known issue list.
- [x] QA smoke validation scenarios are documented for handoff.

## Prerequisites

- ✅ TASK-101 complete: Streaming architecture stable
- ✅ StreamingService contract tests ready to validate

## Implementation Scope (see detailed plan)

See: `backend-lead-task-106-ollama-execution-plan.md` for full technical analysis and implementation steps.

### Issue 1: Cancel Safety

- Problem: URLSession bytes stream may not terminate cleanly on Task cancellation
- Solution: Add withTaskCancellationHandler to ensure network cleanup
- Files: `WriteVibe/Services/AI/OllamaService.swift`

### Issue 2: Search Fallback

- Problem: Ollama-only search failures threw typed errors before generation started.
- Solution: Add soft warning message to prompt and continue generation in degraded mode.
- Files: `WriteVibe/Services/StreamingService.swift` (`buildSearchAugmentation` method)

## Execution Notes

- 2026-04-02: TASK-101 locked; TASK-106 ready for execution start.
- 2026-04-02: Detailed execution plan created in backend-lead-task-106-ollama-execution-plan.md
- 2026-04-02: `StreamingService.buildSearchAugmentation(...)` updated to soft-warn and continue for Ollama-only search degradation paths (missing API key, provider failure, empty findings, missing query).
- 2026-04-02: Cancel path remains guarded by `Task.checkCancellation()` in `OllamaService` stream loops and is covered by focused cancellation lifecycle test evidence.
- 2026-04-02: Focused smoke test command passed:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceTests/testAdapterLifecycleOnCancellation -only-testing:WriteVibeTests/StreamingServiceTests/testOllamaSearchMissingKeyAddsSoftWarningAndContinues -only-testing:WriteVibeTests/StreamingServiceTests/testOllamaSearchProviderFailureAddsSoftWarningAndContinues -only-testing:WriteVibeTests/AppStateProviderRecoveryTests/testLocalSearchUnavailableRecoveryGuidanceRemainsActionable`
  - Outcome: all selected TASK-106 tests passed.
- 2026-04-02: Closeout reconfirmed with WS-103 focused reliability rerun; TASK-106 behavior remains aligned to decision lock (soft warning + fallback).
