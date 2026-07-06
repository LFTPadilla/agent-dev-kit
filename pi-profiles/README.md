# Pi Profiles

Reusable Pi delegation profiles for agent-dev-kit.

These profiles are public-safe presets. They describe how a primary agent can
delegate bounded work to Pi without leaking private context or granting
unnecessary permissions.

## Files

| File | Purpose |
| --- | --- |
| `profiles.yaml` | Canonical Pi profile definitions. |
| `package-matrix.md` | Package-to-profile routing matrix. |
| `pilot-plan.md` | Safe adoption sequence before using Pi in real projects. |
| `settings.example.json` | Example project-local `.pi/settings.json` skeleton. |

## Safety Position

- Start read-only.
- Use disposable workspaces for package experiments.
- Do not pass secrets, customer data, production credentials, or private
  incident reports to delegated profiles.
- Promote a profile to write-capable only for a named task with explicit user
  approval.

## First Pilot

```bash
pi -e npm:@bacnh85/pi-serena \
   -e npm:@bacnh85/pi-plan \
   --print "Review this repository for structural risks. Return findings only."
```
