---
name: explainer-video
tags: ['skill']
description: 'Produces a narrated faceless explainer video from a concept, a ticket, or a bug write-up using HyperFrames, a voice track, and one worker per frame. Use when the audience is non-technical, remote, or asynchronous, and timing or order of events must be spoken rather than inferred from a static picture. Triggers on: "make a video explaining", "record a walkthrough", "explainer video", "narrated explanation", "video for the team".'
---

# Explainer Video 🎬

Turns a written concept into `renders/video.mp4`. Thin wrapper: HyperFrames owns
the rendering, this skill owns the pipeline order, the video direction, and the
voice step.

## When to use

- The explanation is a sequence in time: a race condition, a retry loop, a
  migration, an onboarding flow.
- The audience will not read code and will not open a diagram tool.
- Somebody must watch it later, without you present.

Do not use it for a single static picture. Route to `diagram-render` instead.

## Requirements

| Need | How |
|---|---|
| HyperFrames | `npx hyperframes` installs on demand. Pin nothing. |
| Voice (preferred) | `DEEPGRAM_API_KEY` in env, or `KEY=VALUE` in `~/.config/deepgram.env` |
| Voice (fallback) | No key → HyperFrames local Kokoro TTS: `npx hyperframes tts` |
| Media | `ffmpeg` and `ffprobe` on `PATH` |

Node 20 or later. The voice script has zero npm dependencies and uses `fetch`.

## Quick start

- `npx hyperframes init videos/<slug> --non-interactive --example=blank --skill=faceless-explainer`, then write `BRIEF.md`.
- Write `STORYBOARD.md` (8–10 frames, one `## Video direction` block) and `SCRIPT.md`, then get the frame table approved.
- `node <skill_folder>/scripts/deepgram-voice.mjs --script SCRIPT.md --out audio_meta.json`, then `audio.mjs sync-durations`.
- Dispatch one worker per frame in parallel with the packet, the video direction, the word cues, and the real duration.
- `npx hyperframes render --skill=faceless-explainer --quality high --output renders/video.mp4`.

Full commands, in order, live in [`references/pipeline.md`](references/pipeline.md).
The look and the negative list live in [`references/video-direction.md`](references/video-direction.md).

## Output contract

- File: `videos/<slug>/renders/video.mp4`
- Report the duration in seconds, measured with `ffprobe`, not the planned duration.
- Report the frame count and any frame that failed `npx hyperframes check`.

## Iteration rule

After every video, append what you learned to
[`references/lessons.md`](references/lessons.md) as one dated line. The pipeline
is only as good as the last failure somebody wrote down.
