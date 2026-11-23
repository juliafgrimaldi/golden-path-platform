#!/usr/bin/env bash
# Bootstraps the whole platform on a local kind cluster:
#   kind -> Cilium -> Argo CD -> root Application (everything else comes from Git).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bootstrap/versions.env
source "$ROOT/bootstrap/versions.env"

CLUSTER_NAME="${CLUSTER_NAME:-golden-path}"
REPO_URL="${REPO_URL:-$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)}"
REVISION="${REVISION:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)}"

# Argo CD reads the repo anonymously, so it needs an https URL to a public repo.
if [[ "$REPO_URL" =~ ^git@github\.com:(.+)$ ]]; then
  REPO_URL="https://github.com/${BASH_REMATCH[1]}"
fi
if [[ -z "$REPO_URL" ]]; then
  echo "error: no git remote found. Push this repo to GitHub or set REPO_URL=https://github.com/<you>/<repo>.git" >&2
  exit 1
fi

log() { printf '\n==> %s\n' "$*"; }

for bin in kind kubectl helm; do
  command -v "$bin" >/dev/null || { echo "error: '$bin' is required" >&2; exit 1; }
done

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  log "kind cluster '$CLUSTER_NAME' already exists, reusing it"
else
  log "Creating kind cluster '$CLUSTER_NAME'"
  kind create cluster --name "$CLUSTER_NAME" --config "$ROOT/bootstrap/kind-config.yaml"
fi
kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

log "Installing Cilium $CILIUM_CHART_VERSION"
helm repo add cilium https://helm.cilium.io >/dev/null
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update cilium argo >/dev/null
helm upgrade --install cilium cilium/cilium \
  --version "$CILIUM_CHART_VERSION" \
  --namespace kube-system \
  --values "$ROOT/bootstrap/cilium-values.yaml" \
  --set k8sServiceHost="${CLUSTER_NAME}-control-plane" \
  --wait --timeout 10m
kubectl wait --for=condition=Ready nodes --all --timeout=5m

log "Installing Argo CD (chart $ARGOCD_CHART_VERSION)"
helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --values "$ROOT/bootstrap/argocd-values.yaml" \
  --wait --timeout 10m

log "Pointing Argo CD at $REPO_URL @ $REVISION"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: $REVISION
    path: platform
    helm:
      parameters:
        - name: repoURL
          value: $REPO_URL
        - name: targetRevision
          value: $REVISION
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

log "Done. Argo CD UI:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:80"
echo "  user: admin  password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
