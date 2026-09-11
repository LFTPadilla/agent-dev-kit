# Explainer video pipeline

Seven steps, in order. Do not skip a step. Every command runs from the project
directory `videos/<slug>` unless the step says otherwise.

## 1. Init the project

Enter through `/hyperframes` and take the faceless-explainer route.

```
npx hyperframes init videos/<slug> --non-interactive --example=blank --skill=faceless-explainer
```

Write `BRIEF.md`. State four things: the flow you automate or explain, that a
storyboard is required, the language, and the voice.

## 2. Build the frame shell

```
node <faceless-explainer skill>/scripts/build-frame.mjs --preset <preset> --hyperframes .
```

If you remixed the preset, stage the fonts yourself. Remixed presets do not
carry fonts. Download the Google Fonts woff2 *latin* subset into `assets/fonts`.
Parse the `/* latin */` block of the CSS to find the exact URL.

## 3. Storyboard and script

Write `STORYBOARD.md` with 8 to 10 frames. Include one `## Video direction`
block at the top — copy the template from `video-direction.md`.

Each frame carries:

- type
- persuasion
- beat
- scene
- voiceover
- blueprint
- focal
- roles
- time-coded `Scene` lines

Write `SCRIPT.md` in natural, conversational, first person. Keep lines short.

```
npx hyperframes preview --background --no-open
```

Show the frame table and get approval before you spend voice credits.

## 4. Voice

Preferred:

```
node <skill_folder>/scripts/deepgram-voice.mjs \
  --script SCRIPT.md \
  --out audio_meta.json \
  --voice aura-2-orion-en
```

Alternatives: HeyGen, or local Kokoro through the workflow's `audio.mjs`.

Then align the composition to the audio that exists:

```
node <workflow>/scripts/audio.mjs sync-durations
```

Real durations win. Never keep a planned duration after this step.

## 5. Frames and workers

- Add a `- src:` entry per frame in the index.
- Run `frame-packets.mjs` to build one packet per frame.
- Write `.hyperframes/video-direction.md`.
- Dispatch one worker per frame, in parallel.

Give each worker six inputs: the role, the frame packet, the video direction
file, `frame.md`, the word cues for that frame, and the real duration.

Lint rules to pass to every worker:

- one root element, one ground clip
- unique, prefixed element ids
- `fromTo` for every tween
- no `repeat`, no `yoyo`, no CSS transitions
- `tl.set` for text content
- contrast 3:1 or better
- all content above `0.83 · height`
- GSAP code inside the template
- exact font names, no fallback guessing

## 6. Assemble and check

```
# renumber data-track-index sequentially, per frame, first
node <workflow>/scripts/captions.mjs build
node <workflow>/scripts/assemble-index.mjs
node <workflow>/scripts/transitions.mjs inject
node <workflow>/scripts/transitions.mjs verify
npx hyperframes lint
npx hyperframes check
```

Mark animated frames as animated before you assemble. Feed every `check`
finding back to the frame's own worker, not to a new one. Take `snapshot`
midpoints and look at the contact sheet once.

## 7. Render

```
npx hyperframes render --skill=faceless-explainer --quality high --output renders/video.mp4
```

Measure the final duration with `ffprobe` and report it.
