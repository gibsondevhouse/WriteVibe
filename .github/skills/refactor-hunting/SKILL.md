---
name: refactor-hunting
description: 'Search the WriteVibe codebase for high-ROI refactor opportunities and produce ranked, agent-ready recommendations with ownership, payoff, and next-step guidance. Use for structural cleanup decisions, complexity reduction, and maintenance planning.'
argument-hint: 'Area to inspect or constraint such as app state, services, articles, low risk, or testability'
user-invocable: true
---

# Refactor Hunting

## When to Use

- Find the best next structural cleanup opportunity
- Assess maintainability hotspots before a new sprint
- Turn a refactor idea into an agent-ready workstream candidate
- Compare quick wins versus deeper architecture work

## References

- [WriteVibe Roadmap](../../../docs/roadmap/writevibe-roadmap.md)
- [Sprint Planning Hub](../../../docs/roadmap/sprints/README.md)
- [Handoff Protocol](../../HANDOFF-PROTOCOL.md)

## Procedure

1. Search the actual codebase before making recommendations.
2. Prioritize opportunities that reduce complexity, lower regression risk, or unlock future work.
3. For each candidate, assess:
   - why it matters now
   - affected files or subsystems
   - effort and risk
   - expected payoff
   - best owner
   - whether it belongs in the current sprint, next sprint, or backlog
4. Rank candidates by payoff versus effort and risk.
5. If useful, convert the strongest candidate into sprint/workstream planning docs under `docs/roadmap/sprints/`.

## Output Standard

- Ranked shortlist of opportunities
- File-specific evidence
- Clear payoff and ownership
- Actionable next step for the top candidate

## Avoid

- Style-only cleanup suggestions
- Large unfocused lists
- Recommendations without code evidence
