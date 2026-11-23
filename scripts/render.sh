#!/usr/bin/env bash
# Renders every tenant and the platform chart into out/ so CI can lint the real manifests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/out"
rm -rf "$OUT" && mkdir -p "$OUT"

helm template platform "$ROOT/platform" \
  --set repoURL=https://github.com/example/golden-path-platform.git > "$OUT/platform.yaml"

for file in "$ROOT"/tenants/*/tenant.yaml; do
  tenant="$(basename "$(dirname "$file")")"
  helm template "tenant-$tenant" "$ROOT/charts/tenant" --values "$file" > "$OUT/tenant-$tenant.yaml"
done
ls "$OUT"
