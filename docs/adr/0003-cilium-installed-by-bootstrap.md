# 3. Cilium and Argo CD are installed by the bootstrap script, not by Argo CD

## Status
Accepted

## Context
Argo CD cannot run before the cluster has a CNI, so it cannot install the CNI it depends on.

## Decision
`bootstrap/up.sh` installs Cilium and Argo CD with pinned Helm chart versions (`bootstrap/versions.env`),
then hands over to Argo CD through a single root Application. Everything after that is GitOps.

## Consequences
- Two components are upgraded by script, not by Git. They may be adopted by Argo CD later
  (Argo CD can manage itself once running).
