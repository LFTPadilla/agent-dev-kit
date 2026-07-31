// Render docs/demo/session.txt (a real captured terminal session) into an
// animated GIF for the README. No recorder dependency: SVG frames -> sharp ->
// ffmpeg. Regenerate the transcript by rerunning the commands it contains.
//
// Usage: npm run render:demo   (requires ffmpeg on PATH)
import { execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import sharp from 'sharp'

const ROOT = new URL('..', import.meta.url).pathname
const SESSION = join(ROOT, 'docs/demo/session.txt')
const OUT = join(ROOT, 'docs/demo/demo.gif')

const W = 940
const CHROME = 40
const PAD = 18
const LH = 23 // line height
const FS = 16 // font size
const VIEWPORT = 22 // lines visible at once
const H = CHROME + PAD * 2 + VIEWPORT * LH
const FPS = 6
const HOLD = 14 // frames held on the final state

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

// ponytail: colour by line shape, not by parsing ANSI — the transcript is plain text
function colour(line) {
  if (line.startsWith('$ ')) return '#f8fafc'
  if (line.startsWith('OK ')) return '#34d399'
  if (line.startsWith('FLAG')) return '#f59e0b'
  if (/^\d+ checks: 0 failed/.test(line)) return '#34d399'
  if (line.startsWith('semgrep floor:')) return '#f59e0b'
  if (line.startsWith('>')) return '#475569'
  return '#94a3b8'
}

function frame(lines) {
  const shown = lines.slice(Math.max(0, lines.length - VIEWPORT))
  const body = shown
    .map((line, i) => {
      const y = CHROME + PAD + LH * (i + 1) - 6
      const bold = line.startsWith('$ ') || /^\d+ checks/.test(line)
      return `<text x="${PAD}" y="${y}" fill="${colour(line)}"${bold ? ' font-weight="bold"' : ''}>${esc(line)}</text>`
    })
    .join('\n    ')

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" rx="12" fill="#0a0f1c"/>
  <path d="M0 12a12 12 0 0 1 12-12h${W - 24}a12 12 0 0 1 12 12v${CHROME - 12}H0z" fill="#131b2e"/>
  <circle cx="24" cy="20" r="6" fill="#ef4444"/>
  <circle cx="46" cy="20" r="6" fill="#f59e0b"/>
  <circle cx="68" cy="20" r="6" fill="#34d399"/>
  <text x="${W / 2}" y="25" fill="#64748b" font-size="13" text-anchor="middle"
        font-family="DejaVu Sans, Helvetica, Arial, sans-serif">agent-dev-kit — measurable gates</text>
  <g font-family="DejaVu Sans Mono, monospace" font-size="${FS}">
    ${body}
  </g>
</svg>`
}

const lines = readFileSync(SESSION, 'utf8').replace(/\n+$/, '').split('\n')
const dir = mkdtempSync(join(tmpdir(), 'adk-demo-'))
try {
  let n = 0
  const write = (svg) =>
    sharp(Buffer.from(svg)).png().toFile(join(dir, `f-${String(n++).padStart(4, '0')}.png`))

  const jobs = []
  for (let i = 1; i <= lines.length; i++) jobs.push(write(frame(lines.slice(0, i))))
  const last = frame(lines)
  for (let i = 0; i < HOLD; i++) jobs.push(write(last))
  await Promise.all(jobs)

  mkdirSync(join(ROOT, 'docs/demo'), { recursive: true })
  execFileSync(
    'ffmpeg',
    ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', join(dir, 'f-%04d.png'),
     '-vf', 'split[a][b];[a]palettegen=max_colors=48:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5', OUT],
    { stdio: 'inherit' },
  )
  console.log(`Rendered ${OUT} (${n} frames @ ${FPS}fps)`)
} finally {
  rmSync(dir, { recursive: true, force: true })
}

// Self-check: the transcript must still contain the two claims the README cites.
const text = readFileSync(SESSION, 'utf8')
if (!text.includes('0 failed') || !text.includes('false positives 0/3')) {
  throw new Error('session.txt no longer shows the results the README quotes — recapture it')
}
