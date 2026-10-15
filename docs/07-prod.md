# 07 · Prod

## Topology — start here

- 3 VMs in 3 zones, all Swarm managers, all run apps. Private IPs only, NAT egress. Separate SSD at `/var/lib/docker`.
- Edge: CDN/WAF → L4 LB :443 → Caddy (global) with origin cert. Firewall: 443 only from the edge, plus authenticated origin pull (or a tunnel).
- Postgres and Redis are managed services, never containers in Swarm.
  - Postgres: private, TLS `verify-full`, PITR ≥ 14d, deletion protection. Roles per [01](01-system-design.md#postgres-roles).
  - Redis: only when a cache/queue is needed ([02](02-stack.md)); private, TLS, auth.
- Buckets: one per task (below).
- Private registry, secret manager, machine identity per VM.
- Admin: no public SSH, no public admin UIs. WireGuard VM holds the only public IP; SSH goes over it. Grafana and CI behind zero-trust tunnel + SSO.
- In cluster: Alloy (global), Loki (object storage), Prometheus, Grafana.
- Ops tools are per project, never shared between projects: VPN, CI, SonarQube, registry, Grafana stack.
- Option: Jenkins and Grafana on a local machine instead of VMs. It joins the VPN; Jenkins uses a CI service-account key from `~/.config/<project>/` instead of machine identity. Builds and scheduled runs wait while it's off; Grafana alerting stops too, and the dead man's switch ([10](10-alerts.md#outside-the-cluster)) pages.

## Topology — grown

- 3 small managers (label `apps=false`, not drained) + ≥ 2 workers + 1 ops node (`observability=true`). Labels set by cloud-init, never by hand.
- Postgres and Redis with HA (standby in another zone).
- Hub network (VPN, CI, registry) peered to the prod and stage accounts.

## Swarm service

```yaml
deploy:
  replicas: 2
  resources: {reservations: {cpus: "0.25", memory: 128M}, limits: {cpus: "1", memory: 512M}}
  restart_policy: {condition: on-failure, max_attempts: 5}
  update_config: {parallelism: 1, order: start-first, monitor: 45s, failure_action: rollback}
  rollback_config: {parallelism: 1, order: stop-first}
healthcheck: {test: ["CMD", "/app/api", "-healthcheck"], interval: 10s, retries: 3}
```

- Every service has a healthcheck and limits. Without a healthcheck, auto-rollback only catches crashes.
- `stop-first` for host-mode ports, `replicas = nodes` with `max_replicas_per_node`, and volume singletons — `start-first` deadlocks there.
- Configs and secrets have immutable names: `<name>-<content-hash>` / `<name>-v<N>`.
- Third-party images mirrored to the own registry, pinned ([02](02-stack.md)).
- Nodes pull via credential helper or machine identity. Forwarded registry tokens expire, and tasks then can't reschedule.
- Overlay networks unencrypted unless the cloud firewall passes ESP.
- Bind mounts only to paths cloud-init creates; a missing path silently rejects the task.

## Secrets

- Secret manager per env, two containers: IaC-generated and human-entered (an apply never overwrites manual values).
- `deploy/secrets.sh` (machine identity) → Swarm secrets `<name>-v<N>`. Fails on missing, empty or `REPLACE_ME`.
- Apps read `/run/secrets/<name>` via `X_FILE`. Env files hold non-secret config only.
- Rotation: new version → sync → deploy → verify → delete old.
- Terraform state counts as a secret.

## Buckets — one per task

- Each task gets its own bucket `<project>-<env>-<task>` with its own lifecycle, access policy and credentials. Never two tasks in one bucket.
- A service reaches only its tasks' buckets, and writes only where it writes.
- All private. Files leave through short-lived signed URLs.

| Task (typical) | Lifecycle |
|---|---|
| `media`, `documents` — business data | keep · versioning · soft delete 7d (erasure deadline, [01](01-system-design.md#data-model)) |
| `imports`, `exports` — feeds, generated files | delete after 30d |
| `tmp` | delete after 7d |
| `logs` — Loki | log retention ([04](04-logs.md#retention)) |
| `backups` | standard 30d → cold → delete at 3y · object lock 3y · other account + region |
| `tfstate` | versioned, locked ([09](09-cloud.md)) |

## Backups

- Nightly: `pg_dump -Fc` of every DB + new objects of business-data buckets → `backups` (kept 3y, table above).
- Fast restore = managed PITR. Cold copies are for the long tail; their restore can take hours.
- Missing dump → alert ([10](10-alerts.md)).
- Drills: monthly restore of a recent dump, yearly restore of a cold one, both into a throwaway instance. Record real RPO/RTO in `docs/`.
- Erasure log: each account erasure and tenant offboarding ([01](01-system-design.md#data-model)) writes `{subject_id, time}` (no PII) to the DB and to `erasures/` in `backups`. After any restore, PITR included, re-run every erasure logged after the restore point (account: steps 4–5; tenant: the delete), before traffic returns. Drills check it.
- Cluster is cattle: rebuild from git + secret store.
