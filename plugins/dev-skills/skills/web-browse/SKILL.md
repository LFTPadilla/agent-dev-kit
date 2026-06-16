---
name: web-browse
tags: ['skill']
description: Navigate websites and interact with web pages as a human user. Use when needing to browse, scrape, extract data from, or interact with websites that require real browser behavior (login flows, dynamic content, CAPTCHAs, bot detection, etc.). Triggers on phrases like "browse to", "go to website", "open webpage", "check the page", "extract from", "login to", "navigate to", or any task requiring real web interaction with a browser.
---

# Web Browse Skill

Use the `browser` tool to navigate web pages as a real user.

## Mandatory execution rule

Use this skill only when normal `brave-search` is insufficient: login flows, dynamic pages, forms, buttons, CAPTCHAs, dashboards, or explicit requests to open/navigate a site. For ordinary web search, use `brave-search` first. Do not tell the user web access is unavailable just because browser interaction is not needed.

## Setup

Browser is already configured on Argo:
- Chromium at `/usr/bin/chromium` (no sandbox, host mode)
- CDP port: 18800

## Browser Tool Quick Reference

| Action | When to use |
|--------|-------------|
| `browser(action="open", url="...")` | Navigate to URL |
| `browser(action="snapshot", targetId="...")` | Get page structure (aria refs) |
| `browser(action="screenshot", targetId="...")` | Visual screenshot |
| `browser(action="act", targetId="...", request={kind:"click", ref:"..."})` | Click element |
| `browser(action="act", targetId="...", request={kind:"type", ref:"...", text:"..."})` | Type in input |
| `browser(action="act", targetId="...", request={kind:"press", key:"Enter"})` | Press key |

## Workflow

1. **Open** the URL with `browser(action="open", target="host", url="...")`
2. **Snapshot** to see page structure and get element refs
3. **Act** to interact (click, type, scroll, hover)
4. **Repeat** until task is done
5. **Close** the browser when done

## Common Patterns

### Login to a site
```
open → snapshot → find login fields → type credentials → click submit → verify
```

### Extract data from a page
```
open → snapshot → identify data elements → act to expand/scroll if needed → snapshot → extract
```

### Click through a flow
```
open → snapshot → click button → wait for navigation → snapshot → click next → ...
```

## Tips

- Use `compact=true` in snapshot for fewer nodes
- Use `refs="aria"` to get stable aria refs for act targets
- If a page doesn't load, try adding `timeMs=2000` to act for wait
- For pages requiring user interaction, use `screenshot` to see what the agent sees
- Headless mode: add `headless=true` to open if you don't want visible browser
- Keep browser open between related actions to avoid re-authenticating
