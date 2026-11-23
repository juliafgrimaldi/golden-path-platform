#!/usr/bin/env python3
"""Checks every tenants/*/tenant.yaml before Argo CD ever sees it.

Helm already enforces charts/tenant/values.schema.json at render time. This
script runs the same schema in CI with readable errors, plus the rules a
single-file schema cannot express (folder name, uniqueness across tenants).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft7Validator, FormatChecker

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = json.loads((ROOT / "charts/tenant/values.schema.json").read_text())


def main() -> int:
    validator = Draft7Validator(SCHEMA, format_checker=FormatChecker())
    errors: list[str] = []
    cost_centers: dict[str, str] = {}

    tenant_dirs = sorted(p for p in (ROOT / "tenants").iterdir() if p.is_dir())
    if not tenant_dirs:
        errors.append("tenants/: no tenants found")

    for tenant_dir in tenant_dirs:
        file = tenant_dir / "tenant.yaml"
        where = file.relative_to(ROOT).as_posix()
        if not file.exists():
            errors.append(f"{where}: missing")
            continue
        try:
            tenant = yaml.safe_load(file.read_text())
        except yaml.YAMLError as exc:
            errors.append(f"{where}: invalid YAML: {exc}")
            continue

        for err in sorted(validator.iter_errors(tenant), key=lambda e: list(e.path)):
            field = ".".join(str(p) for p in err.path) or "(root)"
            errors.append(f"{where}: {field}: {err.message}")

        if not isinstance(tenant, dict):
            continue
        if tenant.get("name") != tenant_dir.name:
            errors.append(f"{where}: name '{tenant.get('name')}' must match folder '{tenant_dir.name}'")
        cc = tenant.get("costCenter")
        if cc in cost_centers:
            errors.append(f"{where}: costCenter {cc} already used by {cost_centers[cc]}")
        elif cc:
            cost_centers[cc] = tenant_dir.name

    for line in errors:
        print(f"ERROR {line}")
    print(f"{len(tenant_dirs)} tenant(s) checked, {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
