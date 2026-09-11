---
name: explain-concept
tags: ['skill']
description: 'Routes any "make this understandable" request to the right explanation medium: a rendered PNG diagram, an editable draw.io file, a narrated explainer video, or a text trail of file:line stops. Use when someone must understand a ticket, a bug, an architecture, or a data flow and the medium is not decided yet. Triggers on: "explain this ticket", "explain this concept", "help the team understand X", "make this understandable", "how do I explain this".'
---

# Explain Concept 🧭

Umbrella router. It does not render anything. It picks the medium, hands off to
one skill, and records what was learned.

## When to use

- A request names an audience but not a format ("help the team understand the
  retry logic").
- A ticket, a bug, or a design must be explained to somebody who did not write it.
- You are about to write three paragraphs of prose about a structure. Stop and route.

Do not use it when the user already named the medium. Call that skill directly.

## Step 1 — Clarify in ONE question

Ask one question only, and only if the answer is not already obvious:

> Who is this for, and how will they receive it (image, editable file, or video)?

If the request already names an audience and a medium, skip the question.

## Step 2 — Route

| Signal in the request | Route to | Output |
|---|---|---|
| Quick topology, flow, or architecture picture; paste into chat or a PR | `diagram-render` | PNG |
| The reader must edit it, restyle it, or export SVG/PDF; swimlanes, UML, ER | `drawio-skill` | `.drawio` + export |
| Narrated walkthrough, async share, non-technical audience, onboarding | `explainer-video` | `videos/<slug>/renders/video.mp4` |
| No image is possible or wanted; the reader will read the code | text trail | ordered `file:line` list |

Rules for the routes:

- **diagram-render** — the picture is static and the reader only looks at it.
- **drawio-skill** — the picture has a second life: somebody changes it later.
- **explainer-video** — timing matters. The reader needs the order of events
  spoken, not inferred. Example: a webhook race bug where two handlers write the
  same row.
- **text trail** — the fallback. Give an ordered list of `file:line` stops, one
  sentence per stop on what to notice, and 5 lines of summary at most. Do not
  paraphrase the code.

Pick one route. Do not produce two mediums for the same request unless the user
asks for both.

## Step 3 — Always record lessons

After the chosen skill finishes, append one line to that skill's
`references/lessons.md` if anything was learned:

```
- YYYY-MM-DD: <what broke or surprised you> → <what to do next time>
```

Skip the append only when nothing new happened. The kit improves by iteration,
so a dated one-line lesson is worth more than a clean run with no record.
