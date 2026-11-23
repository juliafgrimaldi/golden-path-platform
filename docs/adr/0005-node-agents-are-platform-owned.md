# 5. Node-level agents are platform-owned; tenants cannot run DaemonSets

## Status
Accepted

## Context
The `edit` ClusterRole that tenants get allows DaemonSets. Pod Security `restricted` already
stops them from touching the node (no hostPath, hostNetwork or privileged), so a tenant
DaemonSet can only spread pods across every node, and those pods count against the tenant's quota.
That means the tenant's usage grows whenever the cluster adds nodes, with no change on their side.

## Decision
Anything that must run on every node (Cilium, log and metric collectors, node-exporter,
GPU device plugins) is installed by the platform in platform namespaces. Tenants consume it
as a service: e.g. the platform log collector reads every namespace and tags lines with the
`tenant` and `cost-center` labels the tenant chart stamps on everything.
Kyverno `tenants-no-daemonsets` denies DaemonSets in any namespace labelled as a tenant.

## Consequences
- One agent per node instead of one per tenant per node.
- Tenant network policies must allow ingress from the `observability` namespace so platform
  collectors can scrape tenant pods (already in the tenant chart).
- A team with a genuine per-node need asks the platform team; the answer is a platform feature, not an exception.
