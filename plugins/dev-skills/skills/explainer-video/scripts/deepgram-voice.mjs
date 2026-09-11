#!/usr/bin/env node
// Deepgram voice track builder for the explainer-video skill.
// Zero dependencies. Node 20+ (global fetch). Needs ffprobe on PATH.
//
// Usage:
//   node deepgram-voice.mjs --script SCRIPT.md --out audio_meta.json \
//     [--voice aura-2-orion-en] [--dir assets/voice] \
//     [--cues-dir .hyperframes/word-cues] [--lang en]

import { execFileSync } from 'node:child_process'
import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs'
import { homedir } from 'node:os'
import path from 'node:path'
import { parseArgs } from 'node:util'

const OPTIONS = {
  script: { type: 'string', default: 'SCRIPT.md' },
  out: { type: 'string', default: 'audio_meta.json' },
  voice: { type: 'string', default: 'aura-2-orion-en' },
  dir: { type: 'string', default: 'assets/voice' },
  'cues-dir': { type: 'string', default: '.hyperframes/word-cues' },
  lang: { type: 'string', default: 'en' },
}

function readKey() {
  if (process.env.DEEPGRAM_API_KEY) return process.env.DEEPGRAM_API_KEY.trim()
  const file = path.join(homedir(), '.config', 'deepgram.env')
  const found = existsSync(file) && readFileSync(file, 'utf8').match(/^\s*DEEPGRAM_API_KEY\s*=\s*["']?(.+?)["']?\s*$/m)
  if (found) return found[1]
  console.error('Deepgram key not found. Set DEEPGRAM_API_KEY, or write DEEPGRAM_API_KEY=... into ~/.config/deepgram.env')
  process.exit(1)
}

// SCRIPT.md lines look like:
//   ## Line 3 — the retry storm (Frame 3)
//       I watch the same webhook arrive twice.
function parseScript(file) {
  const lines = readFileSync(file, 'utf8').split('\n')
  const out = []
  let current = null
  for (const line of lines) {
    const header = line.match(/^##\s+Line\s+(\d+).*?\(Frame\s+(\d+)\)/i)
    if (header) {
      if (current && current.text) out.push(current)
      current = { line: Number(header[1]), frame: Number(header[2]), text: '' }
      continue
    }
    if (current && /^ {4}\S/.test(line)) {
      current.text = current.text ? `${current.text} ${line.trim()}` : line.trim()
    }
  }
  if (current && current.text) out.push(current)
  if (!out.length) {
    console.error(`No lines parsed from ${file}. Expect "## Line N — ... (Frame N)" then 4-space-indented text.`)
    process.exit(1)
  }
  return out
}

function durationOf(file) {
  const value = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file], { encoding: 'utf8' })
  return Number(value.trim())
}

async function speak(key, voice, text) {
  const url = `https://api.deepgram.com/v1/speak?model=${encodeURIComponent(voice)}&encoding=linear16&sample_rate=24000&container=wav`
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Token ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  })
  if (!res.ok) throw new Error(`speak failed: ${res.status} ${await res.text()}`)
  return Buffer.from(await res.arrayBuffer())
}

async function transcribe(key, lang, wav) {
  const url = `https://api.deepgram.com/v1/listen?model=nova-3&language=${encodeURIComponent(lang)}&smart_format=true`
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Token ${key}`, 'Content-Type': 'audio/wav' },
    body: wav,
  })
  if (!res.ok) throw new Error(`listen failed: ${res.status} ${await res.text()}`)
  const json = await res.json()
  const words = json?.results?.channels?.[0]?.alternatives?.[0]?.words ?? []
  return words.map((word, index) => ({
    id: `w${index}`,
    text: word.punctuated_word ?? word.word,
    start: word.start,
    end: word.end,
  }))
}

async function main() {
  const { values } = parseArgs({ options: OPTIONS })
  const args = { ...values, cuesDir: values['cues-dir'] }
  const key = readKey()
  const entries = parseScript(args.script)
  mkdirSync(args.dir, { recursive: true })
  mkdirSync(args.cuesDir, { recursive: true })

  const voices = []
  for (const entry of entries) {
    const name = `${String(entry.line).padStart(2, '0')}.wav`
    const file = path.join(args.dir, name)
    process.stderr.write(`line ${entry.line} → frame ${entry.frame}\n`)
    const wav = await speak(key, args.voice, entry.text)
    writeFileSync(file, wav)
    const duration = durationOf(file)
    const words = await transcribe(key, args.lang, wav)
    voices.push({ frame: entry.frame, path: file, duration_s: duration, words })

    const cues = [`duration_s: ${duration}`, ...words.map((word) => `${word.start} ${word.text}`)].join('\n')
    writeFileSync(path.join(args.cuesDir, `frame-${entry.frame}.txt`), `${cues}\n`)
  }

  writeFileSync(args.out, `${JSON.stringify({ bgm: null, bgm_pending: false, voices, sfx: [] }, null, 2)}\n`)
  process.stderr.write(`wrote ${args.out} (${voices.length} lines)\n`)
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
