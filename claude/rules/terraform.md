---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
---

# Terraform conventions

- Run `terraform fmt` and `terraform validate` after every change.
- Never run `apply` or `destroy`. Produce a plan and let me apply it.
- Treat any planned destroy or replacement of a stateful resource (databases, buckets, volumes) as a blocker until I confirm it.
- Pin provider and module versions.
- Tag every resource with owner and cost-centre tags if the repository defines them.
- No secrets in `.tf` or `.tfvars` files; use the provider's identity mechanism or a secrets manager.
