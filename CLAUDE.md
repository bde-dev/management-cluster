# management-cluster

The ArgoCD management cluster of a three-cluster Talos homelab. ArgoCD runs here and reconciles this cluster and the two leaf clusters, `private-cluster` and `public-cluster`. This repo is private and holds manifests, scripts, and tooling only: no design notes or working documents, and never a secret value.

## Topology

- Three clusters, one GitOps control point. ArgoCD registers each leaf as a destination through `argocd/manifests/*-cluster-credentials.yaml`: ExternalSecrets that pull the leaf's service-account token, CA, and API host from Key Vault.
- App-of-Apps. `root-apps/` holds two root Applications, one recursing `applications/` and one recursing `projects/`. Everything else is reached from those two.
- `projects/` is one AppProject per category: `infrastructure`, `management`, `monitoring`, `private`, `public`. A project pins which source repo, destination cluster, and namespaces its apps may use, so Argo refuses an app whose destination the project does not list.
- `applications/<project>/<app>/` holds the Application CRs. Infrastructure and monitoring apps source their manifests from this repo (`infrastructure/`, `monitoring/`). Private and public apps source theirs from the leaf repos, which is why a leaf app is two changes in two repos: manifests there, Application CR here.

## Working in this repo

- **Deploys track `main`.** Every Application pins `targetRevision: HEAD`, so a commit on any other branch pushes fine and never deploys. Check `git branch --show-current` before committing.
- **Adding a leaf app** needs an Application CR under `applications/<private|public>/<app>/` and the app's namespace added to that project's `destinations` in `projects/`.
- **Cluster access is per-context kubectl.** `mise run gather-configs` fetches a kubeconfig for every cluster from Omni and merges them; `kubectl config get-contexts` lists the names and `kubectl --context <name>` targets one. The leaf clusters are operated from this environment. The tooling in their own repos is break-glass, and its credentials are not kept fresh.
- **Tasks** are mise tasks in `tasks/` (cluster, Cilium, and credential bootstrapping). `mise.toml` pins every tool and Renovate manages the pins, so tool and image versions live in `mise.toml` and the manifests, not in docs.
- **Secrets** are ExternalSecrets against the Key Vault ClusterSecretStore. `.env` is git-ignored and local to a checkout.

## Documentation style

Docs describe current state and its reasons, never the change that produced it. Point at the source of a value instead of restating it.
