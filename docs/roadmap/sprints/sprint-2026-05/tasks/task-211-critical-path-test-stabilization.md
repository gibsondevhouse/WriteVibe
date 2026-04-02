# Task Card: TASK-211 Critical-Path Test Stabilization

- Workstream: WS-204
- Owner: `@qa-lead`
- Priority: Medium
- Status: In Progress

## Objective

Stabilize flaky tests and apply quarantine policy with clear ownership and deadlines.

## Acceptance Criteria

- [ ] Flaky tests are either stabilized or quarantined with owner/date.
- [ ] Critical-path CI signal remains trustworthy for merge decisions.

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
| `WriteVibeTests/StreamingServiceTests` | Intermittent xcodebuild test-host instability during class-level or multi-suite execution; can present as aggregate 0.000s failures instead of deterministic assertion failures | Captured under B-204 scope; current repo memory notes class-level or multi-test runs can crash the test host, while focused reruns have also passed | `@backend-lead` | 2026-04-02 | 2026-04-05 EOD | Investigate root cause and decide stabilize vs quarantine recommendation |
| `WriteVibeTests/AppStateProviderRecoveryTests` | Unstable under class-level or multi-test execution; isolated reruns have passed even when broader execution blocked review closure | Referenced in B-204 and current QA notes as the remaining blocker for tasks that require provider recovery evidence | `@backend-lead` | 2026-04-02 | 2026-04-05 EOD | Reproduce against frozen workflow pack and prepare stabilize vs quarantine recommendation |
| Critical-path combined rerun containing `StreamingServiceTests` plus `AppStateProviderRecoveryTests` | Suite-combination instability risk remains open even when a fresh focused rerun passes; signal is intermittent rather than a confirmed permanent fail | Prior focused rerun passed on 2026-04-02, but sprint risk register still tracks B-204 as open because reproducibility is not yet reliable | `@qa-lead` | 2026-04-02 | 2026-04-05 EOD | Monitor invocation-level flake rate and document quarantine policy if combo execution remains unstable |

## Ownership Notes

- `@backend-lead` owns root-cause triage for the unstable backend suites tracked under B-204.
- `@qa-lead` owns the published register, quarantine recommendation, and checkpoint reporting cadence for TASK-211.

## Evidence Required For Closeout

- Flaky-test register with status, owner, and target resolution date.
- Quarantine policy log with explicit re-entry criteria.
- CI run links showing sustained non-flaky signal for critical path.
