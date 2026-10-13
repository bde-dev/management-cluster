# management-cluster

The ArgoCD management cluster of a three-cluster Talos homelab. ArgoCD runs here and reconciles this cluster and the two leaf clusters, `private-cluster` and `public-cluster`. This repo is public and holds manifests, scripts, and tooling only: no design notes or working documents, never a secret value, and never the name of a private-cluster workload.

## Topology

- Three clusters, one GitOps control point. ArgoCD registers each leaf as a destination through `argocd/manifests/*-cluster-credentials.yaml`: ExternalSecrets that pull the leaf's service-account token, CA, and API host from Key Vault.
- App-of-Apps. `root-apps/` holds two root Applications, one recursing `applications/` and one recursing `projects/`. Everything else is reached from those two.
- `projects/` is one AppProject per category: `infrastructure`, `management`, `monitoring`, `private`, `public`. A project pins which source repo, destination cluster, and namespaces its apps may use, so Argo refuses an app whose destination the project does not list.
- `applications/<project>/` holds the Application CRs for infrastructure, management and monitoring apps (manifests in `infrastructure/` and `monitoring/`) and, under `application-sets/`, the ApplicationSets that roll shared infrastructure onto every registered cluster. `applications/private/` and `applications/public/` each hold one root Application that recurses the leaf repo's `argocd/apps` directory, so a leaf app lives entirely in its own repo: manifests and Application CR together.

## Working in this repo

- **Deploys track `main`.** Every Application pins `targetRevision: HEAD`, so a commit on any other branch pushes fine and never deploys. Check `git branch --show-current` before committing.
- **Adding a leaf app** is a change in the leaf repo only (Kustomize base under `apps/<app>/`, Application CR under `argocd/apps/<app>/`). The `private` and `public` AppProjects already allow every namespace on their cluster, so nothing here changes.
- **Cluster access is per-context kubectl.** `mise run gather-configs` fetches a kubeconfig for every cluster from Omni and merges them; `kubectl config get-contexts` lists the names and `kubectl --context <name>` targets one. The leaf clusters are operated from this environment. The tooling in their own repos is break-glass, and its credentials are not kept fresh.
- **Tasks** are mise tasks in `tasks/` (cluster, Cilium, and credential bootstrapping). `mise.toml` pins every tool and Renovate manages the pins, so tool and image versions live in `mise.toml` and the manifests, not in docs.
- **Secrets** are ExternalSecrets against the Key Vault ClusterSecretStore. `.env` is git-ignored and local to a checkout.

## Documentation style

Docs describe current state and its reasons, never the change that produced it. Point at the source of a value instead of restating it.
