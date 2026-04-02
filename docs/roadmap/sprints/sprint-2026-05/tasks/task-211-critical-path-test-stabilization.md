# Task Card: TASK-211 Critical-Path Test Stabilization

- Workstream: WS-204
- Owner: `@qa-lead`
- Priority: Medium
- Status: Planned

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

## Evidence Required For Closeout

- Flaky-test register with status, owner, and target resolution date.
- Quarantine policy log with explicit re-entry criteria.
- CI run links showing sustained non-flaky signal for critical path.
