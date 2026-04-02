# QA Gates

## Entry Checklist

- [x] Workstreams are decomposed with explicit owner and status.
- [x] Acceptance criteria are defined in requirements and architecture artifacts.
- [x] Risk register and blockers include escalation owner.
- [x] Feature-flag rollout strategy is documented for high-risk refactors.

## In-Sprint Checks

- [x] Daily impacted tests pass before task status moves to Review.
- [x] Mid-sprint full suite run completed and logged by `@qa-lead`.
- [ ] Mid-sprint full suite gate passes with no unresolved failures.
- [x] Contract drift check completed for streaming, article orchestration, and provider fallback behavior.
- [x] Blocker SLA audit completed and escalations posted.

## Exit Checklist

- [ ] Sprint goals mapped to measurable outcomes.
- [ ] WS-101 and WS-102 parity checks pass on success, cancellation, and error paths.
- [ ] WS-103 provider reliability fixes validated against known issue list.
- [ ] WS-104 conversion stability checks pass and baseline measurements are recorded.
- [ ] WS-105 new critical-path tests pass and are non-flaky.
- [ ] No unresolved P0 or P1 defects in sprint scope.
- [ ] Handoff records exist for each owner transition.

## Critical Test Matrix

| Area | Must-Pass Scenarios | Owner |
| --- | --- | --- |
| Streaming and persistence | Placeholder create/update/finalize, cancel/retry consistency | `@backend-tester` |
| Article edit orchestration | Replace/insert/delete validation, round-trip integrity | `@frontend-tester` |
| Provider reliability | Anthropic header/version behavior, Ollama cancel/search fallback | `@backend-tester` |
| Risk operations | Blocker SLA breach detection and escalation | `@qa-lead` |

## QA Decision

- Status: Go with conditions (continue sprint execution), No-go for sprint exit
- Owner: `@qa-lead`
- Notes:
  - Entry gate passed on 2026-04-02.
  - Blocker audit completed and blockers B-001/B-002/B-003 closed on 2026-04-02.
  - TASK-110 completed: scored risk register and escalation SLA review validated on 2026-04-02.
  - WS-106 marked complete and QA closure signoff issued to CTO on 2026-04-02.
  - TASK-108 contract test suite landed and is passing on 2026-04-02.
  - Mid-sprint checkpoint executed on 2026-04-02 with live evidence (full suite + focused compensating suites).

## Mid-Sprint Checkpoint Evidence (2026-04-02)

- Full-suite command:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test`
  - Result: Failed (exit code 65).
  - Observed outcome: UI tests passed (4/4), unit phase reported 37 failures, many at 0.000s execution time, indicating a broad unit-test instability state during aggregate run.
  - XCResult: `/Users/gibdevlite/Library/Developer/Xcode/DerivedData/WriteVibe-ebnlpmdwijaicbeduwogawjutxjs/Logs/Test/Test-WriteVibe-2026.04.02_14-22-36--0400.xcresult`
- Coverage evidence from full-suite xcresult:
  - `xcrun xccov view --report ...14-22-36--0400.xcresult`
  - Result: `WriteVibe.app` 15.78% (1975/12519), below 80% threshold.
- Compensating focused suites (nearest reliable equivalent while full-suite gate is red):
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/ArticleEditOrchestratorTests -only-testing:WriteVibeTests/ChatRewriteDiffSupportTests -only-testing:WriteVibeTests/StreamingServiceContractTests -only-testing:WriteVibeTests/ProviderRecoveryTests -only-testing:WriteVibeTests/AppStateProviderRecoveryTests`
  - Result: Failed (exit code 65) due to one unique unresolved test: `StreamingServiceContractTests/testPlaceholderInterruptionPath_CreateCancelRetry` (duplicate failure lines present in output).
  - Passing compensating areas: article orchestration workflow tests, chat rewrite diff tests, provider recovery tests, app-state provider recovery test.
  - Focused-run coverage snapshot: `WriteVibe.app` 14.87% (1862/12519).

## Acceptance Criteria Validation (sprint-2026-04-hotspot-roi-proposal)

- [x] Article edit orchestration boundary exists and no observed regressions in orchestrator-focused suite.
- [ ] Streaming interruption parity remains unresolved (contract interruption test failing).
- [ ] Document sync baseline capture remains in progress (TASK-107 still in progress).
- [x] Anthropic/Ollama reliability behavior validated in focused provider recovery suites.
- [x] Known architecture hotspot decisions are documented (Ollama cancel/search behavior, Anthropic version handling scope, InputBar ownership clarified).
- [x] Automated workflow coverage exists for article edit request/apply and streaming interruption scenario.

## Pending Items Before Exit Gate

- Resolve `StreamingServiceContractTests/testPlaceholderInterruptionPath_CreateCancelRetry` and rerun full suite.
- Restore full-suite stability so aggregate unit execution no longer cascades into broad 0.000s failures.
- Raise effective tested coverage to sprint threshold or secure explicit leadership exception.
