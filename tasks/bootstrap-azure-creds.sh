#!/usr/bin/env bash
#MISE description="Seed the azure-creds Service Principal secret (external-secrets Key Vault auth) into one cluster context (--cluster) or all contexts (default)"
#MISE confirm="Seed azure-creds into the resolved cluster(s)?"
#USAGE flag "-c --cluster <name>" help="Limit to contexts matching this substring (default: all contexts)"
set -euo pipefail

# The azure-kv-store-homelab ClusterSecretStore is deployed to every cluster and
# authenticates to Key Vault with a Service Principal read from secret
# azure-creds/external-secrets (keys ClientID + ClientSecret). That secret carries the
# client secret, so it is seeded imperatively per-cluster rather than committed to GitOps.
# Interactive run prompts (confirm); unattended callers use `mise -y run bootstrap-azure-creds`.
: "${CLIENT_ID:?set in mise.toml [env]}"
: "${CLIENT_SECRET:?export it or add CLIENT_SECRET=… to .env}"

NAMESPACE="external-secrets"

sel="${usage_cluster:-}"
CONTEXTS="$(kubectl config get-contexts -o name | { [ -n "$sel" ] && grep -- "$sel" || cat; })"
[ -n "$CONTEXTS" ] || { echo "No matching kube-context — run 'mise run gather-configs' first."; exit 1; }

while IFS= read -r ctx; do
  [ -n "$ctx" ] || continue
  echo "▶ Seeding azure-creds into $NAMESPACE on context: $ctx"
  kubectl create namespace "$NAMESPACE" --context "$ctx" --dry-run=client -o yaml \
    | kubectl apply --context "$ctx" -f -
  kubectl apply --context "$ctx" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: azure-creds
  namespace: $NAMESPACE
type: Opaque
stringData:
  ClientID: ${CLIENT_ID}
  ClientSecret: ${CLIENT_SECRET}
EOF
  echo "✓ azure-creds present on $ctx."
done <<< "$CONTEXTS"

echo ""
echo "✓ azure-creds seeded for: $(echo "$CONTEXTS" | paste -sd' ' -)"
echo "  external-secrets can now authenticate to Key Vault on these clusters;"
echo "  blocked ExternalSecrets resolve on their next refresh."
