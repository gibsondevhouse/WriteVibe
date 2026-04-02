---
name: sprint-execution
description: 'Advance an active sprint by updating workstreams, task status, risks, blockers, QA gates, and handoff records in docs/roadmap/sprints. Use for moving a sprint from planning into active agent delivery.'
argument-hint: 'Sprint name and the workstreams, tasks, blockers, or handoffs to advance'
user-invocable: true
---

# Sprint Execution

## When to Use

- Advance a sprint already created under `docs/roadmap/sprints/`
- Update task owners, statuses, blockers, or QA progress
- Record agent handoffs as work changes owners
- Keep sprint indexes aligned with current execution reality

## References

- [Sprint Planning Hub](../../../docs/roadmap/sprints/README.md)
- [Sprint Index](../../../docs/roadmap/sprints/_indexes/sprint-index.md)
- [Active Workstreams](../../../docs/roadmap/sprints/_indexes/active-workstreams.md)
- [Handoff Protocol](../../HANDOFF-PROTOCOL.md)

## Procedure

1. Identify the target sprint folder and inspect current sprint artifacts.
2. Determine which workstreams or tasks should move forward.
3. Update:
   - `02-agent-workstreams.md`
   - `03-task-board.md`
   - `04-risks-and-blockers.md`
   - `05-qa-gates.md`
   - related docs in `handoffs/`, `workstreams/`, and `tasks/`
4. Create or refresh handoff records whenever ownership changes.
5. Update sprint indexes when active status changed materially.
6. Leave the sprint pack in a state where the next agent can act without extra clarification.

## Output Standard

- Current and actionable
- Clear next owner and next move
- Consistent status values: Planned, In Progress, Blocked, Review, Complete
- Handoff-ready with blockers and escalation ownership captured

## Avoid

- Duplicating docs instead of updating current sprint artifacts
- Vague blockers without owners
- Untracked ownership changes
