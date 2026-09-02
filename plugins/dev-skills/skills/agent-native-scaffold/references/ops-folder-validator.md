# Ops-folder local validator — verified recipe

When you apply the ANRS scaffolding to a **non-Git ops/records folder** (Kommit
billing, vendor artifacts, signing keys, signed PDFs, etc.), the external
`audit-agent-native.py` check is necessary but not sufficient. It checks
structure and depth, not the business invariants of the folder.

This reference documents the local validator pattern verified on
`/home/user/kommit/ops` (renamed from `empresa`) on 2026-08-31.

## Why a local validator

The external audit is generic by design. It will not know that:

- `digital-id/*.p12` files must be `0o600`.
- `~/.config/kommit-invoice/.env` must be `0o600`.
- `~/.local/state/kommit-invoice/` (runtime state) must be `0o700`.
- `invoices/YYYY-MM/Invoice - <Full Name> - <start> - <end>.pdf` must be a
  signed PDF (`pdfsig` validates the signature).
- Old directory names (`empresa/`, `empresa-backup/`, etc.) must not be
  present anywhere in the tree.
- Markdown links must resolve to a real file (no broken cross-references
  after the rename pass).

A one-shot script that runs all of these and returns a JSON
`status: PASS/FAIL` makes the scaffold's exit criterion unambiguous and
diff-able across refactors.

## Verified recipe

Create `scripts/validate_ops.py` (or repo-equivalent) at the ops-folder
root. Run as:

```bash
python3 /home/user/kommit/ops/scripts/validate_ops.py --json
```

Expected output shape:

```json
{
  "status": "PASS",
  "root": "/home/user/kommit/ops",
  "directory_count": 24,
  "file_count": 109,
  "max_file_depth": 4,
  "checks": {
    "canonical_names": true,
    "digital_id_mode": "0o600",
    "env_mode": "0o600",
    "final_pdf_present": true,
    "final_pdf_signature": true,
    "hub": true,
    "invoice_index": true,
    "invoice_month_partition": true,
    "markdown_links": true,
    "old_directories_absent": true,
    "registry_structure": true,
    "registry_yaml": "structural-only-no-pyyaml",
    "required_paths": true,
    "stale_paths": true,
    "state_dir_mode": "0o700",
    "state_file_mode": "absent-ok"
  },
  "errors": []
}
```

The `state_file_mode: "absent-ok"` value covers the "the state file has
not been created yet, only its parent dir" case. The check should report
the mode only when the file exists; otherwise it should be a non-error
`absent-ok` marker.

The `registry_yaml: "structural-only-no-pyyaml"` value covers PEP-668
hosts where `pyyaml` is not importable without a venv. The check should
use a structural regex (or shell out to `yq`/`uv run --with pyyaml`) and
still report `true` when the file is well-formed.

## Companion: portable-root TDD

The validator checks structure, not script portability. For every ops
script that derives its location from `__file__` (Python) or
`$BASH_SOURCE` (bash), write a TDD test that runs the script with the
`KOMMIT_OPS_ROOT` env var pointed at a fresh tempdir and asserts the
script wrote to the relocated root, not the real one.

```python
import os, subprocess, sys, tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="kommit-ops-portable-") as td:
    root = Path(td) / "relocated-ops"
    env = os.environ.copy()
    env["KOMMIT_OPS_ROOT"] = str(root)
    r = subprocess.run(
        [sys.executable, "scripts/worklogs/daily_log.py", "msg", "0:15"],
        env=env, capture_output=True, text=True
    )
    assert r.returncode == 0
    expected = root / "worklogs" / "daily" / f"worklog-{today}.txt"
    assert expected.is_file()
    assert expected.read_text().startswith("msg; 0:15; ")
```

The portable-root test catches the "first run with no env falls back to
the real path silently" regression that the lint-only checks miss.

## Pitfalls

- **Do not let the validator call `print` for human-friendly output when
  `--json` is set.** The whole point of the `--json` flag is to be
  diff-able across refactors. Always emit one JSON object to stdout, and
  use stderr for human-only progress messages.
- **Do not depend on `pyyaml` if the host is PEP-668.** Either do a
  structural regex check, or run via `uv run --with pyyaml`. The validator
  must run with the system `python3` to keep the operator's path simple.
- **The validator must not execute the production scripts against the
  real `.env`.** The validator checks *shape* (file exists, mode 0o600,
  contains the expected keys) — it must never run a script that fires
  email, opens a Discord session, or signs a PDF.
- **The signed-PDF check uses `pdfsig`.** It must require
  `Signature Validation: Signature is Valid.` AND
  `Total document signed` — either alone is a false positive on partial
  signatures.
- **`__pycache__` directories that the script writes inflate file_count
  by 4-8 items per script.** Run the validator from a state that already
  has caches cleaned, or filter `__pycache__` out of the count.
