#!/usr/bin/env bash
# Collects cluster state after a failed CI run and publishes it where it can be
# read without signing in: the job summary and error annotations.
set -uo pipefail

section() { # section <title> <command...>
  local title="$1"; shift
  local out; out="$("$@" 2>&1 | tail -n 40)"
  printf '### %s\n```\n%s\n```\n' "$title" "$out" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
  # Annotations are single-line; GitHub decodes %0A as a newline.
  local encoded="${out//'%'/'%25'}"; encoded="${encoded//$'\n'/'%0A'}"
  echo "::error title=${title}::${encoded:0:4000}"
}

section "Helm releases" helm list -A
section "Pods not Running/Completed" bash -c "kubectl get pods -A -o wide | grep -vE ' (Running|Completed) ' || true"
section "Argo CD applications" kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,MESSAGE:.status.conditions[*].message
section "Warning events" bash -c "kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 25"
section "Cilium status" kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --brief
