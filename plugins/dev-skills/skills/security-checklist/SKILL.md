---
name: security-checklist
description: A pattern → severity → fix checklist for reviewing security-sensitive code (auth, payments, user input, file uploads, webhooks). Use as the LLM-reasoning complement to a deterministic SAST scan — semgrep catches known patterns, this catches the contextual ones. Run on any diff touching a trust boundary.
---

# security-checklist — pattern review for trust boundaries

The reasoning layer of security review. Pair with the `semgrep` skill: semgrep
is deterministic (never misses a known pattern), this catches the contextual
issues a static rule can't see. Adapted from ECC (github.com/affaan-m/ECC), MIT
— see [ATTRIBUTION.md](../../../../ATTRIBUTION.md).

## Flag-on-sight table

| Pattern | Severity | Fix |
|---|---|---|
| Hardcoded secret / key / token | CRITICAL | `process.env`, rotate if committed |
| String-concatenated SQL | CRITICAL | Parameterized query / `$1` placeholders |
| Shell command with user input | CRITICAL | `execFile` / arg arrays, never string interp |
| Plaintext password compare | CRITICAL | `bcrypt.compare` / argon2 |
| No auth check on protected route | CRITICAL | Auth middleware; verify per-route |
| Balance/quota check without lock | CRITICAL | `SELECT ... FOR UPDATE` in a transaction |
| `innerHTML = userInput` | HIGH | `textContent` or DOMPurify |
| `fetch(userProvidedUrl)` (SSRF) | HIGH | Allowlist hosts; block internal IPs |
| Cross-tenant / cross-user access | HIGH | Scope every query by owner id |
| Error detail leaked to client | MEDIUM | Generic message out, detail to logs only |
| Secret / PII in logs or Sentry | MEDIUM | Redact before logging |
| No rate limit on public endpoint | HIGH | Throttle (per-IP / per-user) |

## Process

1. Scope to the diff at a trust boundary (auth, payments, input, uploads, webhooks).
2. Walk the table; for each hit cite `file:line`, the trigger, and the fix.
3. Cross-check with `semgrep --config p/owasp-top-ten p/secrets` — deterministic backstop.
4. Backend-first: a security gap fixed only in the frontend is still open — flag until the server enforces it.

## Skip these (common false positives)

- Vars in `.env.example` — placeholders, not secrets.
- Test credentials clearly inside test files.
- Keys meant to be public (publishable client keys).
- SHA256/MD5 used for checksums, not passwords.
- `Math.random()` in non-crypto contexts (animation, jitter, sampling).

**Verify context before flagging.** A finding without a concrete trigger is noise.
