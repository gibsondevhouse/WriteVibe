# QA Gates

## Entry Checklist

- [x] Workstreams have explicit owners and scoped acceptance criteria.
- [x] Task board maps critical path execution to owners and priorities.
- [x] Risk register and blocker escalation owners are defined.
- [x] Architecture boundaries are documented for streaming, provider routing, and edit orchestration.

## In-Sprint Checks

- [x] Top-5 GA-critical workflows frozen and published on 2026-04-02.
- [ ] Daily impacted tests pass before task status moves to Review.
- [ ] Mid-sprint full suite run completed and logged by `@qa-lead`.
- [ ] Contract drift checks completed for stream lifecycle, provider fallback, and edit orchestration.
- [x] Coverage uplift ladder published with weekly checkpoints under WS-204/WS-205 carry-forward mandate.

## Exit Checklist

- [ ] WS-201 reliability parity passes success/cancel/error/retry scenarios.
- [ ] WS-202 provider failures map to user-visible actionable recovery states.
- [ ] WS-203 edit confidence UX checks pass (orchestrator parity + diff behavior + error clarity).
- [ ] WS-204 critical-path automation passes and is non-flaky.
- [ ] WS-205 blocker register is current and all high/medium blockers are closed or waived.
- [ ] No unresolved P0/P1 defects in sprint scope.
- [ ] Handoff records exist for all owner transitions.

## Critical Test Matrix

| Area | Must-Pass Scenarios | Owner |
| --- | --- | --- |
| Streaming and persistence | Placeholder create/update/finalize, cancel/retry consistency, idempotent persistence writes | `@backend-tester` |
| Provider reliability and recovery | Anthropic/OpenRouter/Ollama fallback and user recovery state mapping | `@backend-tester` |
| Article edit confidence | Replace/insert/delete validation, round-trip integrity, diff behavior for rewrite actions | `@frontend-tester` |
| Release operations | Blocker SLA adherence, waiver logging, sign-off evidence completeness | `@qa-lead` |

## QA Decision

- Status: In Progress
- Owner: `@qa-lead`
- Notes:
  - QA entry gate passed for sprint planning artifacts on 2026-04-02.
  - TASK-211 first-pass flaky inventory was published on 2026-04-02; this is a monitoring checkpoint only and does not claim the affected suites are stabilized.
  - TASK-211 next checkpoint is 2026-04-05 EOD for CI-level reproduce-or-quarantine confirmation on `StreamingServiceTests`, `AppStateProviderRecoveryTests`, and their combined critical-path invocation.
  - TASK-210 started on 2026-04-02; workflow freeze work is active under WS-204.
  - TASK-210 top-5 GA-critical workflow package was frozen and approved on 2026-04-02 after the same-day WS-201 ownership correction, and the active gate command produced a passing first enforcement run on 2026-04-02 (`TEST SUCCEEDED`).
  - Daily impacted test pass tracking is now required for tasks in Review state.
  - TASK-202 remains In Progress: adapter-owned persistence path is implemented, but parity evidence is not yet sufficient because targeted streaming tests are unstable under multi-test execution.
  - TASK-201 is Complete: protocol boundary lock signoffs from `@backend-lead` and `@frontend-lead` are recorded, and blocker B-203 is closed.
  - TASK-205 remains in Review and constrained by B-204 monitoring: two fresh combined reruns of `StreamingServiceTests` + `AppStateProviderRecoveryTests` passed on 2026-04-02, but CI-level confirmation is still required before removing the reliability caution.
  - TASK-206 is Complete: build passed and focused provider suites (`ServiceContainerTests`, `ProviderRecoveryTests`) passed, with no active automation blocker on the task.
  - TASK-207 remains in Review with focused automation green (`ArticleEditOrchestratorTests`); remaining closure work is parity confirmation via integration/UI-path regression evidence.
  - TASK-208 is Complete: focused automation is green (`ChatRewriteDiffSupportTests`) and no active automated QA blocker is open for this task.
  - TASK-209 remains in Review with build passing; closure still requires manual product+QA copy/clarity review and is also partially QA-blocked by the same `AppStateProviderRecoveryTests` instability captured in B-204.
  - B-204 scope is now narrower than WS-wide execution: it is under Monitoring and remains a caution only where `AppStateProviderRecoveryTests`/`StreamingServiceTests` evidence is required, while focused TASK-206/TASK-207/TASK-208 validation remains unblocked.
  - WS-204 execution lock: TASK-210 approval deadline 2026-04-04 EOD; TASK-211 stability proof deadline 2026-04-09 EOD.
  - WS-205 execution lock: twice-weekly blocker triage and weekly readiness snapshots are mandatory with QA co-review.
  - WS-205 blocker triage snapshot #1 was published on 2026-04-02 with Conditional Go trend; no waivers issued and B-203/B-204/B-205 remain active.
  - WS-205 coverage uplift ladder was published and approved on 2026-04-02 (baseline 29.29% overall / 20.37% app); weekly checkpoint enforcement is now active.
