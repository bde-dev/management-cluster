# Management Cluster

GitOps repository for the ArgoCD management cluster.

## Structure

```
.
├── root-apps/         # Two root Applications: one recurses applications/, one recurses projects/
├── projects/          # One AppProject per category (infrastructure, management, monitoring, private, public)
├── applications/      # Application CRs, applications/<project>/<app>/
├── argocd/            # ArgoCD install: Helm values + manifests (namespace, cluster and repo credentials, tunnel)
├── infrastructure/    # Manifests for the infrastructure project's apps (sourced from this repo)
├── monitoring/        # Manifests for the monitoring project's apps (sourced from this repo)
├── tasks/             # mise tasks: cluster, Cilium, and credential bootstrapping
├── scripts/setup      # Devcontainer post-create: trusts mise.toml and installs the pinned tools
├── mise.toml          # Pinned tooling and task config (Renovate-managed)
└── renovate.json
```
