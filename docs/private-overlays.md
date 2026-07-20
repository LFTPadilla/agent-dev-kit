# Private overlays

This is **Tier C** of the cold-clone path: optional, never assumed on a fresh
clone. Tiers A (kit only) and B (Agent Tutor Orchestrator with public skills)
are documented in [README](../README.md#install--cold-clone-tiers) and
[agent-tutor-orchestrator.md](agent-tutor-orchestrator.md).

This repository is public-safe. Organization-specific material belongs in a
**private org skills registry** (or a private project directory) **outside this git
tree**. Compose at install or profile-setup time; never bake employer or client
identity into the public kit.

## What stays out of this public kit

1. Customer names, company names, internal product names, private hostnames, IPs,
   cluster namespaces, credentials, billing details, or incident reports.
2. Project-specific runbooks that include connection strings or production commands.
3. Agent profiles that assume access to private systems.
4. Real machine paths to private registries or employer workspaces.

In public docs, use only generic language: “private org skills overlay”,
“employer-local skills registry”, “optional private profile clone source”.

## Composition model

```text
agent-dev-kit (public)
        │
        │  install / symlink / AGENT_TUTOR_CLONE_FROM (optional)
        ▼
Hermes profile agent-tutor-orchestrator
        │
        │  link skills from private registry if present
        ▼
private org skills registry (outside this repo)
```

1. **Public kit** supplies reusable machinery: validation, provenance, generic
   profiles (including Agent Tutor Orchestrator), sandbox policy contracts, evals, and
   generalist skills.
2. **Private org skills registry** supplies policy, internal examples, approved
   tools/models, QA evidence rules, and org-only skills.
3. **Project overlay** (each application repo) supplies local facts:
   `CLAUDE.md` / `AGENTS.md`, repo-local skills, hooks, and domain commands.

Agent Tutor Orchestrator is intentionally a **generalist pure orchestrator**. Org flavor is
added by composing overlays elsewhere, not by forking the public profile.

## Recommended private registry layout

```text
private-agent-pack/
├── README.md
├── profiles/
│   ├── sre-diagnose.yml
│   ├── support-triage.yml
│   └── operator-confirmed.yml
├── policies/
│   └── production-sandbox.json
├── skills/
│   └── <private-skill>/SKILL.md
└── references/
    └── connection-map.md
```

Names above are placeholders. Use whatever naming your org prefers; keep that
naming out of this public repository.

## How to compose with Agent Tutor Orchestrator

Typical operator flow (paths and registry names are local to your machine):

1. Install the public tutor profile (`scripts/tutor-install.sh` then `scripts/tutor-doctor.sh`).
2. Optionally clone non-secret defaults from another Hermes profile via
   `AGENT_TUTOR_CLONE_FROM` or `--clone-from` (no company default in this kit).
3. Symlink or install skills from your private org skills registry into the
   tutor profile’s skills directory if present (skills under
   `requires_private_overlay` in `profiles/agent-tutor-orchestrator.yml`).
4. Keep worklogs under the tutor profile (or `AGENT_TUTOR_WORKLOG_DIR`).
5. Never commit the private registry into this public tree.

The public profile notes the same contract: link a private org skills overlay
separately; do not bake employer-specific content into the public manifest.

## Layering summary

| Layer | Location | Contents | Update owner |
| --- | --- | --- | --- |
| Public kit | this repo | generic phases, safety rules, installer, templates, Agent Tutor Orchestrator | public maintainers |
| Org overlay | private skills registry (outside this repo) | policies, approved tools/models, QA rules, internal examples | organization |
| Project overlay | each project repo | project instructions, local skills/agents/hooks, domain context | project team |

This separation prevents context bleed: the public tutor teaches the method, the
org overlay adds policy, and the project overlay adds only local facts.
