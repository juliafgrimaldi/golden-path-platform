# 1. A tenant is a folder in Git

## Status
Accepted

## Context
Teams need namespaces with the same guardrails every time, without waiting on a ticket.
Options considered: a PR with a YAML file, a custom `Tenant` CRD (kro/Crossplane), a Backstage form.

## Decision
A tenant is `tenants/<name>/tenant.yaml`. An Argo CD ApplicationSet (git files generator)
turns each file into an Application that renders `charts/tenant` with that file as values.
`charts/tenant/values.schema.json` is the contract: Helm refuses to render a file that breaks it,
and CI runs the same schema with readable errors before merge.

## Consequences
- Review, audit trail and rollback come from Git for free.
- No extra controller to run or upgrade.
- No real-time feedback beyond CI; a portal or CRD could be added later on top of the same chart.
