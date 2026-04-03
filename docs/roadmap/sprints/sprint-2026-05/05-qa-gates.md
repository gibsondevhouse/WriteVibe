# QA Gates

## Entry Checklist

- [x] Workstreams have explicit owners and scoped acceptance criteria.
- [x] Task board maps critical path execution to owners and priorities.
- [x] Risk register and blocker escalation owners are defined.
- [x] Architecture boundaries are documented for streaming, provider routing, and edit orchestration.

## In-Sprint Checks

- [x] Top-5 GA-critical workflows frozen and published on 2026-04-02.
- [x] Daily impacted tests pass before task status moves to Review.
- [x] Mid-sprint full suite run completed and logged by `@qa-lead`.
- [x] Contract drift checks completed for stream lifecycle, provider fallback, and edit orchestration.
- [x] Coverage uplift ladder published with weekly checkpoints under WS-204/WS-205 carry-forward mandate.

## Exit Checklist

- [x] WS-201 reliability parity passes success/cancel/error/retry scenarios.
- [x] WS-202 provider failures map to user-visible actionable recovery states.
- [x] WS-203 edit confidence UX checks pass (orchestrator parity + diff behavior + error clarity).
- [x] WS-204 critical-path automation passes and is non-flaky.
- [x] WS-205 blocker register is current and all high/medium blockers are closed or waived.
- [x] No unresolved P0/P1 defects in sprint scope.
- [x] Handoff records exist for all owner transitions.

## Critical Test Matrix

| Area | Must-Pass Scenarios | Owner |
| --- | --- | --- |
| Streaming and persistence | Placeholder create/update/finalize, cancel/retry consistency, idempotent persistence writes | `@backend-tester` |
| Provider reliability and recovery | Anthropic/OpenRouter/Ollama fallback and user recovery state mapping | `@backend-tester` |
| Article edit confidence | Replace/insert/delete validation, round-trip integrity, diff behavior for rewrite actions | `@frontend-tester` |
| Release operations | Blocker SLA adherence, waiver logging, sign-off evidence completeness | `@qa-lead` |

## QA Decision

- Status: Sprint Closed (Delivery Scope Complete)
- Owner: `@qa-lead`
- Notes:
  - QA entry gate passed for sprint planning artifacts on 2026-04-02.
  - TASK-211 is Complete: first-pass inventory, reproduce-or-quarantine checks, and immediate CTO-requested CI-level confirmation all passed on 2026-04-02.
  - CTO requested immediate continuation on 2026-04-02; QA executed CI-like confirmation immediately instead of waiting for the 2026-04-05 checkpoint.
  - TASK-210 started on 2026-04-02; workflow freeze work is active under WS-204.
  - TASK-210 top-5 GA-critical workflow package was frozen and approved on 2026-04-02 after the same-day WS-201 ownership correction, and the active gate command produced a passing first enforcement run on 2026-04-02 (`TEST SUCCEEDED`).
  - Daily impacted test pass tracking is now required for tasks in Review state.
  - TASK-202 remains In Progress: adapter-owned persistence path is implemented, but parity evidence is not yet sufficient because targeted streaming tests are unstable under multi-test execution.
  - TASK-201 is Complete: protocol boundary lock signoffs from `@backend-lead` and `@frontend-lead` are recorded, and blocker B-203 is closed.
  - CI-level checkpoint evidence for B-204 on 2026-04-02: combined rerun #1 passed (10/10), combined rerun #2 passed (10/10), TASK-210 gate pack passed (40/40), optional full suite passed (`result: Passed`, `totalTestCount: 76`).
  - TASK-206 is Complete: build passed and focused provider suites (`ServiceContainerTests`, `ProviderRecoveryTests`) passed, with no active automation blocker on the task.
  - TASK-207 remains in Review with focused automation green (`ArticleEditOrchestratorTests`); remaining closure work is parity confirmation via integration/UI-path regression evidence.
  - TASK-208 is Complete: focused automation is green (`ChatRewriteDiffSupportTests`) and no active automated QA blocker is open for this task.
  - TASK-209 remains in Review with build passing; closure still requires manual product+QA copy/clarity review.
  - B-204 is Closed based on immediate CI-level confirmation evidence; no active test-host stability blocker remains for `AppStateProviderRecoveryTests`/`StreamingServiceTests`.
  - Residual QA risk remains coverage-related (full-suite app coverage 20.37%); this is tracked under coverage uplift governance, not as a B-204 blocker.
  - WS-204 execution lock: TASK-210 approval deadline 2026-04-04 EOD; TASK-211 stability proof deadline 2026-04-09 EOD.
  - WS-205 execution lock: twice-weekly blocker triage and weekly readiness snapshots are mandatory with QA co-review.
  - WS-205 blocker triage snapshots are published on 2026-04-02 with Conditional Go trend; no waivers issued and B-203/B-204/B-205 are closed.
  - WS-205 coverage uplift ladder was published and approved on 2026-04-02 (baseline 29.29% overall / 20.37% app); weekly checkpoint enforcement is now active.
  - TASK-202 is Complete (2026-04-02): adapter-only mutation path fully confirmed; StreamingServiceTests 9/9 PASS, StreamingServiceContractTests 6/6 PASS.
  - TASK-204 is Complete (2026-04-02): provider failure taxonomy documented — OpenRouter 7 classes, Anthropic 7 classes, Ollama 9 classes, cross-provider 5 classes — all mapped to `WriteVibeError` → `RuntimeIssue` with title + message + nextStep.
  - TASK-205 is Complete (2026-04-02): Ollama silent failure path removed; `AppStateProviderRecoveryTests` passed; gate pack passed.
  - TASK-207 is Complete (2026-04-02): `ArticleEditOrchestratorTests` 13/13 PASS; boundary audit confirmed no direct SwiftData mutations in view or view-model apply/accept/reject paths.
  - TASK-209 is Complete (2026-04-02): product and QA copy/clarity review passed across all 4 recovery UI surfaces; all TASK-204 failure classes have recovery copy.
  - Implementation wave final gate pack run (2026-04-02): `result: Passed`, 40/40 PASS, 0 failures — StreamingServiceContractTests 6/6, StreamingServiceTests 9/9, ProviderRecoveryTests 7/7, ArticleEditOrchestratorTests 13/13, ChatRewriteDiffSupportTests 5/5.
  - Full suite run (2026-04-02, 17:02:47 -0400): `result: Passed`, 76/76 PASS, 0 failures, 0 skipped.
  - No new compiler warnings observed in the current delivery wave.
  - No debug-only instrumentation or hardcoded secrets identified in reviewed files.
  - Coverage Week 1 preliminary note (2026-04-05 deadline): No new test methods were added in this implementation wave (76 tests identical to baseline). A dedicated Xcode coverage-enabled run is required before 2026-04-05 EOD to confirm or refute the ≥31.00% overall / ≥21.00% app threshold. Coverage uplift task items must begin immediately to avoid missing Week 1 ladder target.

## Final Gate Validation — Implementation Wave Sign-Off (2026-04-02)

### Gate Pack Run (Critical Path)

| Suite | Tests | Result |
| --- | --- | --- |
| StreamingServiceContractTests | 6/6 | PASS |
| StreamingServiceTests | 9/9 | PASS |
| ProviderRecoveryTests | 7/7 | PASS |
| ArticleEditOrchestratorTests | 13/13 | PASS |
| ChatRewriteDiffSupportTests | 5/5 | PASS |
| **Gate Pack Total** | **40/40** | **PASS** |

### Full Suite Run

| Metric | Value |
| --- | --- |
| Result | Passed |
| Total tests | 76 |
| Passed | 76 |
| Failed | 0 |
| Skipped | 0 |
| Run timestamp | 2026-04-02 17:02:47 -0400 |

### QA Recommendation

**READY FOR DELIVERY SIGN-OFF.**

All quality gates are cleared:

- All 5 delivery tasks (TASK-202, TASK-204, TASK-205, TASK-207, TASK-209) reported Complete by delivery leads and confirmed via gate automation.
- Critical-path gate pack 40/40 PASS with zero failures.
- Full suite 76/76 PASS with zero failures.
- All exit checklist items satisfied.
- No open high/medium blockers (B-202/203/204/205 Closed, B-201 Monitoring only).
- No P0/P1 defects in sprint scope.

Coverage Week 1 ladder checkpoint (≥31.00% overall / ≥21.00% app) — **MET** (2026-04-02, ahead of 2026-04-05 EOD deadline). Four new service test files added by `@backend-tester` (MarkdownParserTests, ExportServiceTests, KeychainServiceTests, MessagePersistenceAdapterTests — 28 test cases). Full-suite coverage-enabled run result: **22.48% app (2816/12526)**, **33.49% overall (4910/14659)**. All new tests PASS. Full suite remains 104/104 (76 unit + 28 new + UI tests). Coverage ladder obligation for Week 1 is closed.

Recommendation to `@cto`: Approve sprint-2026-05 closeout. Delivery scope is complete; continue B-201 provider monitoring under release operations governance.

## Implementation Readiness Decision

- Decision: Ready for implementation execution.
- Decision Date: 2026-04-02
- Rationale: Entry gate passed, workflow freeze/gate enforcement active, and planning-phase blockers B-202/B-203/B-204/B-205 are closed.
- Constraint: Historical entry decision only. Sprint implementation scope was later completed and formally closed on 2026-04-02.

## Post-Close Intake Gates (Apple Structured Workflow)

These gates apply to post-close intake WS-301 through WS-304 and do not modify the historical 2026-04-02 sprint close decision.

### Intake Entry Checklist

- [ ] Architecture contract is finalized for structured workflow boundaries and non-chat guardrails (TASK-301).
- [ ] Data contract addendum is finalized for typed output schemas and bounded field mapping (TASK-302).
- [ ] Decision queue D-301 through D-305 has owners, due dates, and active review status.
- [ ] Fallback UX standard is defined for unavailable Apple Intelligence states.
- [ ] Transcript/feedback retention policy is approved before evaluation capture activation.

### Intake Exit Checklist

- [ ] Backend and frontend lead plans are approved for WS-302 and WS-303.
- [ ] QA gate pack draft is approved for structured workflows, fallback behavior, and observability artifacts (TASK-307).
- [ ] Evidence checklist is approved for transcript and feedback capture acceptance (TASK-308).
- [ ] No unresolved high-severity blockers remain in B-301 through B-304.

### Intake References

- `docs/requirements/apple-foundation-models-structured-workflow-augmentation.md`
- `docs/requirements/apple-foundation-models-structured-workflow-augmentation-handoff.md`
- `docs/architecture/service-contracts/apple-foundation-models-structured-workflow-contract.md`
- `docs/requirements/apple-foundation-models-structured-workflow-decision-log.md`
- `docs/requirements/apple-foundation-models-structured-workflow-task-stubs.md`
