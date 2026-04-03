# Task Board

| Task ID | Workstream | Task | Owner | Status | Priority |
| --- | --- | --- | --- | --- | --- |
| TASK-201 | WS-201 | Lock protocol boundaries for streaming/persistence and edit orchestration | `@architect` | Complete | High |
| TASK-202 | WS-201 | Complete adapter-only streaming persistence mutation path | `@backend-developer` | Complete | High |
| TASK-203 | WS-201 | Validate cancellation/retry/finalize parity via contract tests | `@backend-tester` | Complete | High |
| TASK-204 | WS-202 | Build provider failure taxonomy and typed mapping matrix | `@backend-lead` | Complete | High |
| TASK-205 | WS-202 | Eliminate Ollama-only silent search failure and map recovery UX | `@backend-developer` | Complete | High |
| TASK-206 | WS-202 | Update stale Anthropic API version/config defaults and error states | `@backend-developer` | Complete | Medium |
| TASK-207 | WS-203 | Move article apply flow fully behind orchestrator boundary | `@frontend-developer` | Complete | High |
| TASK-208 | WS-203 | Add chat diff view for rewrite actions using existing DiffEngine | `@frontend-developer` | Complete | Medium |
| TASK-209 | WS-203 | Replace generic warning strings with explicit user recovery states | `@frontend-lead` | Complete | High |
| TASK-210 | WS-204 | Define and enforce top-5 GA-critical workflow CI gate | `@qa-lead` | Complete | High |
| TASK-211 | WS-204 | Stabilize flaky critical-path tests and quarantine policy | `@qa-lead` | Complete | Medium |
| TASK-212 | WS-205 | Operate launch blocker register, waiver log, and weekly readiness review | `@cto` | Complete | High |

## Status Values

- Planned
- In Progress
- Blocked
- Review
- Complete

## WS-204/WS-205 Cadence (2026-04-02 Lock)

- TASK-210: top-5 GA workflow freeze completed on 2026-04-02 with multi-lead approval evidence.
- TASK-210 package is approved, frozen, and active; first enforcement run passed on 2026-04-02 (`TEST SUCCEEDED`).
- TASK-211: flaky stabilization checkpoint completed early on 2026-04-02 with CI-level confirmation evidence and B-204 closure.
- TASK-212: twice-weekly blocker triage plus weekly readiness snapshot, co-reviewed by `@qa-lead`.
- WS-205 coverage ladder is active (published 2026-04-02); B-205 is closed and now tracked through weekly coverage checkpoints.
- Coverage Week 1 checkpoint (due 2026-04-05 EOD) is complete and passing ahead of schedule: 22.48% app / 33.49% overall (2026-04-02 full-suite coverage run).
- Sprint closeout decision (2026-04-02): TASK-212 complete with co-reviewed CTO/QA recommendation; delivery scope is fully closed.

## Implementation Wave Close (2026-04-02)

- Wave: TASK-202, TASK-204, TASK-205, TASK-207, TASK-209 — all moved to Complete.
- WS-201/WS-202/WS-203 workstream status updated to Complete.
- Final gate pack: 40/40 PASS. Full suite: 76/76 PASS.
- QA sign-off: Ready for Delivery Sign-Off (`@qa-lead`, 2026-04-02).
- Coverage Week 1 ladder check is closed as pass (22.48% app / 33.49% overall).

## Sprint Closeout (2026-04-02)

- All sprint tasks TASK-201 through TASK-212 are Complete.
- Workstreams WS-201 through WS-205 are Complete.
- Delivery closeout approved by `@cto` with `@qa-lead` co-review.
- Remaining provider availability monitoring (B-201) continues as release operations governance, not open sprint implementation scope.

## Post-Close Intake Queue (Apple Structured Workflow)

These tasks are queued after sprint close and do not alter the final status of TASK-201 through TASK-212.

| Task ID | Workstream | Task | Owner | Status | Priority |
| --- | --- | --- | --- | --- | --- |
| TASK-301 | WS-301 | Publish final architecture contract for structured Apple workflow actions | `@architect` | Planned | High |
| TASK-302 | WS-301 | Publish data contract addendum for structured output schemas and constraints | `@architect` | Planned | High |
| TASK-303 | WS-302 | Produce backend execution plan for bounded structured tasks and fallback states | `@backend-lead` | Planned | High |
| TASK-304 | WS-302 | Define backend validation checklist for deterministic structured output mapping | `@backend-tester` | Planned | Medium |
| TASK-305 | WS-303 | Produce frontend integration plan for commands and selected-text actions | `@frontend-lead` | Planned | High |
| TASK-306 | WS-303 | Define UX copy and state checklist for non-chat Apple scope messaging | `@product-manager`, `@frontend-lead` | Planned | High |
| TASK-307 | WS-304 | Define QA gate pack for structured workflows, fallbacks, and observability artifacts | `@qa-lead` | Planned | High |
| TASK-308 | WS-304 | Define test evidence checklist for transcript and feedback capture acceptance | `@qa-lead`, `@backend-tester`, `@frontend-tester` | Planned | Medium |

### Intake Dependencies

- See decision blockers D-301 through D-305 in `docs/requirements/apple-foundation-models-structured-workflow-decision-log.md`.
