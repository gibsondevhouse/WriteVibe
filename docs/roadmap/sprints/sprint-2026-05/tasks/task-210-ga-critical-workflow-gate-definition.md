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

## Proposed Top-5 GA-Critical Workflow Package

Draft published: 2026-04-02

| Workflow | Rationale | Primary Owner |
| --- | --- | --- |
| Chat send to streamed reply persistence | Core GA value path. A user prompt must produce a visible assistant reply with placeholder creation, token updates, and finalized persistence without data loss or orphaned state. | `@backend-tester` |
| In-flight response cancel/retry/finalize recovery | Launch trust depends on users being able to stop or retry generation without duplicate messages, stuck thinking state, or inconsistent conversation history. | `@backend-tester` |
| Provider failure, fallback, and recovery messaging | GA cannot ship with opaque provider failure states. Anthropic, OpenRouter, and Ollama routing failures must degrade into explicit recovery guidance rather than silent or generic failure. | `@backend-lead` |
| Article rewrite request to diff review rendering | AI edit confidence is launch-critical for article workflows. Rewrite requests must produce an inspectable diff view so users can understand proposed changes before applying them. | `@frontend-lead` |
| Article diff accept/apply persistence integrity | Approval to apply a rewrite must preserve document structure and persist the accepted result through the orchestrator boundary without corruption or dropped edits. | `@frontend-lead` |

## Approval Status

Target approval date: 2026-04-04 EOD

- `@product-manager`: Pending signoff. Name: TBD. Date: TBD. Notes: Draft package published for review.
- `@architect`: Pending signoff. Name: TBD. Date: TBD. Notes: Architecture review required before workflow freeze.
- `@qa-lead`: Pending signoff. Name: TBD. Date: TBD. Notes: QA gate owner review required before CI enforcement.

## Evidence Required For Closeout

- Approved workflow list link in sprint handoff trail.
- CI configuration/automation evidence and passing run snapshot.
- QA signoff note confirming merge-block behavior for critical workflow failures.
