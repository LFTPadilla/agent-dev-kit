# Security

This repo is a public kit for directing coding agents. It contains no
production services, credentials, or customer data — but it *is* the kind of
code that teaches agents to handle untrusted input, so vulnerabilities in the
skills, prompts, or scripts still matter.

## Reporting a vulnerability

Please report security issues through **GitHub Private Vulnerability
Reporting** (repo → *Security → Report a vulnerability*) rather than a public
issue, so the report is visible only to the maintainer.

What to include:

- The affected file(s) and a minimal reproduction (a prompt, a skill, or a
  script input that triggers it).
- Impact: what an attacker could do, and under what assumptions (e.g. "an
  agent runs this skill on a malicious PR description").
- Suggested fix, if you have one.

## What we do about it

- Findings are triaged privately and fixed on `main`; a fix is announced in
  the commit/PR that lands it.
- Skills that read untrusted input (diffs, web pages, issues, PR bodies) are
  expected to follow the prompt-injection defense in
  [`docs/prompt-defense.md`](docs/prompt-defense.md) — a skill that doesn't
  is a bug worth reporting.
- Third-party skills are pinned in `skills-lock.json` and restored via the
  skills CLI; update them with the documented flow, never by editing this
  tree's copies.
