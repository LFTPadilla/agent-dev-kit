#!/usr/bin/env bash
# VoiceStudio local speech synthesizer and player
set -euo pipefail

PORT="${OMNIVOICE_PORT:-3900}"
MODEL="${VOICE_MODEL:-omnivoice}"
VOICE="${VOICE_NAME:-0a96633d}"
SPEED="${VOICE_SPEED:-1.1}"
LANG="${VOICE_LANG:-es}"
INSTRUCT="${VOICE_INSTRUCT:-}"

if [[ "${1:-}" == "--list" || "${1:-}" == "-L" ]]; then
  echo "Available voices in VoiceStudio:"
  curl -s "http://127.0.0.1:${PORT}/profiles" | jq -r '.[] | "  - \(.name) [id: \(.id)]"'
  exit 0
fi

NUM_STEPS="${VOICE_STEPS:-24}"
CFG_SCALE="${VOICE_CFG:-}"

OUTPUT_FILE=""
PLAY_BG=false
NO_PLAY=false
SHOW_TIME=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)
      MODEL="$2"; shift 2 ;;
    -v|--voice)
      VOICE="$2"; shift 2 ;;
    -s|--speed)
      SPEED="$2"; shift 2 ;;
    -l|--lang)
      LANG="$2"; shift 2 ;;
    -i|--instruct)
      INSTRUCT="$2"; shift 2 ;;
    -o|--output)
      OUTPUT_FILE="$2"; shift 2 ;;
    -b|--bg|--async)
      PLAY_BG=true; shift ;;
    --no-play)
      NO_PLAY=true; shift ;;
    -t|--time)
      SHOW_TIME=true; shift ;;
    -N|--steps)
      NUM_STEPS="$2"; shift 2 ;;
    --cfg)
      CFG_SCALE="$2"; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done

# Resolve friendly voice aliases
case "${VOICE,,}" in
  companion)    VOICE="6c622598" ;;
  enthusiast)   VOICE="32ac306d" ;;
  narrator)     VOICE="6a9c814f" ;;
  explainer)    VOICE="0a96633d" ;;
  radio)        VOICE="e0a0b1e7" ;;
  deep)         VOICE="26979e6a" ;;
  demo)         VOICE="demo0001" ;;
esac

if [ ${#POSITIONAL[@]} -gt 0 ]; then
  TEXT="${POSITIONAL[*]}"
else
  TEXT="$(cat)"
fi

if [ -z "${TEXT// }" ]; then
  exit 0
fi

# Verify backend health
if ! curl -s --max-time 2 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
  echo "Error: VoiceStudio is not responding on http://127.0.0.1:${PORT}" >&2
  echo "Ensure VoiceStudio is running or start the backend service." >&2
  exit 1
fi

TMP_AUDIO=$(mktemp /tmp/voicestudio-XXXXXX.wav)
trap 'rm -f "$TMP_AUDIO"' EXIT

PAYLOAD=$(jq -n \
  --arg model "$MODEL" \
  --arg voice "$VOICE" \
  --arg text "$TEXT" \
  --arg lang "$LANG" \
  --arg instruct "$INSTRUCT" \
  --arg steps "$NUM_STEPS" \
  --arg cfg "$CFG_SCALE" \
  --argjson speed "$SPEED" \
  '{
    model: $model,
    voice: $voice,
    input: $text,
    language: (if $lang == "" then null else $lang end),
    instruct: (if $instruct == "" then null else $instruct end),
    speed: $speed,
    response_format: "wav"
  } + (if $steps != "" then {num_step: ($steps | tonumber)} else {} end)
    + (if $cfg != "" then {guidance_scale: ($cfg | tonumber)} else {} end)')

CONNECT_TIMEOUT="${VOICE_CONNECT_TIMEOUT:-10}"
SYNTHESIS_TIMEOUT="${VOICE_SYNTHESIS_TIMEOUT:-300}"

CURL_OUT=$(curl -s --connect-timeout "$CONNECT_TIMEOUT" --max-time "$SYNTHESIS_TIMEOUT" \
  -w "%{http_code}:%{time_total}" -X POST "http://127.0.0.1:${PORT}/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --output "$TMP_AUDIO")

HTTP_CODE="${CURL_OUT%%:*}"
TIME_TOTAL="${CURL_OUT##*:}"

if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: VoiceStudio returned HTTP $HTTP_CODE" >&2
  cat "$TMP_AUDIO" >&2
  exit 1
fi

if [ "$SHOW_TIME" = true ]; then
  echo "GPU synthesis time: ${TIME_TOTAL}s"
fi

if [ -n "$OUTPUT_FILE" ]; then
  cp "$TMP_AUDIO" "$OUTPUT_FILE"
fi

if [ "$NO_PLAY" = true ]; then
  exit 0
fi

if [ "$PLAY_BG" = true ]; then
  trap - EXIT
  nohup bash -c "pw-play \"$TMP_AUDIO\" >/dev/null 2>&1; rm -f \"$TMP_AUDIO\"" >/dev/null 2>&1 &
else
  pw-play "$TMP_AUDIO"
fi
