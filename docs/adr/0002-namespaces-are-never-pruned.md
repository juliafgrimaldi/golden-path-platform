# 2. Tenant namespaces are never deleted by Argo CD

## Status
Accepted

## Context
With automated prune, deleting a folder (or a bad merge) would delete the namespace and every workload in it.

## Decision
The Namespace carries `argocd.argoproj.io/sync-options: Delete=false`. Removing a tenant folder
stops Argo CD from managing it; deleting the namespace is a deliberate, manual offboarding step.

## Consequences
- A mistaken PR cannot wipe a team's workloads.
- Offboarding needs a runbook step, and orphaned namespaces must be watched for.
