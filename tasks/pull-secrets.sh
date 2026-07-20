#!/bin/bash
#MISE description="Log in to Azure (service principal) and pull Omni + GitHub secrets from Key Vault into .env"
set -euo pipefail

: "${AZURE_TENANT_ID:?set in mise.toml [env]}"
: "${AKV_VAULT_NAME:?set in mise.toml [env]}"
: "${CLIENT_ID:?set in mise.toml [env]}"
: "${CLIENT_SECRET:?export CLIENT_SECRET or set it in .env}"

ENV_FILE=".env"

echo "Logging in to Azure with the service principal..."
az login --service-principal \
  --username "$CLIENT_ID" \
  --password "$CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" \
  --output none
echo "✓ az authenticated"

upsert() {
  local key=$1 val=$2
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    grep -v "^${key}=" "$ENV_FILE" >"$ENV_FILE.tmp"
    mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >>"$ENV_FILE"
}

pull() {
  local kv_name=$1 env_var=$2 val
  val=$(az keyvault secret show --vault-name "$AKV_VAULT_NAME" --name "$kv_name" --query value -o tsv)
  upsert "$env_var" "$val"
  echo "✓ $env_var  ← $kv_name"
}

pull omni-endpoint                    OMNI_ENDPOINT
pull omni-bootstrap-sa-key            OMNI_SERVICE_ACCOUNT_KEY
pull github-management-repo-username  GITHUB_USERNAME
pull github-management-repo-pat-token GITHUB_MANAGEMENT_REPO_PAT_TOKEN

echo ""
echo "✅ Pulled 4 secrets from Key Vault '$AKV_VAULT_NAME' into $ENV_FILE."
echo "   Fetch kubeconfigs with:  mise run gather-configs"
