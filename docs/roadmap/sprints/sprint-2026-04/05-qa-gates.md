# QA Gates

## Entry Checklist

- [x] Workstreams are decomposed with explicit owner and status.
- [x] Acceptance criteria are defined in requirements and architecture artifacts.
- [x] Risk register and blockers include escalation owner.
- [x] Feature-flag rollout strategy is documented for high-risk refactors.

## In-Sprint Checks

- [x] Daily impacted tests pass before task status moves to Review.
- [ ] Mid-sprint full suite run completed and logged by `@qa-lead`.
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

- Status: In Progress
- Owner: `@qa-lead`
- Notes:
  - Entry gate passed on 2026-04-02.
  - Blocker audit completed and blockers B-001/B-002/B-003 closed on 2026-04-02.
  - TASK-110 completed: scored risk register and escalation SLA review validated on 2026-04-02.
  - WS-106 marked complete and QA closure signoff issued to CTO on 2026-04-02.
  - TASK-108 contract test suite landed and is passing on 2026-04-02.
  - Full build and test run passed on 2026-04-02 after Phase 1 execution updates.
  - Provider fallback and recovery behavior validated with focused tests for Anthropic/OpenRouter and Ollama search recovery paths.
  - Mid-sprint gate still pending scheduled checkpoint run by `@qa-lead` (2026-04-15).
