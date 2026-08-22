# AGENTS.md — Overnight Task Kit Subsystem Context

> **Progressive Disclosure Context.** Loaded when configuring, running, or extending overnight and long-running autonomous workflows.

---

## 1. Subsystem Scope & Invariants

This subsystem provides protocols, harnesses, and templates for autonomous, long-running agent tasks.

1. **Hard Invariants:**
   - **Protocol, Not Loop:** Treat this kit as protocol specifications and templates, not a monolithic runner.
   - **Isolation First:** Always run tasks in isolated worktrees (e.g. via treehouse or dedicated git worktrees).
   - **Bounded Execution:** Every task specification must declare explicit exit criteria, circuit breakers, and budget caps.

2. **Directory Structure:**
   ```text
   overnight-task-kit/
   ├── docs/                    # Workflow guides and harness research
   ├── scripts/                 # Runner scripts and orchestrators
   ├── skills/                  # Overnight execution and multi-harness skills
   └── install.sh               # Local setup script
   ```

---

## 2. Verification Commands

```bash
# Initialize overnight runner template
node overnight-task-kit/scripts/overnight-runner.mjs init

# Validate multi-harness delegation
python3 overnight-task-kit/skills/multi-harness/scripts/delegate.py --help
```
