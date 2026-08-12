#!/bin/bash
#MISE description="Fetch remote clusters' argocd-sa token + CA and store them in Key Vault so management's ArgoCD can register them"
set -euo pipefail

: "${AKV_VAULT_NAME:?set in mise.toml [env]}"

# Resolve target contexts independently (this task is runnable on its own).
PRIVATE_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep private || true)"
PUBLIC_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep public || true)"
# TODO(pre-hardware): the runners cluster is not provisioned yet — until it
# exists (with its kube-system/argocd-sa-token secret), its context cannot
# resolve and this task exits here. Remove this note once it is live.
RUNNERS_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep runners || true)"
if [ -z "$PRIVATE_CLUSTER_CONTEXT" ] || [ -z "$PUBLIC_CLUSTER_CONTEXT" ] || [ -z "$RUNNERS_CLUSTER_CONTEXT" ]; then
  echo "Error: private/public/runners contexts not found — run 'mise run gather-configs' first."
  exit 1
fi

# Extract a target cluster's argocd-sa token + CA and store them (with its API host)
# in Key Vault, so management's ArgoCD can register and manage it remotely.
store_cluster_creds() {
  local ctx=$1 name=$2 api_host=$3
  local ns="kube-system" secret="argocd-sa-token"

  echo "--- Extracting SA token from $name cluster ---"
  kubectl -n "$ns" get secret "$secret" --context "$ctx" -o jsonpath='{.data.token}' |
    base64 -d >"/tmp/argocd-$name-token"
  kubectl -n "$ns" get secret "$secret" --context "$ctx" -o jsonpath='{.data.ca\.crt}' |
    base64 -d >"/tmp/argocd-$name-ca.crt"

  echo "--- Storing $name creds in Azure Key Vault: $AKV_VAULT_NAME ---"
  az keyvault secret set --vault-name "$AKV_VAULT_NAME" \
    --name "argocd-$name-cluster-token" --file "/tmp/argocd-$name-token" --encoding utf-8
  az keyvault secret set --vault-name "$AKV_VAULT_NAME" \
    --name "argocd-$name-cluster-ca-cert" --file "/tmp/argocd-$name-ca.crt" --encoding utf-8
  az keyvault secret set --vault-name "$AKV_VAULT_NAME" \
    --name "argocd-$name-cluster-api-host" --value "$api_host" --encoding utf-8

  rm -f "/tmp/argocd-$name-token" "/tmp/argocd-$name-ca.crt"
  echo "  stored: argocd-$name-cluster-{token,ca-cert,api-host}"
}

store_cluster_creds "$PRIVATE_CLUSTER_CONTEXT" private 192.168.0.31
store_cluster_creds "$PUBLIC_CLUSTER_CONTEXT"  public  192.168.0.32
store_cluster_creds "$RUNNERS_CLUSTER_CONTEXT" runners 192.168.0.33
