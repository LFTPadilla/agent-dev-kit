# Private Overlays

This repository is public-safe. Organization-specific material belongs in a
private overlay repository or a private project directory.

Keep out of this public kit:

- Customer names, company names, internal product names, private hostnames, IPs,
  cluster namespaces, credentials, billing details, or incident reports.
- Project-specific runbooks that include connection strings or production
  commands.
- Agent profiles that assume access to private systems.

Recommended layout for a private overlay:

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

The public kit supplies reusable machinery: validation, provenance, profiles,
sandbox policy contracts, evals, and generic skills. The private overlay supplies
context.
