---
name: voice-studio
description: Use when the user requests spoken voice responses, audio generation, speech synthesis, speaking directly to the user, or expressive speech playback through VoiceStudio
---

# VoiceStudio

Synthesize spoken audio responses and play expressive speech locally via GPU.

## Usage

```bash
# Speak in background (non-blocking, default: explainer voice, 1.1x speed, 24 steps)
vsay -b "Task completed successfully."

# Expressive speech with pauses and non-verbal tokens
vsay -b "[surprise-wa] Incredible! The benchmark finished... [breathing] and ran fast. [laughter]"
```

## Flags

- `-b, --bg`: Play in background without blocking caller.
- `-v <voice>`: `explainer` (default), `companion`, `enthusiast`, `narrator`, `radio`, `deep`, or profile ID.
- `-s <float>`: Speed multiplier (default: `1.1`).
- `-N <int>`: Diffusion steps (default: `24`; `16` fast, `32` studio).
- `--cfg <float>`: Guidance scale (default: `2.0`).
- `-o <path>`: Save WAV to target file.
- `--no-play`: Generate audio without playing.
- `-l <code>`: Language code (default: `es`).
- `-L, --list`: List installed voice profiles.

## Expressive Tokens & Prosody

Embed bracketed tokens for vocal inflections:
- **Reactions:** `[laughter]`, `[surprise-wa]`, `[surprise-ah]`, `[sigh]`, `[crying]`
- **Hesitations & Feedback:** `[uhm]`, `[confirmation-en]`, `[dissatisfaction-hnn]`, `[shh]`, `[cough]`
- **Questions:** `[question-en]`, `[question-ah]`, `[question-oh]`, `[question-ei]`, `[question-yi]`

**Pacing rules:**
1. Combine `...` and `[breathing]` between clauses for natural breathing pauses.
2. Use punctuation marks (!, ?, ¡, ¿) to shape expressive pitch contours.
3. Place commas before conjunctions to induce realistic pitch dips.

## Health Check

```bash
curl -s http://127.0.0.1:3900/health
# Verify: "device": "cuda (AMD Radeon Graphics)"
```
