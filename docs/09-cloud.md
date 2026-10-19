# 09 · Cloud-agnostic

## Rules

- Generic primitives only (table below). No provider PaaS in the request path: functions, app gateways, managed k8s, logic apps.
- Provider-specific code lives in exactly two places: `deploy/terraform/modules/*` and `deploy/cloud.sh` (`secret_get`, `registry_login`).
- App code: object storage through `internal/blob` over the S3 API; a second implementation only when the cloud has no S3 API. Secrets from files. No provider SDKs anywhere else.
- Same on every cloud: edge, runtime, logs, metrics, alerts ([02](02-stack.md)), WireGuard VM ([07](07-prod.md)).
- Monitoring is our own stack. Provider monitoring only for what the cluster can't see ([10](10-alerts.md)).

## Buy list

| Concept | AWS | GCP | Azure | Yandex |
|---|---|---|---|---|
| VM + data disk | EC2 + EBS | Compute Engine + PD | VM + Managed Disk | Compute Cloud + disk |
| Private net + NAT | VPC + NAT Gateway | VPC + Cloud NAT | VNet + NAT Gateway | VPC + NAT gateway |
| Firewall | Security Group | Firewall rules | NSG | Security group |
| L4 load balancer | NLB | Passthrough NLB | Load Balancer | Network Load Balancer |
| Postgres | RDS | Cloud SQL | PG Flexible Server | Managed PostgreSQL |
| Redis, grown only ([07](07-prod.md#redis)) | ElastiCache (Redis OSS) | Memorystore for Redis | Azure Managed Redis | Managed Valkey (Redis API) |
| Object storage | S3 | GCS (S3 via HMAC) | Blob (no S3 API) | Object Storage |
| Cold class, 3y backups | Glacier Deep Archive | Archive | Archive tier | ICE |
| Object lock | Object Lock | Bucket Lock | immutability policy | Object Lock |
| Registry | ECR | Artifact Registry | ACR | Container Registry |
| Secrets | Secrets Manager | Secret Manager | Key Vault | Lockbox |
| Machine identity | instance role | service account | managed identity | service account |
| Terraform state | S3 + lockfile | GCS | storage account | Object Storage (S3 backend) |
| SOC 2 Type II ([15](15-security.md#vendors)) | yes, AWS Artifact | yes, Compliance Reports Manager | yes, Service Trust Portal | **none published** (ISO, PCI DSS, 152-FZ instead): a SOC 2 project needs a deviation |

## Terraform

```
deploy/terraform/
  modules/   network, swarm, edge-lb, postgres, buckets, registry, secrets, vpn, dns, alerts
  shared/    bootstrap/ + vpn, ci, registry (this project's stage + prod)
  stage/     bootstrap/ + main.tf, backend.tf, terraform.tfvars
  prod/      bootstrap/ + main.tf, backend.tf, terraform.tfvars
```

- `bootstrap/` creates the env's state bucket with local state, once.
- Modules take and return generic values (node IPs, DB host, bucket names). Changing cloud = rewrite modules; roots stay.
- State: remote, versioned, locked, one per env, access-restricted.
- Names `<project>-<env>-<role>-<n>`. Tags `env`, `owner`, `managed-by=terraform`.
- Non-secret tfvars are committed.
- After any manual change `terraform plan` must be empty. A targeted apply states its expected diff and stops on anything else.
- cloud-init is idempotent; ignore changes to user-data so an edit never recreates the cluster.
