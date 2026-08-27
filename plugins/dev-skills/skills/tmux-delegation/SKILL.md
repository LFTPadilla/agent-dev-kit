---
name: tmux-delegation
description: "Delegate tasks to coding agents running in tmux panes across multiple harnesses (Codex, Claude Code, Pi, OpenCode, cursor-agent). Covers pane allocation, reliable multiline buffer injection, harness-specific completion detection, queued inputs, and disk-level diff auditing."
version: 2.0.0
author: agent-dev-kit contributors
license: MIT
metadata:
  tags: [tmux, delegation, multi-harness, codex, claude, pi, opencode, audit]
---

# Multi-Harness tmux Delegation

Manage and delegate tasks to coding agents running inside tmux panes and windows. Designed for orchestrators (like Hermes, OpenCode, Pi, or Tech Lead profiles) that decompose work and delegate execution to bounded workers across diverse CLI harnesses: **Codex CLI**, **Claude Code**, **Pi CLI**, **OpenCode**, **cursor-agent**, or standard shells.

The core rule: **The orchestrator plans, routes, and audits; the worker implements in an isolated tmux pane.**

---

## 1. Pane Selection & Allocation (Anti-Contamination Rule)

**Never reuse a pane that has active context or conversation history from a different task or repository.** Context pollution corrupts reasoning.

### Inventory Existing Panes

```bash
# Check all windows and panes in the session with command, cwd, and alive status
tmux list-panes -t "$TMUX_SESSION" -F \
  '#{window_index}:#{pane_index} #{pane_id} #{pane_current_command} #{pane_dead} #{pane_current_path}'
```

### Pane Selection Matrix

| Pane Condition | Suitable? | Action |
|---|---|---|
| Target harness running, same repo, idle prompt | **YES** | Reset context if needed (`/clear` in Claude/Codex) and proceed. |
| Target harness running, **different** repo | **NO** | Open a new window. Do not contaminate active context. |
| Empty shell (`zsh`/`bash`), same repo | **YES** | Boot the desired agent directly in this pane. |
| Empty shell, different directory | **YES** | `cd /abs/repo/path` then launch agent. |
| All panes occupied or conflicting | **NO** | Spawn a fresh window. |

### Spawning a Fresh Pane

When creating a new window, always specify the absolute working directory:

```bash
# 1. Create window with explicit cwd
tmux new-window -t "$TMUX_SESSION" -n "$TASK_SLUG" -c "$ABS_REPO_PATH"

# 2. Launch the target harness
# Claude Code:
tmux send-keys -t "$TMUX_SESSION:$WINDOW_INDEX" "claude --dangerously-skip-permissions" Enter

# Codex CLI:
tmux send-keys -t "$TMUX_SESSION:$WINDOW_INDEX" "codex" Enter

# Pi CLI:
tmux send-keys -t "$TMUX_SESSION:$WINDOW_INDEX" "pi" Enter

# OpenCode CLI:
tmux send-keys -t "$TMUX_SESSION:$WINDOW_INDEX" "opencode" Enter

# cursor-agent CLI:
tmux send-keys -t "$TMUX_SESSION:$WINDOW_INDEX" "cursor-agent" Enter
```

Allow adequate boot time (10–25 seconds on cold starts) before injecting the first prompt.

---

## 2. Pre-Injection Probe

Before sending instructions, verify that the target pane is alive and ready for input:

```bash
# Verify pane is alive
DEAD=$(tmux display-message -t "$TARGET" -p "#{pane_dead}")
if [ "$DEAD" = "1" ]; then
  echo "Target pane $TARGET is dead; reallocate." >&2
  exit 1
fi

# Dismiss pending modal dialogs or confirm prompts
tmux capture-pane -t "$TARGET" -p | grep -qE 'Enter to continue|Esc to cancel' \
  && { tmux send-keys -t "$TARGET" Escape; sleep 1; }
```

---

## 3. Reliable Multiline Prompt Injection (The 3-Step)

**Never use `send-keys -l` with multi-line or code-containing prompts.** Raw keystroke injection mangles newlines, quotes, backticks, brackets, and environment variables (`$VAR`). Full-screen terminal apps (Ink, Textual, Bubble Tea) require bracketed paste.

### The Robust Protocol

```bash
PROMPT_FILE="/tmp/${TMUX_SESSION}_${TASK_SLUG}_prompt.md"

# 1. Stage prompt in a file with markdown formatting
cat > "$PROMPT_FILE" <<'EOF'
Repo: /absolute/path/to/repo
Branch precondition: check that `git rev-parse --abbrev-ref HEAD` equals feat/my-feature

Task: Implement the user authentication endpoint.

Allowlist:
- src/auth/service.py
- tests/test_auth.py

Rules:
- Do NOT commit, push, or modify files outside the allowlist.
- Return a compact summary: status, files_changed, tests_run, risks.
EOF

# 2. Load into a tmux buffer and paste
tmux load-buffer -b "${TASK_SLUG}_buf" "$PROMPT_FILE"
tmux paste-buffer -b "${TASK_SLUG}_buf" -t "$TARGET"

# 3. Allow TUI bracketed paste to settle (500ms-1000ms), then submit
sleep 1
tmux send-keys -t "$TARGET" Enter
```

---

## 4. Prompt Contract for Workers

Every delegated prompt must be self-contained and enforce strict execution boundaries:

```markdown
Target repo: /absolute/path/to/repo
Precondition: cd /absolute/path/to/repo && test "$(git rev-parse --abbrev-ref HEAD)" = "<expected-branch>"
File allowlist: <file-1>, <file-2> (ONLY modify these files)
Forbidden: Do NOT run git commit, git push, or touch configs outside allowlist.

Acceptance Criteria:
1. <Verifiable criterion 1>
2. <Verifiable criterion 2>

Expected Output:
Report: status, files_changed, tests_run, risks, and next_actions.
```

---

## 5. Monitoring & Completion by Harness

Different CLI harnesses render status and completion differently. Use the matching detection logic:

### Claude Code (`claude`)

- **Busy:** Rotating spinner verbs/characters (`Slithering|Cooking|Pondering|Concocting|Brewed|Hyperspacing|Baked|Sprouting|Flambéing|✢|✶|✻`) or `Running \d+ shell commands`.
- **Idle / Done:** Prompt `❯ *$` returns at the bottom and spinner verbs clear.
- **Dialogs (`AskUserQuestion`):**
  - Option 1 is highlighted by default (`Enter` selects it).
  - Option 2 requires pressing `Down` before `Enter`.
  - Press `Escape` to cancel or dismiss.

```bash
# Wait for Claude turn completion
for i in $(seq 1 60); do
  PANE=$(tmux capture-pane -t "$TARGET" -p -S -5 2>/dev/null)
  echo "$PANE" | grep -qE "Concocting|Cooking|Pondering|Slithering|Brewed|Hyperspacing|Baked|Sprouting|Flambéing|Running [0-9]+ shell" \
    && { sleep 3; continue; }
  echo "$PANE" | tail -10 | grep -q "❯ *$" && break
  sleep 2
done
```

### Codex CLI (`codex`)

- **Busy:** Active turn or subagent processing indicator.
- **Idle / Done:** Command prompt returns (`codex>` or configured shell prompt).
- **Inspection:** Use `tmux capture-pane -t "$TARGET" -p -S -50` to inspect recent lines.

### Pi CLI (`pi`)

- **Busy:** Active token streaming or thinking indicators.
- **Idle / Done:** Pi prompt character returns ready for next turn.

### OpenCode CLI (`opencode`)

- **Busy:** Footer status bar shows active operation or model streaming.
- **Idle / Done:** Input bar is active and responsive.

### Generic Shell / REPL

- **Completion:** Check exit code or prompt symbol (`$`, `#`, `❯`).

---

## 6. Mid-Run Corrections & Queued Delegation

### Delayed Delegation (Queueing)

When you want an agent to process follow-up work immediately after its current task finishes:

```bash
# 1. Load the follow-up prompt into the buffer
tmux load-buffer -b follow_up /tmp/follow_up.md

# 2. Paste WITHOUT pressing Enter
tmux paste-buffer -b follow_up -t "$TARGET"
# The text sits under the prompt box and will automatically execute when the active turn completes.
```

### Cancelling / Interrupting

- Send `Escape` (`tmux send-keys -t "$TARGET" Escape`) to cancel a tool call.
- Send `C-c` (`tmux send-keys -t "$TARGET" C-c`) to interrupt a run.

---

## 7. Post-Delegation Disk Audit Loop

**Never trust the delegate's self-report.** Always independently inspect disk state:

```bash
cd "$ABS_REPO_PATH"

# 1. Check touched files against allowlist
git status --short

# 2. Check diff stat
git diff --stat

# 3. Inspect exact diff
git diff -- <allowlist-files>

# 4. Verify tests independently
npm test / pytest / cargo test / go test
```

Reject any collateral changes (e.g. `.vscode/settings.json`, lockfiles, formatters) before proceeding.

---

## 8. Common Pitfalls & Guardrails

1. **Empty `capture-pane`**: Terminal applications (like Ink) draw on alternate screen buffers. A brief empty capture does not mean the agent crashed; wait for visible output or spinner.
2. **Multi-line Mangling**: Always use `load-buffer` + `paste-buffer`. Do NOT use `send-keys -l` for multiline text.
3. **Pasting Too Fast**: Sleep 500ms–1000ms between `paste-buffer` and `send-keys Enter` so bracketed-paste escape sequences settle.
4. **Concurrent Writes on Same Checkout**: Running two write-workers on the same repository without git worktree isolation causes race conditions and lost work. Always isolate concurrent workers with `.worktrees/<lane>`.
5. **Context Bleed**: A long-running agent pane accumulates conversational drift. Issue `/clear` or allocate a clean window between distinct features.
