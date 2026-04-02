# Risks and Blockers

## Risks

| Risk ID | Description | Impact | Likelihood | Owner | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- |
| R-001 | Streaming and persistence refactor introduces message lifecycle regressions | High | Medium | `@backend-lead` | TASK-101/102/108 complete; keep parity checks in daily focused smoke set during stabilization window | Monitoring |
| R-002 | Article edit orchestration split causes apply-state drift in review mode | High | Medium | `@frontend-lead` | Two-phase migration complete for sprint scope; TASK-103/104/109 complete with parity validation evidence | Monitoring |
| R-003 | Provider reliability fixes are delayed by unresolved API behavior assumptions | Medium | Medium | `@backend-lead` | TASK-105/TASK-106 complete with focused QA smoke validation evidence | Monitoring |
| R-004 | Premature performance optimization could destabilize conversion correctness | Medium | Medium | `@frontend-lead` | Keep WS-104 scoped to stable/accurate conversion plus baseline capture this sprint | Monitoring |
| R-005 | QA coverage expansion introduces flaky tests that block merge cadence | Medium | High | `@qa-lead` | Use seam-level contract tests and quarantine unstable cases with owner/date; enforce blocker ownership for repeat failures | Active |
| R-006 | Mid-sprint full-suite aggregate run showed broad 0.000s unit failures, reducing confidence in release gate signal | High | Medium | `@backend-lead` | Root cause isolated to backend test fixture lifetime + interruption contract assertion mismatch; focused and full-suite reruns now green | Mitigated |
| R-007 | Coverage at rerun checkpoint remains below threshold (26.76% overall; 18.32% app target) and cannot satisfy default QA gate | High | High | `@qa-lead` | CTO granted sprint-2026-04 scoped exception with mandatory coverage uplift workstream in sprint-2026-05 (WS-204/WS-205) | Monitoring |

## Blockers

| Blocker ID | Description | Blocking Workstream | Escalation Owner | Next Action | Status |
| --- | --- | --- | --- | --- | --- |
| B-001 | WS-104 scope clarified to stability/accuracy-first; hard latency target deferred | WS-104 | `@cto` | None (decision locked) | Closed |
| B-002 | Duplicate InputBar decision resolved: clarify ownership/usage this sprint | WS-103 | `@cto` | None (decision locked) | Closed |
| B-003 | Ollama-only search UX decision resolved: soft warning with fallback behavior | WS-103 | `@product-manager` | None (decision locked) | Closed |
| B-004 | QA-reported TASK-108 build blocker (duplicate stringsdata artifact) | WS-105 | `@cto` | None (resolved via conformance/test target corrections) | Closed |
| B-005 | Mid-sprint full-suite gate failure: 37 unit failures in aggregate run (exit 65) | WS-101, WS-103, WS-105 | `@backend-lead` | Monitor nightly aggregate run; reopen only if regression reproduces | Closed |
| B-006 | Streaming interruption contract test failure: `testPlaceholderInterruptionPath_CreateCancelRetry` | WS-101, WS-105 | `@backend-lead` | Keep interruption path in focused critical-path smoke set for daily reruns | Closed |
| B-007 | Coverage threshold gate unmet at rerun checkpoint (26.76% overall / 18.32% app vs 80% target) | WS-105 | `@cto` | Closed with sprint-2026-04 scoped exception; enforce coverage uplift plan in sprint-2026-05 WS-204/WS-205 with explicit gate metric tracking | Closed |

## Decision Log

- 2026-04-02: WS-104 de-scoped from strict latency target to correctness-first conversion hardening.
- 2026-04-02: InputBar direction set to ownership clarification instead of merge work.
- 2026-04-02: Ollama-only search failure handling set to soft warning with fallback.
- 2026-04-02: QA-reported TASK-108 build blocker resolved after conformance/test target corrections; full suite rerun passed.
- 2026-04-02: Mid-sprint QA checkpoint executed; full-suite gate failed with 37 unit failures and one repeatable focused failure in streaming interruption contract coverage.
- 2026-04-02: QA checkpoint recommendation set to Go with conditions for continued sprint execution, No-go for sprint exit until blockers B-005/B-006/B-007 are resolved.
- 2026-04-02: Backend burn-down isolated aggregate crash vector to SwiftData `ModelContainer` lifetime in `StreamingServiceTests` fixture and patched helper to retain container through test scope.
- 2026-04-02: Backend burn-down corrected interruption contract assertion (`partial token count` expected 19) and revalidated focused interruption, TASK-105/106 reliability, and full-suite aggregate runs as passing.
- 2026-04-02 14:56 ET: QA reran full suite and focused critical-path suites after backend burn-down; both runs passed (71/71 and 34/34). B-005 and B-006 remain closed with regression monitoring, B-007 remains open due 26.76% overall coverage.
- 2026-04-02 14:56 ET: QA decision reaffirmed: Go for continued sprint execution, No-go for sprint exit until B-007 is resolved or explicitly waived by `@cto`.
- 2026-04-02 15:20 ET: CTO decision lock: B-007 closed with sprint-scoped coverage exception based on green full/focused gates and completed hotspot tasks; coverage uplift is mandatory carry-forward scope in sprint-2026-05 WS-204/WS-205.
- 2026-04-02 15:21 ET: Final exit-readiness rerun completed by QA; fresh full suite and focused critical-path suites both passed (76/76 and 39/39). Coverage remained below default threshold (29.29% overall), consistent with CTO-locked B-007 sprint-scoped exception and carry-forward uplift requirement.

## Escalation SLA

- Blockers open for more than 2 business days escalate to `@cto` in daily sprint review.
- Any blocker affecting WS-101 or WS-102 immediately moves dependent tasks to Blocked status.
