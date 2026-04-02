# Task Card: TASK-210 GA-Critical Workflow Gate Definition

- Workstream: WS-204
- Owner: `@qa-lead`
- Priority: High
- Status: In Progress

## Objective

Define top-5 GA-critical workflows and enforce CI gate requirements for those flows.

## Acceptance Criteria

- [ ] Workflow list approved by `@product-manager`, `@architect`, and `@qa-lead`.
- [ ] CI gate rule is documented and active.

## Dependencies

- Requires lead alignment on launch-critical path scope.

## Execution Checkpoints

- 2026-04-03 EOD: publish proposed top-5 workflow list with rationale and owners.
- 2026-04-04 EOD: secure approval from `@product-manager`, `@architect`, and `@qa-lead`.
- 2026-04-05 EOD: enforce CI gate rule and publish first gate run evidence.

## Evidence Required For Closeout

- Approved workflow list link in sprint handoff trail.
- CI configuration/automation evidence and passing run snapshot.
- QA signoff note confirming merge-block behavior for critical workflow failures.
