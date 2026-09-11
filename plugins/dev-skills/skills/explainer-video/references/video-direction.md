# Video direction template

Copy this block into `STORYBOARD.md` and fill the bracketed values. Copy the
same block into `.hyperframes/video-direction.md` for the frame workers.

## Video direction

**Palette roles** — five roles, no more:

| Role | Use |
|---|---|
| ground | page background, one flat value |
| ink | body text and thin strokes |
| healthy accent | the state that works |
| broken accent | the state that fails |
| dark surface | panels, code blocks, insets |

Pick neutral hues. The two accents must differ in lightness, not only in hue.

**Recurring object** — choose one shape, for example a rounded rectangle that
stands for a request. It keeps the same size, corner radius, and stroke in every
frame. Its position and its fill change. Nothing else about it changes.

**Reveal model**

- Nothing appears on screen before the voiceover names it.
- One `Scene` per spoken cue. No cue, no scene.
- Hold the last state still for the final second. No exit animation.

**Typography roles** — three roles: title, body, label. One family, three
sizes, two weights. Nothing else.

**Negative list** — do not use:

- gradients or bokeh
- exit animations
- `repeat` or `yoyo`
- CSS transitions
- the narration set as on-screen text

**Caption keep-out** — every element must sit at `y ≤ 0.83 · height`. Captions
own the band below it.
