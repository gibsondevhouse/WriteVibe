# Task Board

| Task ID | Workstream | Task | Owner | Status | Priority |
| --- | --- | --- | --- | --- | --- |
| TASK-201 | WS-201 | Lock protocol boundaries for streaming/persistence and edit orchestration | `@architect` | Complete | High |
| TASK-202 | WS-201 | Complete adapter-only streaming persistence mutation path | `@backend-developer` | In Progress | High |
| TASK-203 | WS-201 | Validate cancellation/retry/finalize parity via contract tests | `@backend-tester` | Complete | High |
| TASK-204 | WS-202 | Build provider failure taxonomy and typed mapping matrix | `@backend-lead` | In Progress | High |
| TASK-205 | WS-202 | Eliminate Ollama-only silent search failure and map recovery UX | `@backend-developer` | Review | High |
| TASK-206 | WS-202 | Update stale Anthropic API version/config defaults and error states | `@backend-developer` | Complete | Medium |
| TASK-207 | WS-203 | Move article apply flow fully behind orchestrator boundary | `@frontend-developer` | Review | High |
| TASK-208 | WS-203 | Add chat diff view for rewrite actions using existing DiffEngine | `@frontend-developer` | Complete | Medium |
| TASK-209 | WS-203 | Replace generic warning strings with explicit user recovery states | `@frontend-lead` | Review | High |
| TASK-210 | WS-204 | Define and enforce top-5 GA-critical workflow CI gate | `@qa-lead` | Complete | High |
| TASK-211 | WS-204 | Stabilize flaky critical-path tests and quarantine policy | `@qa-lead` | Complete | Medium |
| TASK-212 | WS-205 | Operate launch blocker register, waiver log, and weekly readiness review | `@cto` | In Progress | High |

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
