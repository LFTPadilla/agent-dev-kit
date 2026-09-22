#!/usr/bin/env node
// Validate a task-class routing policy against the classifier-policy schema.
//
// Usage: node check-classifier-policy.mjs [--json] <policy.yml|policy.json>
//
// Exit code 0 means the policy is valid. Exit code 1 means at least one rule
// failed. Exit code 2 means the file could not be read or parsed.
//
// The checker reads the policy only. It never routes a task and never calls a
// remote service.
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import process from 'node:process'

const require = createRequire(import.meta.url)

const HARNESSES = new Set(['claude', 'codex', 'pi', 'opencode', 'hermes', 'any'])
const EFFORTS = new Set(['low', 'medium', 'high'])
const CONSEQUENCES = new Set(['low', 'medium', 'high'])
const MODES = new Set(['shadow', 'enforce'])
const TOP_KEYS = new Set(['version', 'updated', 'policy', 'classes'])
const POLICY_KEYS = new Set(['name', 'mode', 'default_route', 'thresholds'])
const THRESHOLD_KEYS = new Set(['delegate', 'review'])
const CLASS_KEYS = new Set(['criteria', 'consequence', 'route', 'fallback', 'notes'])
const ROUTE_KEYS = new Set(['harness', 'model', 'effort'])
const TIER_PATTERN = /^[a-z0-9][a-z0-9._-]*$/
const CLASS_PATTERN = /^[a-z][a-z0-9-]*$/
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/

const ok = (msg) => ({ level: 'ok', msg })
const fail = (msg) => ({ level: 'fail', msg })

const isObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value)
const listOf = (set) => [...set].join(', ')

function checkKeys(value, allowed, label, checks) {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) checks.push(fail(`${label} has unknown key: ${key}`))
  }
}

function requireText(value, label, checks) {
  if (typeof value !== 'string' || !value.trim()) {
    checks.push(fail(`${label} must be a non-empty string`))
    return false
  }
  return true
}

function validateRoute(route, label, checks) {
  if (!isObject(route)) {
    checks.push(fail(`${label} must be a mapping`))
    return
  }
  checkKeys(route, ROUTE_KEYS, label, checks)
  for (const field of ['harness', 'model', 'effort']) requireText(route[field], `${label}.${field}`, checks)
  if (typeof route.harness === 'string' && !HARNESSES.has(route.harness)) {
    checks.push(fail(`${label}.harness must be one of: ${listOf(HARNESSES)}`))
  }
  if (typeof route.effort === 'string' && !EFFORTS.has(route.effort)) {
    checks.push(fail(`${label}.effort must be one of: ${listOf(EFFORTS)}`))
  }
  if (typeof route.model === 'string' && route.model.trim()) {
    if (route.model.includes('/')) {
      checks.push(fail(`${label}.model must be a tier token, not a vendor model path`))
    } else if (!TIER_PATTERN.test(route.model)) {
      checks.push(fail(`${label}.model must match ${TIER_PATTERN}`))
    }
  }
}

function validateThresholds(thresholds, checks) {
  if (!isObject(thresholds)) {
    checks.push(fail('policy.thresholds must be a mapping'))
    return
  }
  checkKeys(thresholds, THRESHOLD_KEYS, 'policy.thresholds', checks)
  for (const name of ['delegate', 'review']) {
    const value = thresholds[name]
    if (typeof value !== 'number' || Number.isNaN(value)) {
      checks.push(fail(`policy.thresholds.${name} must be a number`))
    } else if (value <= 0 || value > 1) {
      checks.push(fail(`policy.thresholds.${name} must be greater than 0 and at most 1`))
    }
  }
  const { delegate, review } = thresholds
  if (typeof delegate === 'number' && typeof review === 'number' && !(review < delegate)) {
    checks.push(fail('policy.thresholds.review must be below policy.thresholds.delegate'))
  }
}

function validateClasses(classes, checks) {
  if (!isObject(classes) || !Object.keys(classes).length) {
    checks.push(fail('classes must be a non-empty mapping'))
    return 0
  }
  const names = Object.keys(classes)
  for (const name of names) {
    const label = `classes.${name}`
    if (!CLASS_PATTERN.test(name)) checks.push(fail(`${label} must match ${CLASS_PATTERN}`))
    const entry = classes[name]
    if (!isObject(entry)) {
      checks.push(fail(`${label} must be a mapping`))
      continue
    }
    checkKeys(entry, CLASS_KEYS, label, checks)
    if (typeof entry.criteria !== 'string' || entry.criteria.trim().length < 20) {
      checks.push(fail(`${label}.criteria needs 20 characters or more; it is the classifier question text`))
    }
    if (!CONSEQUENCES.has(entry.consequence)) {
      checks.push(fail(`${label}.consequence must be one of: ${listOf(CONSEQUENCES)}`))
    }
    validateRoute(entry.route, `${label}.route`, checks)
    if (entry.fallback !== undefined) validateRoute(entry.fallback, `${label}.fallback`, checks)
    if (entry.consequence === 'high' && entry.fallback === undefined) {
      checks.push(fail(`${label} has consequence high and needs a fallback route`))
    }
  }
  return names.length
}

function validatePolicy(data, checks) {
  if (!isObject(data)) {
    checks.push(fail('the policy file must contain a mapping at the top level'))
    return
  }
  checkKeys(data, TOP_KEYS, 'the policy file', checks)
  requireText(data.version, 'version', checks)
  if (typeof data.updated !== 'string' || !DATE_PATTERN.test(data.updated)) {
    checks.push(fail('updated must be a date in YYYY-MM-DD form'))
  }
  const policy = data.policy
  if (!isObject(policy)) {
    checks.push(fail('policy must be a mapping'))
  } else {
    checkKeys(policy, POLICY_KEYS, 'policy', checks)
    requireText(policy.name, 'policy.name', checks)
    if (!MODES.has(policy.mode)) checks.push(fail(`policy.mode must be one of: ${listOf(MODES)}`))
    validateRoute(policy.default_route, 'policy.default_route', checks)
    validateThresholds(policy.thresholds, checks)
  }
  const count = validateClasses(data.classes, checks)
  if (count) {
    checks.push(ok(`${count} task classes declared; mode is ${policy?.mode ?? 'missing'}`))
  }
}

function readPolicy(file) {
  const text = readFileSync(file, 'utf8')
  if (file.endsWith('.json')) return JSON.parse(text)
  // `yaml` is a dependency of the kit root. Resolve it lazily so a missing
  // install reports one clear line instead of a stack trace.
  let parse
  try {
    ;({ parse } = require('yaml'))
  } catch {
    throw new Error('the yaml package is not installed; run npm ci in the kit root')
  }
  return parse(text)
}

const args = process.argv.slice(2)
const asJson = args.includes('--json')
const file = args.find((arg) => !arg.startsWith('--'))

if (!file) {
  console.error('usage: check-classifier-policy.mjs [--json] <policy.yml|policy.json>')
  process.exit(2)
}

let data
try {
  data = readPolicy(file)
} catch (error) {
  if (asJson) console.log(JSON.stringify({ file, status: 'unreadable', error: error.message }, null, 2))
  else console.error(`FAIL ${file} could not be read: ${error.message}`)
  process.exit(2)
}

const checks = [ok(`${file} parses`)]
validatePolicy(data, checks)

const failures = checks.filter((check) => check.level === 'fail')

if (asJson) {
  console.log(JSON.stringify({ file, status: failures.length ? 'invalid' : 'valid', failures: failures.map((check) => check.msg), checks: checks.length }, null, 2))
} else {
  for (const check of checks) console.log(`${check.level === 'ok' ? 'OK' : 'FAIL'} ${check.msg}`)
  console.log(`\n${checks.length} checks: ${failures.length} failed`)
}

process.exit(failures.length ? 1 : 0)
