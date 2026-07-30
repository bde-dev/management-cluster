#!/bin/bash
#MISE description="One-time cluster provision (assumes 'mise run fresh-clone'): Cilium → namespaces → secrets → ArgoCD → GitOps handoff"

# Assumes `mise run fresh-clone` has already run: pull-secrets populated .env and
# authenticated az; gather-configs fetched the kubeconfigs. Light guard on the vars
# this script consumes directly.
require_prereqs() {
  local missing=0
  for v in CLIENT_ID CLIENT_SECRET GITHUB_USERNAME GITHUB_MANAGEMENT_REPO_PAT_TOKEN AKV_VAULT_NAME; do
    [ -n "${!v:-}" ] || {
      echo "  missing: $v"
      missing=1
    }
  done
  if [ "$missing" -ne 0 ]; then
    echo "Error: prerequisites missing — run 'mise run fresh-clone' first."
    exit 1
  fi
}

resolve_contexts() {
  MANAGEMENT_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep management)"
  PRIVATE_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep private)"
  PUBLIC_CLUSTER_CONTEXT="$(kubectl config get-contexts -o name | grep public)"

  if [[ -z $MANAGEMENT_CLUSTER_CONTEXT || -z $PRIVATE_CLUSTER_CONTEXT || -z $PUBLIC_CLUSTER_CONTEXT ]]; then
    echo "Error: cluster contexts not found — run 'mise run fresh-clone' first."
    return 1
  fi

  for ctx in "$MANAGEMENT_CLUSTER_CONTEXT" "$PRIVATE_CLUSTER_CONTEXT" "$PUBLIC_CLUSTER_CONTEXT"; do
    echo "$ctx 'kubectl get ns':"
    if ! kubectl get ns --context "$ctx"; then
      echo "Error: Failed to reach $ctx"
      return 1
    fi
  done
}

create_namespaces() {
  echo "Creating namespaces"

  kubectl create --context "$MANAGEMENT_CLUSTER_CONTEXT" namespace argocd
  kubectl create --context "$MANAGEMENT_CLUSTER_CONTEXT" namespace external-secrets
}

create_infra_secrets() {

  echo "Creating azure-creds"

  cat <<EOF | kubectl apply --context "$MANAGEMENT_CLUSTER_CONTEXT" -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-creds
  namespace: external-secrets
type: Opaque
stringData:
  ClientID: ${CLIENT_ID}
  ClientSecret: ${CLIENT_SECRET}
EOF

  echo "Creating argocd-management-repo-creds-github"

  cat <<EOF | kubectl apply --context "$MANAGEMENT_CLUSTER_CONTEXT" -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-management-repo-creds-github
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/bde-dev/management-cluster.git
  username: ${GITHUB_USERNAME}
  password: ${GITHUB_MANAGEMENT_REPO_PAT_TOKEN}
EOF
}

# Remote clusters' ArgoCD SA creds → Key Vault lives in the `store-cluster-creds`
# mise task (tasks/store-cluster-creds.sh), called from the main flow below.

install_argocd_helm() {
  echo "Attempting ArgoCD installation"

  if kubectl get -n argocd --context "$MANAGEMENT_CLUSTER_CONTEXT" app management-root-app &>/dev/null; then
    echo "ArgoCD installation already handed off to GitOps"
    return
  fi

  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm install argocd --kube-context "$MANAGEMENT_CLUSTER_CONTEXT" argo/argo-cd \
    --namespace argocd \
    --version 9.3.7 \
    --set configs.cm.kustomize.buildOptions="--enable-helm" \
    --set configs.params.server.insecure="true" \
    --wait --timeout 15m
}

hand_off_to_gitops() {
  echo "Attempting to apply management project and root app manifests"

  kubectl --context "$MANAGEMENT_CLUSTER_CONTEXT" apply -f projects/management.yaml
  kubectl --context "$MANAGEMENT_CLUSTER_CONTEXT" apply -f projects/infrastructure.yaml
  kubectl --context "$MANAGEMENT_CLUSTER_CONTEXT" apply -f root-apps/management-root-app.yaml
  kubectl --context "$MANAGEMENT_CLUSTER_CONTEXT" apply -f projects/monitoring.yaml
}

require_prereqs

resolve_contexts

read -p "Press enter to bootstrap to $MANAGEMENT_CLUSTER_CONTEXT or ctrl+C to exit."

mise run bootstrap-cilium

read -p "Cilium done. Press enter to continue (next is create_namespaces)"

create_namespaces

read -p "namespaces done. Press enter to continue (next is infra_secrets)"

create_infra_secrets

read -p "infra_secrets done. Press enter to continue (next is store remote cluster creds)"

mise run store-cluster-creds

install_argocd_helm

hand_off_to_gitops

echo "Done"
