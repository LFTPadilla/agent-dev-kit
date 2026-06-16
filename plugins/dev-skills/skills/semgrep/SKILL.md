---
name: semgrep
description: Run static analysis (SAST) over the codebase with semgrep to find real bug and security patterns — injection, auth gaps, secret handling, dangerous APIs. Use before a security-sensitive PR, on auth/payment/data-handling code, or when the user asks for a deterministic security scan.
---

# semgrep — static analysis / SAST

Pattern-based static analysis. Deterministic, fast, rule-driven — the
complement to an LLM security review: semgrep never misses a known pattern,
the LLM reasons about novel ones. Run both.

## Run

```bash
semgrep --config auto                 # auto-select rules for the detected languages
semgrep --config p/typescript         # registry rule pack (TS)
semgrep --config p/javascript
semgrep --config p/owasp-top-ten      # OWASP Top 10 patterns
semgrep --config p/secrets            # hardcoded secrets
semgrep --config p/nodejs-scan        # Node-specific
semgrep --config auto --json          # machine-readable for processing
```

Scope to a diff for speed:
```bash
semgrep --config auto $(git diff --name-only --diff-filter=ACM main)
```

Install: `pipx install semgrep` (or `brew install semgrep`). No global install? `pipx run semgrep ...`.

## How to use the output

1. Pick rule packs by the code under review — `p/owasp-top-ten` + `p/secrets`
   for auth/payment surfaces; `p/typescript` for general correctness.
2. Triage findings by severity. Confirm each against the real code — semgrep
   patterns can false-positive on guarded paths.
3. For a PR, scan only the diff (above) to keep it fast.
4. Report: rule id, file:line, why it matters, fix. Don't auto-apply on
   security code without confirmation.

## Gotchas

- `--config auto` phones the registry; for offline/CI pin explicit `p/...` packs.
- Custom rules go in `.semgrep.yml` — but prefer registry packs first (YAGNI).
- Pairs with the `security-review` skill: semgrep catches known patterns, the
  review reasons about the rest.
