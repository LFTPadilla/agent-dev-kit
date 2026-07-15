# Lane prompt for hermes-tutor delegation

You are working inside a worktree delegated by the Hermes Workflow Tutor. Read
the precondition check below BEFORE doing anything. If anything does not match,
STOP and report — do not improvise around it.

## Precondition (run first)

```bash
cd <REPO_ABS_PATH>
git rev-parse --abbrev-ref HEAD
```

Expected branch: `<BRANCH_EXPECTED>`

If the branch is anything else (especially a worktree sibling like
`feat/some-other-pr`), STOP and report. Worktree-sibling files can shadow
your target even when the path is correct.

## Working directory

`<WORKTREE_PATH>`

## Goal

<GOAL_PARAGRAPH>

## Acceptance criteria

Number each one. The auditor will grade you against this list exactly.

1. <AC1>
2. <AC2>
3. <AC3>

## Allowed files

You may ONLY modify the files below. Touching anything else is grounds for
rejection.

- <ALLOWED_FILE_1>
- <ALLOWED_FILE_2>

## Forbidden actions

- Do NOT commit, push, or open a PR.
- Do NOT touch secrets, `.env`, or credentials.
- Do NOT modify `<FORBIDDEN_FILE_1>`.
- Do NOT change branch.

## Skills to load

<SKILL_HINTS>

## Steps

1. Read the relevant files first; do not guess.
2. Make the smallest change that satisfies the acceptance criteria.
3. Run the project's test suite if available.
4. Self-audit against each acceptance criterion.
5. Report back with a clean summary (see Output format).

## Output format

Reply in plain text with these sections:

```
STATUS:           APTO PARA REVIEW | NECESITA CORRECCIONES
FILES_CHANGED:    <list, one per line>
COMMANDS_RUN:     <list, one per line>
TESTS:            <test name>: <pass/fail>  (one per line)
DECISIONS:        <short rationale for non-obvious choices>
RISKS:            <what might still be wrong>
NEXT_ACTIONS:     <what the auditor should check>
```

## Verification expectation

The Hermes Workflow Tutor will independently verify this work by running
`git status --short`, `git diff --stat`, and re-reading the diff against the
acceptance criteria above. Self-reports are not trusted. Do not modify files
outside the allowlist.

## Context

<USER_CONTEXT>