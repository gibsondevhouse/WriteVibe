# Risks and Blockers

## Risks

| Risk ID | Description | Impact | Likelihood | Owner | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- |
| R-201 | Streaming/persistence refactor introduces message lifecycle regressions | High | Medium | `@backend-lead` | Ship protocol tests before full rewiring and gate release path on parity checks | Open |
| R-202 | Provider behavior drift causes inconsistent fallback and user confusion | High | Medium | `@backend-lead` | Centralize typed provider failure mapping and UX recovery actions | Open |
| R-203 | Article orchestrator migration causes apply-state divergence | High | Medium | `@frontend-lead` | Migrate in bounded phases with round-trip validation and rollback flag | Open |
| R-204 | Expanded QA gate suite introduces flaky failures that stall merges | Medium | Medium | `@qa-lead` | Stabilize top-5 critical path first and quarantine with owner/date policy | Monitoring |
| R-205 | Late-sprint blocker discovery dilutes v1 focus and timeline confidence | High | Medium | `@cto` | Twice-weekly blocker triage and strict scope freeze for non-critical items | Open |

## Blockers

| Blocker ID | Description | Blocking Workstream | Escalation Owner | Status |
| --- | --- | --- | --- | --- |
| B-201 | External provider outage or API changes prevent deterministic validation | WS-202 | `@cto` | Monitoring |
| B-202 | Critical-path workflow list is not frozen by end of week 1 | WS-204 | `@qa-lead` | Closed |
| B-203 | Contract boundary lock (TASK-201) not yet complete for downstream parity validation | WS-201 | `@architect` | Closed |
| B-204 | xcodebuild test-host instability in `StreamingServiceTests`/`AppStateProviderRecoveryTests` under class-level or multi-test execution blocks reliability parity evidence for affected review tasks | WS-201 | `@backend-lead` | Closed |
| B-205 | Coverage uplift carry-forward from sprint-2026-04 lacks approved weekly target ladder and could slip past mid-sprint gate | WS-204, WS-205 | `@cto` | Closed |

## Decision Log

- 2026-04-02: CTO approved reliability-first v1 sprint scope for 2026-05 (no net-new platform features).
- 2026-04-02: Provider trust hardening includes explicit recovery UX and no silent failure tolerance.
- 2026-04-02: Chat diff view is included as confidence UX, not a broad visual redesign.
- 2026-04-02: Sprint kickoff authorized with Wave 1 tasks in progress across WS-201/WS-202/WS-203/WS-204/WS-205.
- 2026-04-02: Initial implementation landed for TASK-202 and TASK-207; WS-201 review gating blocked by streaming test-suite instability (B-204).
- 2026-04-02: Initial implementation landed for TASK-205 and TASK-208; both are review-ready, with backend QA still constrained by test-host instability.
- 2026-04-02: TASK-206 landed with focused provider smoke validation passing; direct Claude fallback now resolves Anthropic-native model IDs and actionable Anthropic/OpenRouter recovery guidance.
- 2026-04-02: QA consolidation narrowed B-204 impact scope: focused TASK-206/TASK-207/TASK-208 suites pass, while TASK-205/TASK-209 closure remains constrained where `AppStateProviderRecoveryTests`/`StreamingServiceTests` evidence is required.
- 2026-04-02: CTO set WS-204/WS-205 execution lock: TASK-210 approval due 2026-04-04 EOD, TASK-211 stability evidence due 2026-04-09 EOD, and weekly coverage uplift tracking is mandatory.
- 2026-04-02: TASK-211 first-pass flaky-test inventory was published in the task card with initial ownership assignments for `StreamingServiceTests`, `AppStateProviderRecoveryTests`, and their combined critical-path invocation; next checkpoint is 2026-04-05 EOD for reproduce-or-quarantine recommendation.
- 2026-04-02: WS-205 blocker triage snapshot #1 completed by `@cto`; no waivers issued, readiness trend set to Conditional Go, and B-203/B-204/B-205 remain active with dated checkpoints.
- 2026-04-02: TASK-210 top-5 GA-critical workflow package was approved by `@product-manager`, `@architect`, and `@qa-lead` after WS-201 ownership correction; B-202 closed, with CI gate activation evidence remaining as the final TASK-210 dependency.
- 2026-04-02: TASK-210 CI gate rule was activated and first enforcement run for the frozen critical-path suite passed (`TEST SUCCEEDED`); TASK-210 moved to Complete.
- 2026-04-02: TASK-211 reproduce-or-quarantine checkpoint reran combined `StreamingServiceTests` + `AppStateProviderRecoveryTests` twice with `TEST SUCCEEDED` both times; B-204 downgraded to Monitoring pending CI-level confirmation by 2026-04-05 EOD.
- 2026-04-02: WS-205 published and approved weekly coverage uplift ladder (baseline 29.29% overall / 20.37% app); B-205 closed and moved to scheduled checkpoint enforcement.
- 2026-04-02: TASK-201 protocol boundary lock recorded backend and frontend lead sign-off; B-203 closed and WS-201 dependency shifted to B-204 monitoring checkpoint only.
- 2026-04-02: CTO-directed immediate CI-level confirmation for B-204 completed ahead of the prior 2026-04-05 checkpoint: combined `StreamingServiceTests` + `AppStateProviderRecoveryTests` passed in two fresh reruns (10/10 each), TASK-210 critical-path gate pack passed (40/40), optional full suite passed (`result: Passed`, `totalTestCount: 76`), and `xcodebuild build` returned `BUILD SUCCEEDED`; B-204 closed on objective evidence.
- 2026-04-02: Residual risk remains on coverage readiness (full-suite app target coverage stayed at 20.37% vs long-term threshold goals), but this does not reopen B-204 test-host stability status.
- 2026-04-02: Implementation readiness gate passed for sprint-2026-05; planning-phase blockers are closed and remaining open items are execution-phase delivery/quality outcomes.
- 2026-04-02: CTO implementation wave closed. TASK-202/204/205/207/209 all Complete. WS-201/202/203 Complete. Final gate pack 40/40 PASS, full suite 76/76 PASS. QA Lead issued Ready for Delivery Sign-Off. Coverage Week 1 ladder check (≥31.00% overall / ≥21.00% app) is non-blocking to wave sign-off but non-waivable; due 2026-04-05 EOD under WS-205 governance.
- 2026-04-02: Coverage Week 1 ladder checkpoint was completed ahead of deadline and passed: app 22.48% (target ≥21.00%), overall 33.49% (target ≥31.00%). WS-205 remains active for Week 2 checkpoint enforcement (2026-04-12 EOD).
- 2026-04-02: Sprint-2026-05 formally closed by `@cto` with `@qa-lead` co-review. TASK-212 completed; all sprint tasks and workstreams are complete. B-201 remains Monitoring as an external-dependency operational watch, not an open sprint blocker.

## Escalation SLA

- Any blocker open for more than 2 business days escalates to `@cto`.
- Any blocker impacting WS-201 or WS-204 requires same-day triage by `@cto` and `@qa-lead`.

## Post-Close Intake Risks (Apple Structured Workflow)

| Risk ID | Description | Impact | Likelihood | Owner | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- |
| R-301 | Structured output contracts become too broad and increase context cost or mapping ambiguity | High | Medium | `@architect` | Keep schema concise and task-bounded before contract freeze | Open |
| R-302 | Apple workflow scope drifts into generic chat expectations in UX copy or routing behavior | High | Medium | `@product-manager` | Enforce explicit non-chat copy and route guardrails in acceptance checks | Open |
| R-303 | Fallback behavior for unavailable Apple Intelligence is inconsistent across entry points | High | Medium | `@frontend-lead` | Define shared fallback UX contract and QA checklist before implementation | Open |
| R-304 | Transcript and feedback capture lacks approved retention policy before activation | Medium | Medium | `@qa-lead` | Block evaluation-capture rollout until governance decision is closed | Open |

## Post-Close Intake Blockers (Apple Structured Workflow)

| Blocker ID | Description | Blocking Workstream | Escalation Owner | Status |
| --- | --- | --- | --- | --- |
| B-301 | Architecture contract and data contract addendum are not finalized for WS-301 | WS-301 | `@architect` | Open |
| B-302 | Rollout strategy decision (staged flag vs default-on) is unresolved | WS-302, WS-303, WS-304 | `@cto` | Open |
| B-303 | Structured-task quality threshold and fallback UX standard are unresolved | WS-304 | `@qa-lead` | Open |
| B-304 | Transcript and feedback retention policy unresolved for internal evaluation artifacts | WS-304 | `@cto` | Open |

## Post-Close Intake Decision Log (Apple Structured Workflow)

- 2026-04-03: Product requirements and handoff package were published for Apple Foundation Models structured workflow augmentation.
- 2026-04-03: WS-301 through WS-304 were queued as planned post-close intake workstreams pending architecture and governance decisions.
- 2026-04-03: Decision queue D-301 through D-305 was opened with owner assignments and due dates in `docs/requirements/apple-foundation-models-structured-workflow-decision-log.md`.
