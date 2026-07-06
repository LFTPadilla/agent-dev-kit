#!/usr/bin/env node
import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, statSync } from 'node:fs'
import { homedir } from 'node:os'
import path from 'node:path'
import process from 'node:process'

const root = path.resolve(new URL('..', import.meta.url).pathname)
const privatePatterns = [
  new RegExp(['black', 'rack'].join(''), 'i'),
  new RegExp(['/home/felipe/vault/Projects/', ['Black', 'rack'].join('')].join(''), 'i'),
  new RegExp(['ec2', '-us', '-east', '-', 'bk', '-control'].join(''), 'i'),
  new RegExp(['100', '\\.', '98', '\\.'].join('')),
  new RegExp(['52', '\\.', '2', '\\.', '233', '\\.', '175'].join(''))
]
const ignoreDirs = new Set(['.git', 'node_modules', '.pi', '.venv', 'venv', 'playwright-report', 'test-results'])

function color(code, text) {
  return process.stdout.isTTY ? `\u001b[${code}m${text}\u001b[0m` : text
}

const ok = (msg) => ({ level: 'ok', msg })
const warn = (msg) => ({ level: 'warn', msg })
const fail = (msg) => ({ level: 'fail', msg })

function printChecks(checks) {
  for (const check of checks) {
    const label = check.level === 'ok' ? color(32, 'OK') : check.level === 'warn' ? color(33, 'WARN') : color(31, 'FAIL')
    console.log(`${label} ${check.msg}`)
  }
  const failures = checks.filter((c) => c.level === 'fail').length
  const warnings = checks.filter((c) => c.level === 'warn').length
  console.log(`\n${checks.length} checks: ${failures} failed, ${warnings} warnings`)
  return failures
}

function commandExists(name) {
  const result = spawnSync('sh', ['-lc', `command -v ${quote(name)} >/dev/null 2>&1`])
  return result.status === 0
}

function commandVersion(name, args = ['--version']) {
  if (!commandExists(name)) return null
  try {
    return execFileSync(name, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).split('\n')[0].trim()
  } catch {
    return 'installed'
  }
}

function quote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`
}

function walkFiles(dir, out = []) {
  if (!existsSync(dir)) return out
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (ignoreDirs.has(entry.name)) continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walkFiles(full, out)
    else if (entry.isFile()) out.push(full)
  }
  return out
}

function readJson(file, checks) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'))
  } catch (error) {
    checks.push(fail(`${rel(file)} is not valid JSON: ${error.message}`))
    return null
  }
}

function rel(file) {
  return path.relative(root, file) || '.'
}

function parseFrontmatter(text) {
  if (!text.startsWith('---\n')) return null
  const end = text.indexOf('\n---', 4)
  if (end === -1) return null
  const raw = text.slice(4, end).trim()
  const fields = new Map()
  for (const line of raw.split('\n')) {
    const match = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)
    if (match) fields.set(match[1], match[2].trim())
  }
  return fields
}

function skillDirs() {
  const dir = path.join(root, 'plugins/dev-skills/skills')
  if (!existsSync(dir)) return []
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(dir, entry.name))
    .sort()
}

function validateSkills(checks) {
  const dirs = skillDirs()
  if (!dirs.length) {
    checks.push(fail('no skills found under plugins/dev-skills/skills'))
    return
  }
  for (const dir of dirs) {
    const file = path.join(dir, 'SKILL.md')
    if (!existsSync(file)) {
      checks.push(fail(`${rel(dir)} is missing SKILL.md`))
      continue
    }
    const text = readFileSync(file, 'utf8')
    const fm = parseFrontmatter(text)
    if (!fm) {
      checks.push(fail(`${rel(file)} is missing YAML frontmatter`))
      continue
    }
    const name = fm.get('name')
    const description = fm.get('description')
    if (!name) checks.push(fail(`${rel(file)} is missing frontmatter field: name`))
    if (!description || description.length < 20) checks.push(fail(`${rel(file)} needs an actionable description`))
  }
  checks.push(ok(`${dirs.length} skill frontmatters checked`))
}

function validateJsonFiles(checks) {
  for (const file of walkFiles(root).filter((f) => f.endsWith('.json'))) readJson(file, checks)
  checks.push(ok('JSON files parse'))
}

function validateYamlFiles(checks) {
  for (const file of walkFiles(root).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'))) {
    const text = readFileSync(file, 'utf8')
    if (text.includes('\t')) checks.push(fail(`${rel(file)} contains tabs; use spaces in YAML`))
    if (!text.trim()) checks.push(fail(`${rel(file)} is empty`))
  }
  checks.push(ok('YAML files passed lightweight syntax checks'))
}

function validatePlugin(checks) {
  const file = path.join(root, 'plugins/dev-skills/.claude-plugin/plugin.json')
  const data = readJson(file, checks)
  if (!data) return
  if (!/^\d+\.\d+\.\d+/.test(data.version || '')) checks.push(fail(`${rel(file)} version must be semver-like`))
  if (!data.name || !data.description) checks.push(fail(`${rel(file)} must include name and description`))
  else checks.push(ok('plugin manifest checked'))
}

function validateProvenance(checks) {
  const file = path.join(root, 'skill-provenance.json')
  const data = readJson(file, checks)
  if (!data) return
  const actual = skillDirs().map((dir) => path.basename(dir)).sort()
  const recorded = Object.keys(data.skills || {}).sort()
  const missing = actual.filter((name) => !recorded.includes(name))
  const stale = recorded.filter((name) => !actual.includes(name))
  for (const name of missing) checks.push(fail(`skill-provenance.json missing skill: ${name}`))
  for (const name of stale) checks.push(fail(`skill-provenance.json has stale skill: ${name}`))
  for (const [name, item] of Object.entries(data.skills || {})) {
    for (const field of ['source', 'license', 'visibility', 'risk', 'dependencies']) {
      if (!(field in item)) checks.push(fail(`skill-provenance.json ${name} missing ${field}`))
    }
  }
  if (!missing.length && !stale.length) checks.push(ok('skill provenance covers all skills'))
}

function validateProfiles(checks) {
  const dir = path.join(root, 'profiles')
  if (!existsSync(dir)) {
    checks.push(fail('profiles/ directory is missing'))
    return
  }
  const files = readdirSync(dir).filter((name) => name.endsWith('.yml') || name.endsWith('.yaml'))
  if (!files.length) checks.push(fail('profiles/ has no profile manifests'))
  for (const name of files) {
    const text = readFileSync(path.join(dir, name), 'utf8')
    for (const required of ['profile:', 'runtime:', 'sandbox_policy:', 'include_skills:']) {
      if (!text.includes(required)) checks.push(fail(`profiles/${name} missing ${required}`))
    }
  }
  checks.push(ok(`${files.length} profile manifests checked`))
}

function validatePolicies(checks) {
  const file = path.join(root, 'policies/sandbox-policies.json')
  const data = readJson(file, checks)
  if (!data) return
  for (const [name, policy] of Object.entries(data.policies || {})) {
    for (const field of ['writes', 'network', 'secrets', 'production', 'git_push', 'destructive_ops']) {
      if (!(field in policy)) checks.push(fail(`sandbox policy ${name} missing ${field}`))
    }
  }
  checks.push(ok('sandbox policies checked'))
}

function validateEvals(checks) {
  const file = path.join(root, 'evals/cases.json')
  const cases = readJson(file, checks)
  if (!Array.isArray(cases)) return
  const seen = new Set()
  for (const c of cases) {
    if (!c.file || typeof c.plantedBug !== 'boolean') checks.push(fail(`invalid eval case entry: ${JSON.stringify(c)}`))
    if (seen.has(c.file)) checks.push(fail(`duplicate eval case: ${c.file}`))
    seen.add(c.file)
    if (c.file && !existsSync(path.join(root, 'evals/cases', c.file))) checks.push(fail(`eval case file missing: ${c.file}`))
  }
  const planted = cases.filter((c) => c.plantedBug).length
  const controls = cases.length - planted
  if (cases.length < 12) checks.push(fail('eval suite should have at least 12 cases'))
  if (controls < 2) checks.push(fail('eval suite should have at least 2 clean controls'))
  checks.push(ok(`eval suite checked (${planted} planted, ${controls} controls)`))
}

function validateLinks(checks) {
  const markdown = walkFiles(root).filter((f) => f.endsWith('.md'))
  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g
  for (const file of markdown) {
    const text = readFileSync(file, 'utf8')
    for (const match of text.matchAll(linkPattern)) {
      const target = match[1]
      if (/^(https?:|mailto:|#)/.test(target)) continue
      const clean = target.split('#')[0]
      if (!clean || clean.includes('<') || clean.includes('>')) continue
      const resolved = path.resolve(path.dirname(file), clean)
      if (!existsSync(resolved)) checks.push(fail(`${rel(file)} links to missing ${target}`))
    }
  }
  checks.push(ok('relative markdown links checked'))
}

function privacyScan(checks) {
  const offenders = []
  for (const file of walkFiles(root)) {
    if (file.includes('plugins/dev-skills/skills/drawio-skill/data/lobe-icons.json')) continue
    if (!/\.(md|json|ya?ml|mjs|js|ts|tsx|sh)$/.test(file)) continue
    const text = readFileSync(file, 'utf8')
    for (const pattern of privatePatterns) {
      if (pattern.test(text)) {
        offenders.push(`${rel(file)} matches ${pattern}`)
        break
      }
    }
  }
  if (offenders.length) offenders.forEach((item) => checks.push(fail(`private coupling: ${item}`)))
  else checks.push(ok('privacy scan found no private project coupling'))
}

function validate() {
  const checks = []
  validateJsonFiles(checks)
  validateYamlFiles(checks)
  validatePlugin(checks)
  validateSkills(checks)
  validateProvenance(checks)
  validateProfiles(checks)
  validatePolicies(checks)
  validateEvals(checks)
  validateLinks(checks)
  privacyScan(checks)
  return printChecks(checks)
}

function runtimeTargets() {
  return [
    ['Claude', path.join(homedir(), '.claude/skills')],
    ['Claude secondary', path.join(homedir(), '.claude-very/skills')],
    ['Codex', path.join(homedir(), '.codex/skills')],
    ['Pi', path.join(homedir(), '.pi/agent/skills')],
    ['OpenCode commands', path.join(homedir(), '.config/opencode/command')]
  ]
}

function doctor() {
  const checks = []
  for (const [name, args] of [
    ['node', ['--version']],
    ['npm', ['--version']],
    ['git', ['--version']],
    ['rg', ['--version']],
    ['hypa', ['--version']],
    ['claude', ['--version']],
    ['pi', ['--version']],
    ['opencode', ['--version']],
    ['semgrep', ['--version']]
  ]) {
    const version = commandVersion(name, args)
    checks.push(version ? ok(`${name}: ${version}`) : warn(`${name}: not found`))
  }
  for (const [label, target] of runtimeTargets()) {
    if (!existsSync(target)) {
      checks.push(warn(`${label} skills target missing: ${target}`))
      continue
    }
    const entries = readdirSync(target)
    const broken = entries.filter((entry) => {
      const full = path.join(target, entry)
      return lstatSync(full).isSymbolicLink() && !existsSync(full)
    })
    checks.push(broken.length ? fail(`${label} has broken skill symlinks: ${broken.join(', ')}`) : ok(`${label} target ready: ${target}`))
  }
  const validationFailures = validate()
  checks.push(validationFailures ? fail(`validate has ${validationFailures} failures`) : ok('validate passed'))
  return printChecks(checks)
}

function inventory() {
  const provenance = readJson(path.join(root, 'skill-provenance.json'), [])
  console.log(`# agent-dev-kit inventory\n`)
  console.log(`Root: ${root}`)
  console.log(`Skills: ${skillDirs().length}`)
  for (const dir of skillDirs()) {
    const name = path.basename(dir)
    const item = provenance?.skills?.[name]
    console.log(`- ${name}${item ? ` (${item.risk}, ${item.visibility})` : ''}`)
  }
  console.log(`\nRuntimes:`)
  for (const [label, target] of runtimeTargets()) {
    console.log(`- ${label}: ${existsSync(target) ? target : 'missing'}`)
  }
}

function usage() {
  console.log(`Usage: agent-dev-kit <doctor|validate|inventory>`)
}

const command = process.argv[2]
if (command === 'doctor') process.exit(doctor() ? 1 : 0)
else if (command === 'validate') process.exit(validate() ? 1 : 0)
else if (command === 'inventory') inventory()
else {
  usage()
  process.exit(command ? 1 : 0)
}
