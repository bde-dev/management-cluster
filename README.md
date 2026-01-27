# Management Cluster

GitOps repository for the ArgoCD management cluster.

## Structure

```
.
├── argocd/                  # ArgoCD installation manifests
│   ├── base/                # Base ArgoCD configuration
│   └── overlays/
│       └── production/      # Production-specific patches
├── applications/            # ArgoCD Application CRs (App of Apps)
│   ├── private-cluster/     # Apps deployed to private-cluster
│   └── public-cluster/      # Apps deployed to public-cluster
└── projects/                # ArgoCD AppProject definitions
```

## Visibility

**PRIVATE** - This repository contains cluster management configurations and should never be made public.
