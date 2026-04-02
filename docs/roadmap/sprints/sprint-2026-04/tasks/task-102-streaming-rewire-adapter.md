# TASK-102 - Rewire StreamingService to Adapter

## Owner

`@backend-developer`

## Status

Complete (2026-04-02)

## Description

Use the new persistence adapter internally in streaming paths behind a feature flag and retain parity behavior.

## Acceptance Criteria

- [x] Success, cancel, and error lifecycle paths preserve expected outcomes.
- [x] Feature-flag rollback path is validated.
- [x] Contract tests from WS-105 pass.

## Prerequisites

- ✅ TASK-101 complete: MessagePersistenceAdapter protocol and implementations ready
- ✅ TASK-108 contract tests defined and ready to validate
- ✅ Feature flag added: `AppConstants.useStreamingPersistenceAdapter` (default: true, rollback fallback available)

## Implementation Notes (from @backend-lead)

See full handoff: `backend-lead-to-backend-developer-streaming-rewire.md`

**Quick Summary:**

1. StreamingService already uses messagePersistenceAdapter pattern
2. Wire feature flag to select adapter in StreamingService.init()
3. Run TASK-108 contract tests with both flag states
4. Both should pass identically (parity validation)

**Expected Effort:** Low (adapter already in place, just feature flag wiring)

## Execution Notes

- 2026-04-02: TASK-101 complete; backend-lead handoff issued; TASK-102 execution authorized.
- 2026-04-02: `StreamingService` rewired to explicit flag-driven adapter selection with adapter path enabled by default and in-memory rollback fallback.
- 2026-04-02: Added focused tests for flag-off fallback and flag-on persistence behavior in `StreamingServiceTests`.
- 2026-04-02: Validation run passed:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/StreamingServiceContractTests`
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-15-22--0400.xcresult`
  - Summary: `Passed, 15/15 tests, 0 failed`.

