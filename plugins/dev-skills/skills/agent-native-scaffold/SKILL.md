---
name: agent-native-scaffold
description: Audit, scaffold, or refactor any software repository into the Agent-Native Repository Architecture (ANRS-1.0) with Hub-and-Spoke context, O(1) REGISTRY.yaml, and shallow directory ergonomics.
tags: [agent-native, architecture, context-engineering, scaffolding, refactor, skill]
metadata:
  openclaw:
    emoji: 🏛️
    scope: developer-tooling
    provenance: first-party
    requires:
      bins: [python3, git]
created: 2026-08-22
updated: 2026-08-22
---

# agent-native-scaffold 🏛️

Transform greenfield or legacy software repositories into high-efficiency **Agent-Native** codebases adhering to the ANRS-1.0 specification.

## When to invoke
- User says: "Make this repo Agent-Native", "Organize this codebase for AI agents", "Audit repository context bloat".
- Initializing a new repository or refactoring a legacy project with bloated root prompts.
- When an AI agent experiences high tool hallucination or context rot.

## When NOT to invoke
- Single-script micro-tools with fewer than 5 files.
- Modifying business logic without changing codebase architecture.

---

## The Transformation Workflow

### Phase 1: Audit & Discovery
Run the ANRS linter to inspect the target repository:
```bash
python3 scripts/audit-agent-native.py --repo-root <TARGET_DIR> --json
```
Analyze:
1. **Context Bloat:** Is root `AGENTS.md` / `CLAUDE.md` > 150 lines?
2. **Catalog Presence:** Is `REGISTRY.yaml` missing?
3. **Directory Depth:** Are there paths nested deeper than 4 levels?

---

### Phase 2: Generate Declarative Catalog (`REGISTRY.yaml`)
Create `REGISTRY.yaml` at the project root by cataloging:
- **Services:** Ports, entrypoints, health check URLs.
- **MCP Servers:** Tool schemas, executable paths, required env vars.
- **Skills:** Custom capabilities and prerequisites.
- **Agents:** Dedicated operational personas.

Use [`templates/agent-native/REGISTRY.yaml.template`](../../../../templates/agent-native/REGISTRY.yaml.template) as baseline.

---

### Phase 3: Construct Hub-and-Spoke Context (`AGENTS.md`)
1. **Root `AGENTS.md` (Hub):**
   - Keep under 120 lines.
   - Encode non-negotiable invariants (Git worktree rules, SSoT for secrets/tasks).
   - Build the **Semantic Routing Table** pointing to subsystem guides.
   - Use [`templates/agent-native/AGENTS.md.template`](../../../../templates/agent-native/AGENTS.md.template).

2. **Subsystem Contexts (Spokes):**
   - Create nested `AGENTS.md` files at each subsystem root (e.g. `services/api/AGENTS.md`, `infra/AGENTS.md`).
   - Move specialized implementation rules out of the root prompt into these spoke files.
   - Use [`templates/agent-native/subsystem-AGENTS.md.template`](../../../../templates/agent-native/subsystem-AGENTS.md.template).

3. **Agent Cognition Isolation:**
   - Place agent system prompts and identities under `agents/<slug>/` or `ops/agents/<slug>/`.
   - Never mix agent behavioral prompts with shared runtime library code.

---

### Phase 4: Flatten Directory Hierarchy
If paths exceed depth 4:
- Flatten redundant wrapper folders (e.g., `src/modules/core/v1/...` → `core/...`).
- If in a live production environment, create relative symlinks (`ln -s`) to maintain backward compatibility during transition.

---

### Phase 5: Verification & Gate
Execute the audit script to ensure compliance:
```bash
python3 scripts/audit-agent-native.py --repo-root <TARGET_DIR>
```
Output receipt must confirm:
- `Root AGENTS.md: Budget and Routing Table OK`
- `REGISTRY.yaml: Present and Formatted`
