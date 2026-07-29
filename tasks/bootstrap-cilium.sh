#!/bin/bash
#MISE description="Bootstrap Cilium CNI on management-cluster so nodes go Ready and ArgoCD can adopt it"
set -euo pipefail

CLUSTER="management-cluster"

# Resolve this cluster's kube-context by name (contexts are merged by gather-configs).
CTX="$(kubectl config get-contexts -o name | grep -- "$CLUSTER" | head -1 || true)"
if [ -z "$CTX" ]; then
  echo "Error: no kube-context matching '$CLUSTER' — run 'mise run gather-configs' first."
  exit 1
fi

# Chart version + values match the ArgoCD-managed Cilium (application-sets/cilium),
# so ArgoCD adopts this release cleanly instead of reconciling a divergent install.
echo "▶ Bootstrapping Cilium 1.18.1 on context: $CTX"
helm upgrade --install cilium cilium \
  --repo https://helm.cilium.io \
  --version 1.18.1 \
  --kube-context "$CTX" \
  --namespace kube-system \
  --wait --timeout 10m \
  -f infrastructure/cilium/values.yaml

echo "▶ Waiting for node(s) to become Ready..."
kubectl wait --for=condition=Ready node --all --timeout=180s --context "$CTX"

echo "✓ Cilium bootstrapped on $CLUSTER ($CTX)."
echo "  ArgoCD adopts it on next sync and adds clustermesh identity (cluster.name/id)."
