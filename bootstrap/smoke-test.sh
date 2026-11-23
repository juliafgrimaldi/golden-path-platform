#!/usr/bin/env bash
# End-to-end checks against a running cluster:
#   1. every folder in tenants/ is a synced, healthy namespace with its guardrails
#   2. network isolation between the example tenants behaves as declared
#   3. Kyverno blocks what tenants must not do
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

app_healthy() {
  [[ "$(kubectl -n argocd get application "$1" -o jsonpath='{.status.sync.status}/{.status.health.status}')" == Synced/Healthy ]]
}

# --- 1. tenants ---------------------------------------------------------------
for dir in "$ROOT"/tenants/*/; do
  tenant="$(basename "$dir")"
  ns="tenant-$tenant"
  retry "$TIMEOUT" "application tenant-$tenant Synced/Healthy" app_healthy "tenant-$tenant"
  kubectl -n "$ns" get resourcequota tenant-quota >/dev/null
  kubectl -n "$ns" get limitrange tenant-defaults >/dev/null
  kubectl -n "$ns" get ciliumnetworkpolicy tenant-isolation >/dev/null
  echo "ok: $ns has quota, limit range and network policy"

  if kubectl -n "$ns" run psa-probe --image=busybox --privileged --dry-run=server -o name >/dev/null 2>&1; then
    echo "FAIL: privileged pod was accepted in $ns" >&2; exit 1
  fi
  echo "ok: $ns rejects privileged pods"
done

# --- 2. network isolation -----------------------------------------------------
# search declares allowFrom: payments on 8080; payments allows nobody.
deploy_probes() { # an echo server + a client, compliant with Pod Security "restricted"
  kubectl apply -n "$1" -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: echo
  labels: {app: echo}
spec:
  securityContext: {runAsNonRoot: true, runAsUser: 65534, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: echo
      image: busybox:1.36
      command: ["sh", "-c", "echo ok > /tmp/index.html && exec httpd -f -p 8080 -h /tmp"]
      ports: [{containerPort: 8080}]
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
---
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  selector: {app: echo}
  ports: [{port: 8080, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata:
  name: client
spec:
  securityContext: {runAsNonRoot: true, runAsUser: 65534, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: client
      image: busybox:1.36
      command: ["sleep", "3600"]
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
YAML
  kubectl -n "$1" wait --for=condition=Ready pod/echo pod/client --timeout=180s >/dev/null
}

can_reach() { # can_reach <from-ns> <to-ns>
  kubectl -n "$1" exec client -- wget -qO- -T 5 "http://echo.$2.svc.cluster.local:8080" 2>/dev/null | grep -qx ok
}

expect_reach() { # retried: a new pod's policy can take a few seconds to be programmed
  retry 60 "$1 -> $2 allowed" can_reach "$1" "$2"
}
expect_blocked() {
  if can_reach "$1" "$2"; then echo "FAIL: $1 -> $2 should be blocked" >&2; exit 1; else echo "ok: $1 -> $2 blocked"; fi
}

deploy_probes tenant-search
deploy_probes tenant-payments
expect_reach   tenant-search   tenant-search     # same namespace
expect_reach   tenant-payments tenant-search     # granted by search's allowFrom
expect_blocked tenant-search   tenant-payments   # payments grants nobody

# --- 3. Kyverno guardrails ----------------------------------------------------
denied() { # succeeds only if the server rejects the request
  ! "$@" >/dev/null 2>&1
}

daemonset_dry_run() {
  kubectl apply -n tenant-payments --dry-run=server -f - <<'YAML'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: sneaky-agent
spec:
  selector: {matchLabels: {app: sneaky-agent}}
  template:
    metadata: {labels: {app: sneaky-agent}}
    spec:
      containers: [{name: agent, image: busybox:1.36}]
YAML
}

retry "$TIMEOUT" "Kyverno rejects DaemonSets in tenant namespaces" denied daemonset_dry_run
retry "$TIMEOUT" "Kyverno rejects deleting a tenant's network policy" \
  denied kubectl -n tenant-payments delete ciliumnetworkpolicy tenant-isolation --dry-run=server

kubectl delete -n tenant-search pod/echo pod/client service/echo --wait=false >/dev/null
kubectl delete -n tenant-payments pod/echo pod/client service/echo --wait=false >/dev/null
echo "All checks passed."
