# Task Board

## Execution Sequencing (by Phase)

### Phase 1: Contract Validation Gateway (Days 1-3 | by 2026-04-04)

| Task ID | Workstream | Task | Owner | Status | Priority | Blocking |
| --- | --- | --- | --- | --- | --- | --- |
| TASK-108 | WS-105 | Add contract tests for streaming interruption and placeholder lifecycle | `@backend-tester` | Complete | Critical | TASK-102 |
| TASK-103 | WS-102 | Create ArticleEditOrchestrator boundary and default implementation | `@frontend-lead` | Complete | High | TASK-104 |
| TASK-107 | WS-104 | Establish document sync benchmark corpus and conversion baseline | `@frontend-lead` | In Progress | Medium | --- |

### Phase 2: Protocol & Adapter Gateway (Days 3-6 | by 2026-04-06)

| Task ID | Workstream | Task | Owner | Status | Priority | Prerequisites | Blocking |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TASK-101 | WS-101 | Introduce MessagePersistence protocol and default adapter | `@backend-lead` | Complete | High | TASK-108 ✅ | TASK-102 |
| TASK-104 | WS-102 | Move apply/validation flow from view model to orchestrator | `@frontend-developer` | In Progress | High | TASK-103 ✅ | TASK-109 |
| TASK-109 | WS-105 | Add article edit round-trip and operation validation tests | `@frontend-tester` | In Progress | High | TASK-104 (In Progress) | --- |

### Phase 3: Implementation & Stability (Days 6-9 | by 2026-04-09)

| Task ID | Workstream | Task | Owner | Status | Priority | Prerequisites |
| --- | --- | --- | --- | --- | --- | --- |
| TASK-102 | WS-101 | Rewire StreamingService to persistence adapter behind flag | `@backend-developer` | In Progress | High | TASK-101 ✅, TASK-108 ✅ |
| TASK-105 | WS-103 | Patch Anthropic API version handling and error mapping | `@backend-developer` | Review | Medium | TASK-101 ✅ |
| TASK-106 | WS-103 | Fix Ollama cancel and Ollama-only search failure handling | `@backend-lead` | Review | High | TASK-101 ✅ |

### Completed Work

| Task ID | Workstream | Task | Owner | Status | Priority |
| --- | --- | --- | --- | --- | --- |
| TASK-001 | WS-001 | Publish sprint folder structure and templates | `@product-manager` | Complete | High |
| TASK-002 | WS-001 | Validate architecture contract alignment in templates | `@architect` | Complete | High |
| TASK-110 | WS-106 | Replace risk table with scored register and escalation SLA | `@qa-lead` | Complete | Medium |
| TASK-111 | WS-106 | Resolve open sprint decisions and unblock WS-103/WS-104 | `@cto` | Complete | High |
| TASK-112 | WS-106 | Issue CTO final decision lock and execution authorization | `@cto` | Complete | High |

## Status Values

- Planned
- In Progress
- Blocked
- Review
- Complete
