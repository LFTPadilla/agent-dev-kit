---
name: knip
description: Find dead code, unused files, unused exports, and unused dependencies in a JavaScript/TypeScript project using knip. Use before a refactor, before a PR, or when the user asks to clean up bloat, remove unused deps, or shrink the codebase.
---

# knip — dead code & unused dependency finder

Knip traces the whole project (not one file at a time) to find what nothing
references: unused files, exports, types, and dependencies. This is the
mechanical version of "delete code you don't need."

## Run

```bash
npx knip                  # report unused files, exports, deps, types
npx knip --production     # only production code paths (ignore tests/dev)
npx knip --dependencies   # just unused/unlisted dependencies
npx knip --fix            # auto-remove unused exports/files (review the diff!)
```

Zero-config for most setups — knip reads `package.json` + `tsconfig.json` and
has built-in plugins for Vite, Vitest, Next, ESLint, etc. Add a `knip.json`
only if entry points are non-standard.

## How to use the output

1. Run `npx knip`. Group findings: unused files / exports / deps / types.
2. **Verify before deleting** — knip can flag things reached only by dynamic
   import, config strings, or framework conventions. Confirm each is truly dead.
3. Remove in small commits (files, then exports, then deps). Re-run knip after.
4. `--fix` is safe for clearly-unused exports/files, but read the diff — never
   blind-apply on auth, migration, or public-API code.

## Gotchas

- Monorepo: run per-workspace or configure `workspaces` in `knip.json`.
- Entry points it can't infer (CLI bins, serverless handlers) → list them in
  `knip.json` so it doesn't report them as unused.
- Pairs well as a pre-commit gate (warn, don't block) and before any refactor.
