#!/usr/bin/env bash
#MISE description="Mint a Harbor project-robot secret into Key Vault; the harbor bootstrap job converges the robot to it. Run before the ExternalSecret that reads it lands"
#MISE confirm="Seed the robot secret into Key Vault?"
#USAGE arg "<project>" help="Harbor project the robot is scoped to (e.g. prebuilds)"
#USAGE arg "<robot>" help="Robot name without the robot$ prefix (e.g. workstation)"
set -euo pipefail

# The harbor bootstrap job (infrastructure/harbor/bootstrap-configmap.yaml) creates each
# project robot and PATCHes its secret to the Key Vault value, so the vault is the source
# of truth and a rebuilt cluster converges to the credential the consumer already holds.
# This task mints that value once and never prints it; consumers read the vault entry
# harbor-<project>-robot-creds (the older gha robot predates this naming).
VAULT=bde-dev-kv-homelab
project="${usage_project:?}"
robot="${usage_robot:?}"
name="harbor-${project}-robot-creds"

if az keyvault secret show --vault-name "$VAULT" --name "$name" -o none 2>/dev/null; then
  echo "✓ $name already exists in $VAULT; not overwritten (rotate by hand if intended)."
  exit 0
fi

# Harbor requires 8-128 chars with at least one upper, one lower and one digit.
secret=""
for _ in $(seq 1 10); do
  # Every stage reads its input to EOF: a head on an unbounded /dev/urandom stream
  # SIGPIPEs tr, which pipefail turns into exit 141.
  candidate="$(head -c 300 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-40)"
  if [[ "$candidate" =~ [A-Z] && "$candidate" =~ [a-z] && "$candidate" =~ [0-9] ]]; then
    secret="$candidate"
    break
  fi
done
[[ -n "$secret" ]] || { echo "could not generate a secret meeting Harbor's character classes" >&2; exit 1; }

az keyvault secret set --vault-name "$VAULT" --name "$name" --value "$secret" \
  --content-type "harbor robot secret: robot\$${project}+${robot}" -o none
echo "✓ $name seeded into $VAULT for robot\$${project}+${robot}."
echo "  Sync the harbor app (or wait for its next sync); the bootstrap job converges the robot to it."
