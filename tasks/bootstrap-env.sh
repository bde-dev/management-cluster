#!/bin/bash
#MISE description="Ensure .env holds each required key that isn't already provided (via .env or the shell env)"
set -euo pipefail

ENV_FILE=".env"
# CLIENT_ID is non-secret and lives in mise.toml [env]. CLIENT_SECRET is the one
# value you supply; the rest are pulled from Key Vault by `mise run pull-secrets`.
KEYS=(CLIENT_SECRET OMNI_ENDPOINT OMNI_SERVICE_ACCOUNT_KEY GITHUB_USERNAME GITHUB_MANAGEMENT_REPO_PAT_TOKEN)

[ -f "$ENV_FILE" ] || : > "$ENV_FILE"

added=0
for key in "${KEYS[@]}"; do
  grep -q "^${key}=" "$ENV_FILE" && continue
  [ -n "$(printenv "$key" 2>/dev/null || true)" ] && continue
  printf '%s=\n' "$key" >> "$ENV_FILE"
  added=$((added + 1))
done

echo "✓ .env ready ($added empty key(s) added; existing and shell-provided keys left untouched)"
echo "  CLIENT_SECRET is the only value you supply — export it, or fill it in .env."
echo "  OMNI + GitHub secrets are filled by:  mise run pull-secrets"
