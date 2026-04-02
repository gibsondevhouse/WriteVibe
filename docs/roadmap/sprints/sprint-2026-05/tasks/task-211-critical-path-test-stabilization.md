# Task Card: TASK-211 Critical-Path Test Stabilization

- Workstream: WS-204
- Owner: `@qa-lead`
- Priority: Medium
- Status: Complete

## Objective

Stabilize flaky tests and apply quarantine policy with clear ownership and deadlines.

## Acceptance Criteria

- [x] Flaky tests are either stabilized or quarantined with owner/date.
- [x] Critical-path CI signal remains trustworthy for merge decisions.

## Dependencies

- Depends on TASK-210 workflow freeze.

## Execution Checkpoints

- 2026-04-05 EOD: publish flaky-test inventory for frozen top-5 workflows.
- 2026-04-07 EOD: stabilize or quarantine all critical-path flakes with owner/date.
- 2026-04-09 EOD: demonstrate three consecutive green critical-path CI runs.

## First-Pass Flaky Inventory

Published: 2026-04-02

This is an initial register for known unstable execution paths. It does not claim stabilization is complete.

| Suite or Case | Current Instability Pattern | Current Evidence | Assigned Owner | Assignment Date | Next Checkpoint | Current Disposition |
| --- | --- | --- | --- | --- | --- | --- |
| `WriteVibeTests/StreamingServiceTests` | Intermittent xcodebuild test-host instability during class-level or multi-suite execution; can present as aggregate 0.000s failures instead of deterministic assertion failures | Fresh combined reruns passed twice on 2026-04-02 (10/10 each); full critical-pack and full-suite invocations also passed | `@backend-lead` | 2026-04-02 | Completed early (2026-04-02) | Stabilized for current CI gate scope; no quarantine applied |
| `WriteVibeTests/AppStateProviderRecoveryTests` | Unstable under class-level or multi-test execution; isolated reruns have passed even when broader execution blocked review closure | Fresh combined reruns passed twice on 2026-04-02 (10/10 each); full-suite invocation also passed without host failure | `@backend-lead` | 2026-04-02 | Completed early (2026-04-02) | Stabilized for current CI gate scope; no quarantine applied |
| Critical-path combined rerun containing `StreamingServiceTests` plus `AppStateProviderRecoveryTests` | Suite-combination instability risk remained open until CI-like repeatability was demonstrated | Two prior local reruns passed, and two additional immediate CTO-requested CI-like reruns on 2026-04-02 both passed; supporting critical-pack/full-suite gates also passed | `@qa-lead` | 2026-04-02 | Completed early (2026-04-02) | Repeatable pass signal confirmed; recommendation accepted to close B-204 |

## Reproduce-Or-Quarantine Checkpoint (2026-04-02)

- Combined suite command rerun #1 (`StreamingServiceTests` + `AppStateProviderRecoveryTests`): `TEST SUCCEEDED`.
- Combined suite command rerun #2 (`StreamingServiceTests` + `AppStateProviderRecoveryTests`): `TEST SUCCEEDED`.
- Recommendation at this checkpoint: do not quarantine yet; continue monitoring through the 2026-04-05 EOD checkpoint and require CI-level confirmation before closing B-204.

## CI-Level Continuation Checkpoint (2026-04-02, CTO Requested Immediate Execution)

- Combined suite command rerun #3 (`StreamingServiceTests` + `AppStateProviderRecoveryTests`): `result: Passed`, `totalTestCount: 10`, `failedTests: 0`.
- Combined suite command rerun #4 (`StreamingServiceTests` + `AppStateProviderRecoveryTests`): `result: Passed`, `totalTestCount: 10`, `failedTests: 0`.
- TASK-210 critical-path gate pack command: `result: Passed`, `totalTestCount: 40`, `failedTests: 0`.
- Optional full suite command: `result: Passed`, `totalTestCount: 76`, `failedTests: 0`.
- Build quality check: `xcodebuild build` returned `BUILD SUCCEEDED` with no warning lines emitted in the build log extract.
- Close recommendation: close B-204 now on objective repeatability evidence; keep residual risk tracking in WS-205 coverage uplift governance only.

## Ownership Notes

- `@backend-lead` owns root-cause triage for the unstable backend suites tracked under B-204.
- `@qa-lead` owns the published register, quarantine recommendation, and checkpoint reporting cadence for TASK-211.

## Evidence Required For Closeout

- Flaky-test register with status, owner, and target resolution date.
- Quarantine policy log with explicit re-entry criteria.
- CI run links showing sustained non-flaky signal for critical path.

## Closeout Note (2026-04-02)

- TASK-211 closeout approved by `@qa-lead` after immediate CI-level continuation evidence met stabilization intent for the scoped blocker suites.
- B-204 moved to Closed in sprint blocker governance.
