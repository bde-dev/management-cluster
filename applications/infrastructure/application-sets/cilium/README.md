Two separate cilium AppSets exist:

1. cilium app itself
2. cilium config resources such as IP pools

This pattern is used with `sync-wave` to ensure the app AppSet deploys the cilium CRDs before the cilium-config AppSet attempts to create CR's from the CRDs.
