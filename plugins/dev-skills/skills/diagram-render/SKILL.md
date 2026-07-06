---
name: diagram-render
tags: ['skill']
description: 'Renders network diagrams, flowcharts, and infrastructure diagrams as PNG images using SVG generation and sharp. Use when the agent needs to output a network diagram, system architecture, flowchart, or infrastructure map as a viewable image. Triggers on: "make a diagram", "render this network", "show infrastructure as image", "draw topology", "create flowchart", "generate diagram".'
---

# Diagram Render 🔧

Renders network diagrams, flowcharts, and infrastructure visualizations as PNG images using SVG + sharp.

## Location

The render script lives in the **same skill folder** as this SKILL.md:

```
<skill_folder>/
├── SKILL.md
└── scripts/
    └── diagram-render.js
```

## When to Use

- User asks to "make a diagram", "render this network", "show infrastructure as image"
- System architecture, network topology, or flowchart needs to be visualized
- Infrastructure documentation that would look better as an image than ASCII art

## How It Works

The script takes two arguments:
- `--nodes` — newline-separated node definitions: `ID|LABEL|TYPE|COL|ROW`
- `--conns` — newline-separated connections: `FROM|TO|LABEL|COLOR`
- `--title` — diagram title

Node types: `lan`, `cloud`, `cluster`, `server`, `vm`, `pbs`, `tailscale`
Colors: hex color like `#E74C3C` for red, `#27AE60` for green, etc.

## Example

```bash
node <skill_folder>/scripts/diagram-render.js \
  --nodes 'LAN|Local Network|lan|0|0
host-a|Server A|server|1|0
host-b|Server B|server|2|0
store|Backup Store|pbs|3|0
worker-1|VM Worker-1|vm|1|1
worker-2|VM Worker-2|vm|1|2' \
  --conns 'LAN|host-a|SSH|#E74C3C
LAN|host-b|SSH|#E74C3C
host-a|host-b|Cluster LAN|#9B59B6
host-b|store|Backup|#E74C3C' \
  --title 'Example Cluster + Backup Store'
```

Output: JSON with `svg` and `png` paths.

## Workflow

1. Parse the user's diagram request
2. Define nodes (servers, VMs, networks) and connections
3. Run the script → gets SVG + PNG paths
4. Send image via message tool: `action=send, path=<png_path>`
5. Plain text explanation after the image