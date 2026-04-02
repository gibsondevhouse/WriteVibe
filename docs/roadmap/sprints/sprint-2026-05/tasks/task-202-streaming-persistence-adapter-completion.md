# Task Card: TASK-202 Streaming Persistence Adapter Completion

- Workstream: WS-201
- Owner: `@backend-developer`
- Priority: High
- Status: Complete

## Objective

Complete migration to adapter-owned streaming persistence mutations and remove direct mutation paths.

## Acceptance Criteria

- [x] Persistence writes are adapter-owned on critical stream lifecycle paths.
- [x] Parity checks pass for success/cancel/error/retry paths.

## Dependencies

- Depends on TASK-201 boundary lock.

## Implementation Notes

- Adapter-owned assistant message creation, append, and finalize paths are now routed through `MessagePersistenceAdapter` and `SwiftDataMessagePersistenceAdapter`.
- `useStreamingPersistenceAdapter` feature flag is `true` in `AppConstants` — `SwiftDataMessagePersistenceAdapter` is the production path.
- `InMemoryPersistenceAdapter` serves as the rollback fallback when the flag is false.

## QA Closure Evidence — 2026-04-02

Gate pack executed: `StreamingServiceContractTests`, `StreamingServiceTests`, `ProviderRecoveryTests`, `ArticleEditOrchestratorTests`, `ChatRewriteDiffSupportTests`

### Result: ALL PASS

Path coverage confirmed:

| Path | Test | Result |
| ---- | ---- | ------ |
| Success (create → update → finalize `.succeeded`) | `StreamingServiceContractTests/testPlaceholderSuccessPath_CreateUpdateFinalize` | PASS |
| Cancellation (create → cancel → `.cancelled`) | `StreamingServiceContractTests/testPlaceholderInterruptionPath_CreateCancelRetry` | PASS |
| Idempotent finalize (finalize after finalize) | `StreamingServiceContractTests/testPlaceholderEdgeCase_FinalizeIdempotent` | PASS |
| Error path (provider failure → `.failed`) | `StreamingServiceTests/testAdapterLifecycleOnProviderFailure` | PASS |
| Retry path (cancel then new handle) | `StreamingServiceContractTests/testPlaceholderInterruptionPath_CreateCancelRetry` | PASS |
| Feature flag ON → SwiftDataAdapter | `StreamingServiceTests/testFeatureFlagOnUsesSwiftDataAdapter` | PASS |
| Feature flag OFF → InMemoryAdapter fallback | `StreamingServiceTests/testFeatureFlagOffUsesInMemoryAdapterFallback` | PASS |
| Contract violation: append after finalize | `StreamingServiceContractTests/testContractViolation_AppendAfterFinalize` | PASS |
| Contract violation: invalid handle | `StreamingServiceContractTests/testContractViolation_InvalidHandle` | PASS |
| Concurrent independent lifecycles | `StreamingServiceContractTests/testConcurrentHandles_IndependentLifecycles` | PASS |

All prior blocking conditions (TASK-203, B-204) are Closed. No code gaps found.
