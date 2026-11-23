#!/usr/bin/env bash
# End-to-end check: every folder in tenants/ must become a synced, healthy
# namespace with its guardrails in place.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT="${TIMEOUT:-300}"

retry() { # retry <seconds> <description> <command...>
  local deadline=$((SECONDS + $1)) what="$2"; shift 2
  until "$@" >/dev/null 2>&1; do
    if (( SECONDS > deadline )); then echo "FAIL: timed out waiting for $what" >&2; return 1; fi
    sleep 5
  done
  echo "ok: $what"
}

app_status() { # app_status <app> -> "Synced/Healthy"
  kubectl -n argocd get application "$1" \
    -o jsonpath='{.status.sync.status}/{.status.health.status}'
}

for dir in "$ROOT"/tenants/*/; do
  tenant="$(basename "$dir")"
  ns="tenant-$tenant"
  app="tenant-$tenant"

  retry "$TIMEOUT" "application $app exists" kubectl -n argocd get application "$app"
  retry "$TIMEOUT" "application $app Synced/Healthy" \
    bash -c "[[ \"\$(kubectl -n argocd get application $app -o jsonpath='{.status.sync.status}/{.status.health.status}')\" == Synced/Healthy ]]"
  kubectl get namespace "$ns" >/dev/null
  kubectl -n "$ns" get resourcequota tenant-quota >/dev/null
  kubectl -n "$ns" get limitrange tenant-defaults >/dev/null
  echo "ok: $ns has quota and limit range ($(app_status "$app"))"

  # Pod Security Admission must reject a privileged pod in every tenant namespace.
  if kubectl -n "$ns" run psa-probe --image=busybox --privileged --dry-run=server -o name >/dev/null 2>&1; then
    echo "FAIL: privileged pod was accepted in $ns" >&2
    exit 1
  fi
  echo "ok: $ns rejects privileged pods"
done

echo "All tenants passed."
