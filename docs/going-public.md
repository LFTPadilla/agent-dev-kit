# Going public — pre-publish checklist (PASSED)

This repo went public on 2026-06-18 after passing every check below (gitleaks
over full history clean, coupling scan clean, attribution + license present).
Kept as the record + a reusable checklist for the next repo.

**Status:** public. The checklist below is the historical gate that was satisfied
before the visibility flip, and remains the template for future public releases
from this authoring pattern.

## Review before flipping

- [x] **Secrets** — `gitleaks detect` clean; no tokens, keys, `.env` committed.
- [x] **Coupling scan** — no private organization names, hostnames, IPs, customer names, or project paths remain in tracked files.
- [x] **Attribution complete** — `ATTRIBUTION.md` credits every adapted source (ECC, etc.); licenses compatible (all MIT).
- [x] **No employer/client IP** — nothing from employer/client names or private work in the skills or examples. Use only generic language for overlays ("private org skills registry", "employer-local skills").
- [x] **README is the portfolio front door** — thesis, diagram, "what this demonstrates", links to `WRITEUP.md` and `evals/`.
- [x] **Evals have real numbers** — PROTOCOL has semgrep + LLM single-pass smoke (2026-06-18), `/pr-review` protocol smoke 01–05, and protocol batch 06–15 (2026-07-20) → combined **12/12** recall, **0/3** FP. Live `/pr-review` Workflow against a GitHub PR still open; keep that gap labeled.
- [x] **LICENSE** present (MIT) and author correct.

## Flip (already executed for this repo)

```bash
gh repo edit LFTPadilla/agent-dev-kit --visibility public --accept-visibility-change-consequences
# discoverability:
gh repo edit LFTPadilla/agent-dev-kit --add-topic claude-code,ai-agents,developer-tools,llm,code-review
```

Then: add a social-preview image in repo settings, and pin it on your GitHub
profile. Consider posting the `WRITEUP.md` as a short blog/LinkedIn note linking
back — that's what actually reaches recruiters.

## Ongoing hygiene

Re-run the coupling scan before major public updates. Never reintroduce
employer/client names, private paths, or employer-named session/profile
defaults into tracked files. Private context stays in overlays outside this
repo ([private-overlays.md](private-overlays.md)).
