# BrowserSkill: drive your own Chromium from the agent's shell

[BrowserSkill](https://github.com/Tencent/BrowserSkill) is a local bridge between
an agent harness and a real Chromium browser. Tencent publishes it under the MIT
license.

The agent never talks to the browser directly. It runs `bsk` in a shell. The CLI
sends the request to a local daemon. The daemon sends it to a browser extension
over a WebSocket on `127.0.0.1`. The extension drives a separate **Agent Window**
inside your browser profile.

## What it is

It is not an MCP server. It is a CLI plus an extension plus a skill file.

| Part | Type | Runtime |
|---|---|---|
| `bsk` | Rust CLI and local daemon | Static binary. No Node or Python needed. |
| BrowserSkill extension | Chrome/Edge MV3 extension | Chrome or Edge 125 or later |
| `skill/SKILL.md` | Agent skill | Any harness that can call a shell |
| `@wxg-prc-cpg/browser-skill-dsh-plugin` | npm plugin | DeepSeek Harness only |

Supported hosts: macOS, Linux (x64 and ARM64), Windows x64. Firefox is not
supported.

## Install (verified on Ubuntu 26.04, x86_64)

### 1. Install the CLI

```bash
curl -fsSL https://raw.githubusercontent.com/Tencent/BrowserSkill/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
bsk --version    # -> bsk 0.2.1
```

This worked without changes. The installer verifies a checksum and writes one
binary to `~/.local/bin/bsk`.

### 2. Start the daemon

```bash
bsk doctor
```

`doctor` starts the daemon on first run. It reported `daemon running` and
`protocol compatible`. The daemon survived later shell calls, so no
`BSK_AUTO_START=0` workaround was needed.

### 3. Install the skill

```bash
bsk install-skill --list --json
bsk install-skill --harness claude-code --json
```

This wrote `~/.claude/skills/browser-skill/SKILL.md`. The harness detected the
`browser-skill` skill in the next session.

### 4. Connect the extension

This is the step that needs a human. See the next section.

## The extension is the blocker

`bsk doctor` fails with `extension connected — 0 browsers connected` until a
browser loads the extension. Two paths exist, and both have a cost.

| Path | Result |
|---|---|
| Chrome Web Store / Edge Add-ons | Works. A human must click **Add to Chrome**. An agent cannot do this. |
| `--load-extension` on Chrome stable | **Fails.** Chrome 137 and later ignore the switch. Verified on Chrome 151. |

Chrome 151 ignored `--load-extension` in three attempts: plain, with
`--disable-features=DisableLoadExtensionCommandLineSwitch`, and with
`--disable-extensions-except` plus developer mode in the profile.

The working unattended path uses **Chrome for Testing**, which keeps the switch:

```bash
npx -y @puppeteer/browsers install chrome@stable --path "$PWD/cft"
curl -fsSLO https://github.com/Tencent/BrowserSkill/releases/download/ext-v0.2.1/browser-skill-extension-v0.2.1-chrome.zip
unzip -q browser-skill-extension-v0.2.1-chrome.zip -d bsk-ext

"$PWD/cft/chrome/linux-<version>/chrome-linux64/chrome" \
  --no-sandbox \
  --user-data-dir="$PWD/cft-profile" \
  --load-extension="$PWD/bsk-ext" \
  --no-first-run --no-default-browser-check about:blank &

bsk doctor    # -> ok  extension connected  1 browser(s) connected
```

Match the extension release to the CLI release. `--no-sandbox` is required
because Ubuntu 26.04 restricts unprivileged user namespaces.

This path gives a throwaway profile, not your logged-in profile. To get real
login state, a human must install the extension from the store into the everyday
browser profile.

## Verified usage example

Every command below ran against `https://example.com`, a neutral public page.

```bash
bsk session start --no-focus --json      # -> {"session_id":"hmos", ...}
bsk navigate https://example.com --session hmos
bsk observe --session hmos
bsk screenshot --session hmos --out shot.png
bsk click @e1 --session hmos
bsk session stop hmos
```

`observe` returned a semantic tree with stable `@eN` refs:

```text
@vom 1
@view 1241x1252
@layers 1 focus=L1
L1 page
  RootWebArea "Example Domain"
    heading "Example Domain"
    paragraph "This domain is for use in documentation examples..."
    paragraph
      @e1 link "Learn more" [→ iana.org]
```

`click @e1` returned `click ok tab=... target=@e1 at=(289, 277)`. The next
`observe` showed `RootWebArea "Example Domains"`, so the click navigated.
`screenshot` wrote an 18 KB PNG of 1241x1252 pixels to disk.

All four required operations passed: open a page, read text, take a screenshot,
click an element.

### Command surface

`bsk` exposes 30 subcommands. The main ones are `session`, `navigate`, `observe`,
`snapshot`, `get-html`, `click`, `fill`, `select`, `press`, `hover`, `scroll-to`,
`screenshot`, `console`, `network`, `evaluate`, `download`, `upload`,
`request-help`, and `record`.

## Known limits

1. A human must install the extension for the everyday browser profile. No agent
   can complete that step.
2. Headless operation is not a design goal. The extension needs a running
   Chromium with a window and a display.
3. The CLI release lags the repository. `main` documents version 0.3.0 and
   protocol 1.3. The latest published CLI is 0.2.1 with protocol 1.1.
   `request-help` needs protocol 1.3, so it is unavailable on 0.2.1.
4. The extension asks for `<all_urls>` host access and the `debugger` permission.
   In your everyday profile it can reach every site you are signed into.
5. Sandboxes that kill background children after each command need a host-managed
   daemon, a shared `BSK_HOME`, and `BSK_AUTO_START=0` on every call.
6. `bsk install-skill` writes into the harness home, for example
   `~/.claude/skills/`. It is not a per-repository install.
7. Firefox is not supported. Chromium forks work only when they still load
   unpacked extensions.

## BrowserSkill against browser-lab

| Axis | BrowserSkill | browser-lab |
|---|---|---|
| Control model | Deterministic. One CLI command per action. `@eN` refs come from `observe`. | Two modes. `bu_sh_run_task` takes natural language. `bu_sh_session_action` is deterministic. |
| Reliability | Every command returned a clear `ok` or an error in this test. | The natural-language task agent stalls at 0 steps. The deterministic mode needs manual DOM work. |
| Execution site | Local. Daemon and browser run on your machine. | Remote. A Kubernetes pod runs the browser. |
| Local Chrome profile | Yes, by design. The extension runs in your profile and reuses live logins. | No. The pod has its own profile. Auth state must be explicit and disposable. |
| Screenshots | Written to a local file path. The image never enters the context by default. | Returned through an MCP tool result. |
| Token cost | Low. `observe` on `example.com` cost about 10 lines. A dense page cost about 11 KB. | Higher. MCP tool schemas and results stay in context for the whole session. |
| Setup effort | CLI install is one command. The extension needs one human click, or the Chrome for Testing workaround. | MCP server config plus a reachable remote pod. |
| Transport | Shell. Any harness that can run a command. | MCP. Only harnesses with an MCP client. |
| Interface cost | Zero idle tokens. The CLI is invoked on demand. | About 22 tool definitions loaded per session. |

### Recommendation

Adopt BrowserSkill as the default browser rung. Keep `browser-lab` only for work
that must run off this machine.

Three reasons decide it:

1. It is deterministic. Every step is a command with a visible result. No hidden
   agent loop can stall.
2. It costs no idle context. `browser-lab` loads about 22 MCP tool definitions
   into every session that enables it.
3. It runs on the local browser, so an already-signed-in session needs no test
   account.

The cost is the extension. One human click installs it from the Chrome Web Store.
After that click, every later agent run is unattended.

Keep the `browser-lab` remote rung for a browser a human must watch from another
machine, and for any run that must not touch the local profile.

## Safety notes

- Point BrowserSkill at neutral or local targets first. The
  [`browser-lab` sandbox policy](sandbox-policies.md) still applies: no secrets,
  no production, no destructive action without explicit authorization.
- The extension can read every site in the profile it runs in. Do not run agent
  tasks against client systems from a profile that holds client credentials,
  unless the user asks for it in that session.
- The bundled skill tells the agent never to extract credentials, cookies, or
  tokens. Treat that as a floor, not a guarantee.

## Uninstall

```bash
bsk daemon stop
rm -rf ~/.bsk ~/.local/bin/bsk ~/.claude/skills/browser-skill
```

Remove the extension through the browser's extension page.
