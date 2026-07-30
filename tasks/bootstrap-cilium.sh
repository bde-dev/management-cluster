#!/usr/bin/env bash
#MISE description="Bootstrap Cilium CNI on one cluster context (--cluster) or all contexts (default) so nodes go Ready and ArgoCD can adopt it"
#MISE confirm="Bootstrap Cilium into the resolved cluster(s)?"
#USAGE flag "-c --cluster <name>" help="Limit to contexts matching this substring (default: all contexts)"
set -euo pipefail

# Cilium install is cluster-agnostic: values point at KubePrism (localhost:7445),
# so the same chart + values are correct on every Talos cluster. ArgoCD adopts each
# release on next sync and stamps per-cluster clustermesh identity (cluster.name/id).
# Idempotent (helm upgrade --install); a no-op where Cilium is already present.
# Interactive run prompts (confirm); unattended callers use `mise -y run bootstrap-cilium`.
sel="${usage_cluster:-}"
CONTEXTS="$(kubectl config get-contexts -o name | { [ -n "$sel" ] && grep -- "$sel" || cat; })"
[ -n "$CONTEXTS" ] || { echo "No matching kube-context — run 'mise run gather-configs' first."; exit 1; }

while IFS= read -r ctx; do
  [ -n "$ctx" ] || continue
  echo "▶ Bootstrapping Cilium 1.18.1 on context: $ctx"
  helm upgrade --install cilium cilium \
    --repo https://helm.cilium.io \
    --version 1.18.1 \
    --kube-context "$ctx" \
    --namespace kube-system \
    --wait --timeout 10m \
    -f infrastructure/cilium/values.yaml
  kubectl wait --for=condition=Ready node --all --timeout=180s --context "$ctx"
  echo "✓ Cilium bootstrapped on $ctx."
done <<< "$CONTEXTS"

echo ""
echo "✓ Cilium bootstrap complete for: $(echo "$CONTEXTS" | paste -sd' ' -)"
echo "  Once a remote cluster is registered, management's ArgoCD deploys Cilium to it via"
echo "  the cilium ApplicationSet — manual bootstrap is only needed pre-registration."
