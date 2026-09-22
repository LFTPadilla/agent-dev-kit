# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.13.1] - 2026-09-21

### Added
- `validate` checks `REGISTRY.yaml` against the skills on disk: it fails on a missing skill, a stale skill, or a path that points at the wrong directory
- Agent harness availability checker (`scripts/check-agent-harnesses.py`) with its `test:check-agent-harnesses` contract suite
- `docs/browserskill.md` documents driving a local, logged-in Chromium and the local CLI evaluation

### Fixed
- `REGISTRY.yaml` now catalogs all 28 shipped skills; it listed 10 and dropped the other 18
- `REGISTRY.yaml` now lists all 6 shipped profiles; it listed 1
- Public counts unified at 28 skills and 6 profiles, replacing the stale "25 skills" and "profiles-7" claims in the README badge, README tier table, WRITEUP, and docs index

## [Unreleased]

### Added
- `classifier-policy` skill: a declarative task-class → harness, model tier, and reasoning effort policy, a schema, two example policies, and a checker (`scripts/check-classifier-policy.mjs`) that never calls a remote service
- `test:classifier-policy` contract suite; it asserts the shipped examples pass and that the checker rejects seven defect classes
- Opt-in Jev Review wiring (`scripts/install-jev-review.sh`) for Hermes and Codex
- `docs/jev/` as the single source of truth for the Jev Review loop, install, and harness map

## [0.13.0] - 2026-08-17

### Added
- Editorial kit architecture diagram (HTML source) and refreshed README hero with a real stack diagram, CI, and measured eval results
- Personal Dev Tutor architecture redesigned with an editorial diagram-design overview; the HTML source replaces the D2 diagram
- `validate` verifies profile skill lists resolve and stay in sync across manifests and shell constants
- `validate` guards against re-vendoring third-party skills under `.agents/`
- CI runs every `test:*` contract suite, discovered from package.json, and declares the runner tools they need
- Optional remote-session browser rung for live QA
- CONTRIBUTING.md and SECURITY.md, including private vulnerability reporting
- Social preview image regenerated from the editorial kit diagram
- Codex CLI model delegation fallback

### Fixed
- Personal Dev Tutor contract test now targets the new diagram source, fixing the failing CI contract-tests step
- Bubblewrap sandbox containment assertions now actually execute in CI, with a visible SKIP fallback
- `validate` no longer asserts Pi research prose wording (inertness asserts kept)
- Hermes workhorse link-signal window and override pairing hardened
- Tutor scripts work when invoked with relative paths

### Changed
- Third-party agent skills no longer vendored under `.agents/`; upstream licenses recorded for the 17 pinned skills
- Scripts resolve the user home through one shared helper with a single documented precedence; python3 no longer needed for path canonicalization
- `validate` prints one summary per command
- website/ and its deploy workflow removed from the public repo

### Docs
- README rebuilt around a real stack diagram, CI, and measured evals
- Presentation surface polished: CONTRIBUTING/SECURITY, .gitignore updates, docs-index diagram fixes, profiles-7 badge
- Codex skill installation aligned for CLI and overnight runtimes

### Chore
- Behavior-preserving cleanup series (gnhf 1–162) across validators, tutor scripts, workhorse installers, and test harnesses
- CI actions bumped past the Node 20 deprecation
- Earlier groundwork: initial shareable kit (v0.7.0), evals harness with measured results, vendored drawio and audit-and-plan skills, and completed going-public checklist
