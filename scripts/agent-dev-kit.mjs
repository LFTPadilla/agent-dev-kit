#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import { existsSync, lstatSync, readdirSync, readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { parseDocument } from 'yaml'

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)))
const claudePluginFile = path.join(root, 'plugins/dev-skills/.claude-plugin/plugin.json')
const privatePatterns = [
  /(?<![A-Za-z0-9_$}])\/home\/(?!(?:example|user|runner|tutor)\b)[A-Za-z0-9._-]+/i,
  /(?<![A-Za-z0-9_$}])\/Users\/(?!(?:example|user|runner|you)\b)[A-Za-z0-9._-]+/
]
const yamlExtensions = ['.yml', '.yaml']
const privacyScanExtensions = ['.md', '.json', '.yml', '.yaml', '.mjs', '.js', '.ts', '.tsx', '.sh']
const ignoreDirs = new Set(['.git', 'node_modules', '.pi', '.venv', 'venv', 'playwright-report', 'test-results'])

function color(code, text) {
  return process.stdout.isTTY ? `\u001b[${code}m${text}\u001b[0m` : text
}

const ok = (msg) => ({ level: 'ok', msg })
const warn = (msg) => ({ level: 'warn', msg })
const fail = (msg) => ({ level: 'fail', msg })

function checkLabel(level) {
  if (level === 'ok') return color(32, 'OK')
  if (level === 'warn') return color(33, 'WARN')
  return color(31, 'FAIL')
}

function printChecks(checks) {
  let failures = 0
  let warnings = 0
  for (const check of checks) {
    console.log(`${checkLabel(check.level)} ${check.msg}`)
    if (check.level === 'fail') failures++
    else if (check.level === 'warn') warnings++
  }
  console.log(`\n${checks.length} checks: ${failures} failed, ${warnings} warnings`)
  return failures
}

function commandVersion(name) {
  const result = spawnSync(name, ['--version'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
  if (result.error?.code === 'ENOENT') return null
  if (result.error || result.status !== 0) return 'installed'
  return (result.stdout ?? '').split('\n')[0].trim()
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

function filesWithExtensions(files, extensions) {
  return files.filter((file) => extensions.some((extension) => file.endsWith(extension)))
}

function missingFields(value, fields) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return fields.slice()
  return fields.filter((field) => !(field in value))
}

function addMissingFieldFailures(checks, value, fields, label) {
  for (const field of missingFields(value, fields)) checks.push(fail(`${label} missing ${field}`))
}

// Vite/TypeScript toolchain config files (tsconfig.*.json) are JSONC by
// convention: they carry `/* section */` comments. JSONC is a superset of
// strict JSON, so stripping comments before parsing is safe for every file —
// valid JSON is unaffected, and the JSONC files the repo ships parse cleanly.
function stripJsonComments(text) {
  let out = ''
  let inString = false
  let escape = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    const next = text[i + 1]
    if (inString) {
      out += c
      if (escape) escape = false
      else if (c === '\\') escape = true
      else if (c === '"') inString = false
      continue
    }
    if (c === '"') { inString = true; out += c; continue }
    if (c === '/' && next === '/') {
      while (i < text.length && text[i] !== '\n') i++
      continue
    }
    if (c === '/' && next === '*') {
      i += 2
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++
      i++ // skip the closing `/`
      continue
    }
    out += c
  }
  return out
}

function readJson(file, checks) {
  try {
    return JSON.parse(stripJsonComments(readFileSync(file, 'utf8')))
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

function validateSkills(checks, { skillDirs: dirs }) {
  if (!dirs.length) {
    checks.push(fail('no skills found under plugins/dev-skills/skills'))
    return
  }
  for (const dir of dirs) {
    const name = path.basename(dir)
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
    const declaredName = fm.get('name')
    const description = fm.get('description')
    if (!declaredName) checks.push(fail(`${rel(file)} is missing frontmatter field: name`))
    else if (declaredName !== name) checks.push(fail(`${rel(file)} name must match directory ${name}`))
    if (!description || description.length < 20) checks.push(fail(`${rel(file)} needs an actionable description`))
  }
  checks.push(ok(`${dirs.length} skill frontmatters checked`))
}

function validateJsonFiles(checks, { files }) {
  for (const file of filesWithExtensions(files, ['.json'])) readJson(file, checks)
  checks.push(ok('JSON files parse'))
}

function validateYamlFiles(checks, { files }) {
  for (const file of filesWithExtensions(files, yamlExtensions)) {
    const text = readFileSync(file, 'utf8')
    if (text.includes('\t')) checks.push(fail(`${rel(file)} contains tabs; use spaces in YAML`))
    if (!text.trim()) checks.push(fail(`${rel(file)} is empty`))
    const document = parseDocument(text, { prettyErrors: true, strict: true })
    for (const error of document.errors) {
      checks.push(fail(`${rel(file)} is not valid YAML: ${error.message.replaceAll('\n', ' ')}`))
    }
  }
  checks.push(ok('YAML files parse with strict syntax checks'))
}

function validatePlugin(checks) {
  const data = readJson(claudePluginFile, checks)
  if (!data) return
  if (!/^\d+\.\d+\.\d+/.test(data.version || '')) checks.push(fail(`${rel(claudePluginFile)} version must be semver-like`))
  if (!data.name || !data.description) checks.push(fail(`${rel(claudePluginFile)} must include name and description`))
  else checks.push(ok('plugin manifest checked'))
}

function validateReleaseVersions(checks) {
  const packageFile = path.join(root, 'package.json')
  const lockFile = path.join(root, 'package-lock.json')
  const codexFile = path.join(root, 'plugins/dev-skills/.codex-plugin/plugin.json')
  const releaseFiles = [packageFile, lockFile, claudePluginFile, codexFile]
  const releaseData = releaseFiles.map((file) => readJson(file, checks))
  if (releaseData.some((data) => !data)) return
  const [packageData, lockData, claudeData, codexData] = releaseData
  const versions = new Map([
    [rel(packageFile), packageData.version],
    [`${rel(lockFile)} root`, lockData.version],
    [`${rel(lockFile)} package`, lockData.packages?.['']?.version],
    [rel(claudePluginFile), claudeData.version],
    [rel(codexFile), codexData.version],
  ])
  const expected = packageData.version
  const mismatches = [...versions].filter(([, version]) => version !== expected)
  for (const [source, version] of mismatches) {
    checks.push(fail(`${source} version ${version ?? 'missing'} does not match ${expected}`))
  }
  if (!mismatches.length) {
    checks.push(ok(`release versions aligned at ${expected}`))
  }
}

function validateProvenance(checks, { skillDirs: dirs }) {
  const file = path.join(root, 'skill-provenance.json')
  const data = readJson(file, checks)
  if (!data) return
  const skills = data.skills || {}
  const actual = dirs.map((dir) => path.basename(dir)).sort()
  const recorded = Object.keys(skills).sort()
  const missing = actual.filter((name) => !recorded.includes(name))
  const stale = recorded.filter((name) => !actual.includes(name))
  for (const name of missing) checks.push(fail(`skill-provenance.json missing skill: ${name}`))
  for (const name of stale) checks.push(fail(`skill-provenance.json has stale skill: ${name}`))
  for (const [name, item] of Object.entries(skills)) {
    addMissingFieldFailures(checks, item, ['source', 'license', 'visibility', 'risk', 'dependencies'], `skill-provenance.json ${name}`)
  }
  if (!missing.length && !stale.length) checks.push(ok('skill provenance covers all skills'))
}

function validateProfiles(checks) {
  const dir = path.join(root, 'profiles')
  if (!existsSync(dir)) {
    checks.push(fail('profiles/ directory is missing'))
    return
  }
  const files = filesWithExtensions(readdirSync(dir), yamlExtensions)
  if (!files.length) checks.push(fail('profiles/ has no profile manifests'))
  for (const name of files) {
    const text = readFileSync(path.join(dir, name), 'utf8')
    for (const required of ['profile:', 'runtime:', 'sandbox_policy:', 'include_skills:']) {
      if (!text.includes(required)) checks.push(fail(`profiles/${name} missing ${required}`))
    }
  }
  checks.push(ok(`${files.length} profile manifests checked`))
}

function validatePiPackageResearch(checks) {
  const dir = path.join(root, 'pi-profiles')
  const settingsFile = path.join(dir, 'settings.example.json')
  const profilesFile = path.join(dir, 'profiles.yaml')
  const readmeFile = path.join(dir, 'README.md')
  const matrixFile = path.join(dir, 'package-matrix.md')
  const auditFile = path.join(dir, 'context-mode-audit.md')
  const remainingAuditFile = path.join(dir, 'remaining-candidates-audit.md')
  const requiredFiles = [profilesFile, readmeFile, matrixFile, auditFile, remainingAuditFile]

  const settings = readJson(settingsFile, checks)
  if (!settings || !Array.isArray(settings.packages)) {
    checks.push(fail('pi-profiles/settings.example.json must define a packages array'))
  } else if (settings.packages.length !== 0) {
    checks.push(fail('pi-profiles/settings.example.json must remain inert with an empty packages array'))
  }

  const missingFiles = requiredFiles.filter((file) => !existsSync(file))
  for (const file of missingFiles) checks.push(fail(`${rel(file)} is missing`))
  if (missingFiles.length) return

  const [profiles, readme, matrix, audit, remainingAudit] = requiredFiles.map((file) => readFileSync(file, 'utf8'))
  const profilesDocument = parseDocument(profiles, { prettyErrors: true, strict: true })
  const profilesConfig = profilesDocument.errors.length === 0 ? profilesDocument.toJS() : null

  if (profilesConfig?.status !== 'research-only' || profilesConfig?.runtime_activation !== 'none') {
    checks.push(fail('pi-profiles/profiles.yaml must remain research-only with no runtime activation'))
  }
  for (const profileName of ['pi-code-review', 'pi-sre-research']) {
    const profile = profilesConfig?.profiles?.[profileName]
    const hasPackageFreeCompatibility = Boolean(profile) &&
      Array.isArray(profile.packages) &&
      profile.packages.length === 0 &&
      profile.runtime_activation === 'metadata-only'
    if (!hasPackageFreeCompatibility) {
      checks.push(fail(`pi-profiles/profiles.yaml must preserve package-free ${profileName} compatibility`))
    }
  }
  if (/(?:npm|git|https?):[^\s"']+/.test(profiles)) {
    checks.push(fail('pi-profiles/profiles.yaml must not activate or name package sources'))
  }
  if (!readme.includes('enables no') || !readme.includes('third-party package')) {
    checks.push(fail('pi-profiles/README.md must state that no third-party package is enabled'))
  }
  if (!matrix.includes('context-mode@1.0.169') || !audit.includes('do not install, enable, or pilot')) {
    checks.push(fail('Pi package research must preserve the reviewed context-mode pin and no-pilot decision'))
  }
  for (const packagePin of [
    'pi-sandbox@0.6.0',
    'pi-distill@1.1.0',
    '@gotgenes/pi-permission-system@20.10.0',
  ]) {
    if (!remainingAudit.includes(packagePin)) {
      checks.push(fail(`Pi package research must preserve the reviewed decision for ${packagePin}`))
    }
  }
  if (!remainingAudit.includes('No Pi')) {
    checks.push(fail('remaining Pi audits must state that no Pi package is enabled'))
  }

  checks.push(ok('Pi package research is inert and preserves compatibility contracts'))
}

function validatePolicies(checks) {
  const file = path.join(root, 'policies/sandbox-policies.json')
  const data = readJson(file, checks)
  if (!data) return
  for (const [name, policy] of Object.entries(data.policies || {})) {
    addMissingFieldFailures(checks, policy, ['writes', 'network', 'secrets', 'production', 'git_push', 'destructive_ops'], `sandbox policy ${name}`)
  }
  checks.push(ok('sandbox policies checked'))
}

function validateEvals(checks) {
  const file = path.join(root, 'evals/cases.json')
  const cases = readJson(file, checks)
  if (!Array.isArray(cases)) return
  const seen = new Set()
  let planted = 0
  for (const c of cases) {
    if (!c.file || typeof c.plantedBug !== 'boolean') checks.push(fail(`invalid eval case entry: ${JSON.stringify(c)}`))
    if (seen.has(c.file)) checks.push(fail(`duplicate eval case: ${c.file}`))
    seen.add(c.file)
    if (c.file && !existsSync(path.join(root, 'evals/cases', c.file))) checks.push(fail(`eval case file missing: ${c.file}`))
    if (c.plantedBug) planted++
  }
  const controls = cases.length - planted
  if (cases.length < 12) checks.push(fail('eval suite should have at least 12 cases'))
  if (controls < 2) checks.push(fail('eval suite should have at least 2 clean controls'))
  checks.push(ok(`eval suite checked (${planted} planted, ${controls} controls)`))
}

function validateLinks(checks, { files }) {
  const markdown = filesWithExtensions(files, ['.md'])
  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g
  for (const file of markdown) {
    // Strip fenced code blocks and inline code spans before matching links:
    // `icons[index](illo);` inside a JS sample is code, not a markdown link.
    const text = readFileSync(file, 'utf8')
      .replace(/```[\s\S]*?```/g, '')
      .replace(/~~~[\s\S]*?~~~/g, '')
      .replace(/`[^`\n]*`/g, '')
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

function privacyScan(checks, { files }) {
  const offenders = []
  for (const file of filesWithExtensions(files, privacyScanExtensions)) {
    if (file.includes('plugins/dev-skills/skills/drawio-skill/data/lobe-icons.json')) continue
    const text = readFileSync(file, 'utf8')
    const pattern = privatePatterns.find((candidate) => candidate.test(text))
    if (pattern) offenders.push(`${rel(file)} matches ${pattern}`)
  }
  if (offenders.length) offenders.forEach((item) => checks.push(fail(`private coupling: ${item}`)))
  else checks.push(ok('privacy scan found no private project coupling'))
}

function validate() {
  const checks = []
  const validationContext = {
    files: walkFiles(root),
    skillDirs: skillDirs()
  }
  for (const validator of [
    validateJsonFiles,
    validateYamlFiles,
    validatePlugin,
    validateReleaseVersions,
    validateSkills,
    validateProvenance,
    validateProfiles,
    validatePiPackageResearch,
    validatePolicies,
    validateEvals,
    validateLinks,
    privacyScan
  ]) validator(checks, validationContext)
  return printChecks(checks)
}

function runtimeTargets() {
  return [
    ['Claude', path.join(homedir(), '.claude/skills')],
    ['Claude secondary', path.join(homedir(), '.claude-very/skills')],
    ['Codex', path.join(homedir(), '.agents/skills')],
    ['Pi', path.join(homedir(), '.pi/agent/skills')],
    ['OpenCode commands', path.join(homedir(), '.config/opencode/command')]
  ]
}

function doctor() {
  const checks = []
  for (const name of ['node', 'npm', 'git', 'rg', 'hypa', 'claude', 'pi', 'opencode', 'semgrep']) {
    const version = commandVersion(name)
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
  const dirs = skillDirs()
  console.log(`# agent-dev-kit inventory\n`)
  console.log(`Root: ${root}`)
  console.log(`Skills: ${dirs.length}`)
  for (const dir of dirs) {
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
