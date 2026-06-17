# Going public — pre-publish checklist (PASSED, repo is public)

This repo went public on 2026-06-18 after passing every check below (gitleaks
over full history clean, coupling scan clean, attribution + license present).
Kept as the record + a reusable checklist for the next repo.

## Review before flipping

- [ ] **Secrets** — `gitleaks detect` clean; no tokens, keys, `.env` committed.
- [ ] **Coupling scan** — no private names left: `grep -rinwE "blackrack|openclaw|clawhub|kommit|sunset|elaad|snhq|/home/node" . --exclude-dir=.git` returns only author attribution.
- [ ] **Attribution complete** — `ATTRIBUTION.md` credits every adapted source (ECC, etc.); licenses compatible (all MIT).
- [ ] **No employer/client IP** — nothing from Sunset/Very/Kommit work in the skills or examples.
- [ ] **README is the portfolio front door** — thesis, diagram, "what this demonstrates", links to `WRITEUP.md` and `evals/`.
- [ ] **Evals have real numbers** — run `node evals/run.mjs` and the PROTOCOL once; paste results so the claims are backed.
- [ ] **LICENSE** present (MIT) and author correct.

## Flip

```bash
gh repo edit LFTPadilla/agent-dev-kit --visibility public --accept-visibility-change-consequences
# discoverability:
gh repo edit LFTPadilla/agent-dev-kit --add-topic claude-code,ai-agents,developer-tools,llm,code-review
```

Then: add a social-preview image in repo settings, and pin it on your GitHub
profile. Consider posting the `WRITEUP.md` as a short blog/LinkedIn note linking
back — that's what actually reaches recruiters.

## Decision still open

Whether to go public at all, and when. Documented here for review — not executed.
