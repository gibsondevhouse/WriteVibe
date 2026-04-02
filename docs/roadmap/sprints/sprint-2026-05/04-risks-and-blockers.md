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
| B-202 | Critical-path workflow list is not frozen by end of week 1 | WS-204 | `@qa-lead` | In Progress |
| B-203 | Contract boundary lock (TASK-201) not yet complete for downstream parity validation | WS-201 | `@architect` | Open |
| B-204 | xcodebuild test-host instability in `StreamingServiceTests`/`AppStateProviderRecoveryTests` under class-level or multi-test execution blocks reliability parity evidence for affected review tasks | WS-201 | `@backend-lead` | Open |
| B-205 | Coverage uplift carry-forward from sprint-2026-04 lacks approved weekly target ladder and could slip past mid-sprint gate | WS-204, WS-205 | `@cto` | Open |

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

## Escalation SLA

- Any blocker open for more than 2 business days escalates to `@cto`.
- Any blocker impacting WS-201 or WS-204 requires same-day triage by `@cto` and `@qa-lead`.
