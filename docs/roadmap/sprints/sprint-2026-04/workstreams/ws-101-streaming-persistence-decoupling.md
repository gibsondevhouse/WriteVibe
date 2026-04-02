# WS-101 - Streaming and Persistence Decoupling

## Owner

`@backend-lead`

## Scope

- Introduce `MessagePersistence` protocol and default conversation adapter.
- Rewire streaming internals to use adapter behind feature flag.
- Preserve current caller-facing behavior and signatures this sprint.

## Out of Scope

- SwiftData schema migrations.
- New provider features.

## Acceptance Criteria

- [x] Streaming success/cancel/error paths preserve placeholder lifecycle behavior.
- [x] No duplicate assistant messages are introduced.
- [x] Adapter contract tests pass.
- [x] Feature flag rollback path is documented and verified.

## Dependencies

- Architecture service contract: `docs/architecture/service-contracts/reliability-velocity-core-services.md`
- QA validation from WS-105.

## Next Owner and Move

- Next Owner: `@backend-developer`
- Next Move: Execute TASK-102 after TASK-101 contract merge.

## Validation Evidence (2026-04-02)

- `StreamingService` now resolves persistence path behind `useStreamingPersistenceAdapter` with default adapter path enabled and in-memory rollback fallback.
- Success/cancel/failure adapter lifecycle remained green via focused suite:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/StreamingServiceContractTests`
- Result artifact:
  - `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-15-22--0400.xcresult`
- Summary:
  - `Passed, 15/15 tests, 0 failed.`
