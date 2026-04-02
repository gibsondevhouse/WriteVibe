# QA Gates

## Entry Checklist

- [x] Workstreams are decomposed with explicit owner and status.
- [x] Acceptance criteria are defined in requirements and architecture artifacts.
- [x] Risk register and blockers include escalation owner.
- [x] Feature-flag rollout strategy is documented for high-risk refactors.

## In-Sprint Checks

- [x] Daily impacted tests pass before task status moves to Review.
- [x] Mid-sprint full suite run completed and logged by `@qa-lead`.
- [x] Mid-sprint full suite gate passes with no unresolved test failures.
- [x] Contract drift check completed for streaming, article orchestration, and provider fallback behavior.
- [x] Blocker SLA audit completed and escalations posted.

## Exit Checklist

- [x] Sprint goals mapped to measurable outcomes.
- [x] WS-101 and WS-102 parity checks pass on success, cancellation, and error paths.
- [x] WS-103 provider reliability fixes validated against known issue list.
- [x] WS-104 conversion stability checks pass and baseline measurements are recorded.
- [x] WS-105 new critical-path tests pass and are non-flaky.
- [x] No unresolved P0 or P1 defects in sprint scope.
- [x] Handoff records exist for each owner transition.

## Critical Test Matrix

| Area | Must-Pass Scenarios | Owner |
| --- | --- | --- |
| Streaming and persistence | Placeholder create/update/finalize, cancel/retry consistency | `@backend-tester` |
| Article edit orchestration | Replace/insert/delete validation, round-trip integrity | `@frontend-tester` |
| Provider reliability | Anthropic header/version behavior, Ollama cancel/search fallback | `@backend-tester` |
| Risk operations | Blocker SLA breach detection and escalation | `@qa-lead` |

## QA Decision

- Status: Go for sprint exit (with CTO-approved sprint-scoped coverage exception)
- Owner: `@qa-lead`
- Notes:
  - Entry gate passed on 2026-04-02.
  - Blocker audit completed and blockers B-001/B-002/B-003 closed on 2026-04-02.
  - TASK-110 completed: scored risk register and escalation SLA review validated on 2026-04-02.
  - WS-106 marked complete and QA closure signoff issued to CTO on 2026-04-02.
  - TASK-108 contract test suite landed and is passing on 2026-04-02.
  - Mid-sprint checkpoint executed on 2026-04-02 with live evidence (full suite + focused critical-path suites).
  - Backend blocker burn-down revalidation completed at 14:56 ET on 2026-04-02: full suite passed, focused critical-path suites passed.
  - CTO decision lock (15:20 ET): coverage blocker B-007 closed with sprint-scoped exception and mandatory carry-forward quality uplift in sprint-2026-05 WS-204/WS-205.
  - Final exit-readiness revalidation completed at 15:21 ET on 2026-04-02: fresh full suite and focused critical-path reruns both passed.

## Mid-Sprint Checkpoint and Re-run Evidence (2026-04-02)

- Initial checkpoint (earlier 2026-04-02):
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test`
  - Result: Failed (exit 65) with 37 unit failures and one repeatable streaming interruption failure in focused reruns.
- Fresh full-suite rerun after backend burn-down (14:56 ET):
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test`
  - Result: Passed.
  - `xcrun xcresulttool get test-results summary --path .../Test-WriteVibe-2026.04.02_14-56-05--0400.xcresult`
  - Result summary: 71/71 passed, 0 failed.
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_14-56-05--0400.xcresult`
- Focused critical-path rerun (14:56 ET):
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceContractTests -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/ProviderRecoveryTests -only-testing:WriteVibeTests/ArticleEditOrchestratorTests -only-testing:WriteVibeTests/AppStateProviderRecoveryTests`
  - Result: Passed.
  - `xcrun xcresulttool get test-results summary --path .../Test-WriteVibe-2026.04.02_14-56-46--0400.xcresult`
  - Result summary: 34/34 passed, 0 failed.
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_14-56-46--0400.xcresult`
- Coverage evidence from fresh full-suite rerun:
  - `xcrun xccov view --report --json .../Test-WriteVibe-2026.04.02_14-56-05--0400.xcresult | jq '{overallLineCoverage: .lineCoverage, coveredLines: .coveredLines, executableLines: .executableLines, targets: [.targets[] | {name, lineCoverage}]}'`
  - Result: overall 26.76% (3744/13991), app target 18.32% (2293/12519), below 80% threshold.

## Final Exit Revalidation Evidence (2026-04-02 15:21 ET)

- Fresh full-suite rerun:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test`
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-21-13--0400.xcresult`
  - Summary command: `xcrun xcresulttool get test-results summary --path /Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-21-13--0400.xcresult`
  - Outcome: Passed, 76/76 total tests, 0 failed, 0 skipped.
- Fresh focused critical-path rerun:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceContractTests -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/ProviderRecoveryTests -only-testing:WriteVibeTests/ArticleEditOrchestratorTests -only-testing:WriteVibeTests/AppStateProviderRecoveryTests -only-testing:WriteVibeTests/DocumentSyncBaselineTests`
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-21-58--0400.xcresult`
  - Summary command: `xcrun xcresulttool get test-results summary --path /Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-21-58--0400.xcresult`
  - Outcome: Passed, 39/39 total tests, 0 failed, 0 skipped.
- Fresh coverage evidence (full-suite rerun):
  - `xcrun xccov view --report --json /Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_15-21-13--0400.xcresult | jq '{overallLineCoverage: .lineCoverage, coveredLines: .coveredLines, executableLines: .executableLines, targets: [.targets[] | {name, lineCoverage, coveredLines, executableLines}]}'`
  - Result: overall 29.29% (4138/14129), app target 20.37% (2551/12526), still below 80% default threshold and covered by CTO-approved sprint-scoped exception (B-007 closed).

## Acceptance Criteria Validation (sprint-2026-04-hotspot-roi-proposal)

- [x] Article edit orchestration boundary exists and no observed regressions in orchestrator-focused suite.
- [x] Streaming interruption parity validated in focused and full-suite reruns (`testPlaceholderInterruptionPath_CreateCancelRetry` passing).
- [x] Document sync baseline capture complete (TASK-107): focused `DocumentSyncBaselineTests` suite passed 3/3 on 2026-04-02.
- [x] Anthropic/Ollama reliability behavior validated in focused provider recovery suites.
- [x] Known architecture hotspot decisions are documented (Ollama cancel/search behavior, Anthropic version handling scope, InputBar ownership clarified).
- [x] Automated workflow coverage exists for article edit request/apply and streaming interruption scenario.

## Pending Items Before Exit Gate

- Coverage uplift implementation and stricter gate metric adoption are carry-forward obligations for sprint-2026-05 WS-204/WS-205.
