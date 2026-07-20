#!/bin/bash
#MISE description="Bootstrap the devpod: scaffold .env, pull secrets, fetch kubeconfigs"
set -euo pipefail

mise run bootstrap-env
echo ""
mise run pull-secrets
echo ""
mise run gather-configs

echo ""
echo "▶ Devpod ready: secrets in .env, kubeconfigs fetched."
echo "  Provision the cluster (one-time) with:  scripts/bootstrap"
