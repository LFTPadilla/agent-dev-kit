#!/usr/bin/env bash
# Contract test for the classifier-policy skill.
#
# Asserts that the shipped example policies pass the checker, and that the
# checker rejects the defects the schema claims to catch. Every negative case is
# built from a good policy at run time, so the fixtures cannot drift from the
# shipped examples.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/dev-skills/skills/classifier-policy"
CHECK="$SKILL/scripts/check-classifier-policy.mjs"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

pass() { echo "ok - $1"; }
die() { echo "FAIL - $1" >&2; exit 1; }

run_check() {
  node "$CHECK" "$@" >/dev/null 2>&1
}

# 1. The shipped examples are valid.
for example in "$SKILL/examples/policy.basic.yml" "$SKILL/examples/policy.json"; do
  run_check "$example" || die "$(basename "$example") should be valid"
  pass "shipped example is valid: $(basename "$example")"
done

# 2. A valid policy passes in JSON mode with exit code 0.
node "$CHECK" --json "$SKILL/examples/policy.basic.yml" | grep -q '"status": "valid"' \
  || die "--json should report status valid"
pass "--json reports a valid policy"

# 3. An unreadable path exits 2.
if run_check "$FIXTURE/absent.yml"; then
  die "a missing file should not exit 0"
else
  [ $? -eq 2 ] || die "a missing file should exit 2"
fi
pass "a missing file exits 2"

# 4. Negative cases. Each one mutates the shipped example, so a schema change
#    cannot leave these fixtures stale.
good="$SKILL/examples/policy.basic.yml"

expect_invalid() {
  local label="$1" file="$2"
  if run_check "$file"; then
    die "$label should be invalid"
  fi
  pass "rejects $label"
}

# 4a. review above delegate makes the delegate band unreachable.
sed 's/    review: 0.6/    review: 0.95/' "$good" > "$FIXTURE/threshold-order.yml"
expect_invalid "thresholds.review above thresholds.delegate" "$FIXTURE/threshold-order.yml"

# 4b. A vendor model path in the model field breaks portability.
sed 's/      model: cheap-tier/      model: vendor\/model-name/' "$good" > "$FIXTURE/vendor-model.yml"
expect_invalid "a vendor model path" "$FIXTURE/vendor-model.yml"

# 4c. An unknown key is a silent routing defect, so it must fail.
sed 's/^    consequence: low$/    consequence: low\n    priority: 1/' "$good" > "$FIXTURE/unknown-key.yml"
expect_invalid "an unknown class key" "$FIXTURE/unknown-key.yml"

# 4d. An unknown effort value cannot be applied by any harness.
sed 's/      effort: low/      effort: turbo/' "$good" > "$FIXTURE/bad-effort.yml"
expect_invalid "an unknown effort value" "$FIXTURE/bad-effort.yml"

# 4e. A high-consequence class without a fallback has no safe route.
python3 - "$good" "$FIXTURE/no-fallback.yml" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
# Drop the fallback block of the high-consequence class.
head, _, tail = text.partition("    fallback:\n")
assert tail, "fixture source lost its fallback block"
open(sys.argv[2], "w", encoding="utf-8").write(head)
PY
expect_invalid "a high-consequence class without a fallback" "$FIXTURE/no-fallback.yml"

# 4f. Criteria shorter than 20 characters cannot classify anything.
python3 - "$good" "$FIXTURE/short-criteria.yml" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
patched, count = re.subn(r"(?m)^    criteria: .+$", "    criteria: small change", text, count=1)
assert count == 1, "fixture source lost its criteria field"
open(sys.argv[2], "w", encoding="utf-8").write(patched)
PY
expect_invalid "criteria shorter than 20 characters" "$FIXTURE/short-criteria.yml"

# 4g. An empty classes mapping routes nothing.
python3 - "$good" "$FIXTURE/no-classes.yml" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
head, _, _ = text.partition("classes:\n")
open(sys.argv[2], "w", encoding="utf-8").write(head + "classes: {}\n")
PY
expect_invalid "an empty classes mapping" "$FIXTURE/no-classes.yml"

# 5. The skill is registered where the kit's own validate expects it.
grep -q 'classifier-policy' "$ROOT/REGISTRY.yaml" || die "REGISTRY.yaml does not list classifier-policy"
grep -q 'classifier-policy' "$ROOT/skill-provenance.json" || die "skill-provenance.json does not list classifier-policy"
grep -q 'classifier-policy' "$ROOT/docs/skills-catalog.md" || die "docs/skills-catalog.md does not list classifier-policy"
pass "the skill is registered in REGISTRY.yaml, skill-provenance.json, and the catalog"

echo "classifier-policy contract ok"
