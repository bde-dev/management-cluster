#!/bin/bash
#MISE description="Fetch kubeconfigs for all clusters from Omni (service-account) into ~/.kube/config"
set -euo pipefail

# TODO(pre-hardware): runners-cluster is not provisioned in Omni yet — its
# kubeconfig fetch fails (and aborts the loop) until the cluster exists.
for cluster in management-cluster private-cluster public-cluster runners-cluster; do
  echo "═══ $cluster ═══"
  omnictl kubeconfig --cluster "$cluster" --service-account --user "$USER"
  echo "✓ $cluster kubeconfig merged"
done

echo ""
echo "✅ kubeconfigs fetched. Contexts:"
kubectl config get-contexts
