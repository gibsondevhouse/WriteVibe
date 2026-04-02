# Task Card: TASK-212 Launch Blocker Operations and Sign-Off

- Workstream: WS-205
- Owner: `@cto`
- Priority: High
- Status: In Progress

## Objective

Run blocker register operations, waiver policy, and weekly readiness snapshots for v1 launch confidence.

## Acceptance Criteria

- [ ] Blocker register is current with severity, owner, and verification evidence.
- [ ] High/medium blockers are closed or explicitly waived with rationale.
- [ ] Closeout recommendation is co-reviewed by `@qa-lead`.

## Dependencies

- Depends on workstream status and QA evidence from WS-201 through WS-204.

## Execution Checkpoints

- Twice weekly: blocker triage session with updated severity/owner/ETA.
- Weekly Friday EOD: readiness snapshot published with go/no-go trend.
- Before exit gate: waiver register reviewed and co-signed with `@qa-lead`.

## Evidence Required For Closeout

- Current blocker register with verification artifacts for each high/medium blocker.
- Waiver log entries with rationale, scope, expiry, and approver.
- Final readiness memo co-reviewed by `@qa-lead` and `@cto`.
