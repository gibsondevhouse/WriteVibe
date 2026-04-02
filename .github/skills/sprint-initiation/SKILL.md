---
name: sprint-initiation
description: 'Create or refresh an agent-focused sprint planning pack in docs/roadmap/sprints. Use for starting a new sprint, re-baselining an existing sprint, creating charter/goals/workstreams/task board/risk docs, and making sprint docs handoff-ready.'
argument-hint: 'Sprint name, date range, focus, goals, and seed workstreams'
user-invocable: true
---

# Sprint Initiation

## When to Use

- Start a new sprint folder under `docs/roadmap/sprints/`
- Re-baseline an existing sprint
- Convert a vague sprint goal into agent-ready planning artifacts
- Create the first workstream, task card, and handoff records for a sprint

## References

- [Sprint Planning Hub](../../../docs/roadmap/sprints/README.md)
- [Sprint Index](../../../docs/roadmap/sprints/_indexes/sprint-index.md)
- [Active Workstreams](../../../docs/roadmap/sprints/_indexes/active-workstreams.md)
- [Handoff Protocol](../../HANDOFF-PROTOCOL.md)

## Procedure

1. Determine the target sprint folder in the form `sprint-YYYY-MM`.
2. Inspect existing templates under `docs/roadmap/sprints/_templates/` and reuse them.
3. Create or update the sprint pack with:
   - `00-charter.md`
   - `01-goals-and-outcomes.md`
   - `02-agent-workstreams.md`
   - `03-task-board.md`
   - `04-risks-and-blockers.md`
   - `05-qa-gates.md`
   - `06-retro.md`
   - `handoffs/`, `workstreams/`, and `tasks/`
4. Add at least one workstream doc, one task card, and one handoff doc when the sprint is new.
5. Update the sprint indexes so the sprint is discoverable.
6. Keep all wording agent-facing, ownership-driven, and handoff-ready.

## Output Standard

- Agent-operational, not developer-facing
- Explicit ownership on workstreams, tasks, blockers, and QA gates
- Status-driven tables and checklist-based gates
- Easy to audit from sprint charter to QA sign-off

## Avoid

- Developer implementation playbook language
- Broad roadmap rewriting outside the target sprint
- Unowned tasks or vague acceptance criteria
