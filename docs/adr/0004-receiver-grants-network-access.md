# 4. The receiving tenant grants network access

## Status
Accepted

## Context
Tenants are isolated by default, but real services call each other (payments calls search).
Someone has to declare that a flow is allowed. Options considered:

- **Caller declares** ("payments may call search"): simple, but any tenant can grant itself access to anyone.
- **Both sides declare** (caller egress + receiver ingress): strongest, but two PRs per dependency and easy to get out of sync.
- **Receiver declares** ("search accepts payments on 8080"): the owner of the data decides who gets in.

## Decision
Receiver declares. `network.allowFrom` in the receiving tenant's `tenant.yaml` becomes a
CiliumNetworkPolicy ingress rule scoped to the caller's namespace and ports. Ingress is
default-deny; egress is open in-cluster (the receiver's ingress decides), DNS is allowed,
and the internet is reachable only for hosts listed in `network.egressFQDNs`.

Tenants cannot create, change or delete network policies themselves (Kyverno
`tenants-network-via-git`); only Argo CD can. CODEOWNERS makes the receiving team approve the PR.

## Consequences
- Every cross-tenant flow has a reviewed, dated PR on the receiver's folder.
- The validator rejects `allowFrom` entries pointing to tenants that do not exist.
- Rules are L4 (namespace + port). L7 rules (HTTP method/path) are a later option in Cilium.
- Debugging a blocked call: `hubble observe --namespace tenant-<name> --verdict DROPPED`.
