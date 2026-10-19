# 02 · Stack

| Area | Use | Don't |
|---|---|---|
| Language | Go, latest stable · Python, latest that Airflow supports, for ETL DAGs only | Go inside DAGs · a new language without a reason |
| HTTP | `net/http` with method+path patterns | chi, gin, echo, any framework |
| UI | `html/template` + `go:embed`, plain JS, CSP | SPA, React, npm build (npm only for Playwright and `npx skills`) |
| UI motion | CSS transitions, View Transitions, scroll-driven animations, `element.animate()`, springs: `linear()` tokens, a rAF spring for gestures ([14](14-ui.md)) | animation libraries |
| UI design | look: a Claude Design canvas per project, then the project's own tokens ([14](14-ui.md#look)) · flows, copy: skill `bob` (`bias-advisor/` in [keepsimpleio/UXCoreOSS](https://github.com/keepsimpleio/UXCoreOSS), archived 2026-05-16) · `npx skills add keepsimpleio/UXCoreOSS --skill bob` | `uxcore-style` (UXCore's own brand) · a UI kit or another product's design system |
| DB | Postgres 18, managed in stage/prod · `pgx`, hand-written SQL | ORM, generic repository layer, DB inside Swarm |
| Migrations | numbered `.sql`, forward-only, embedded, run by `cmd/migrate` ([01](01-system-design.md#postgres-roles)) | down migrations, unpinned migrate image |
| Pooler | none; if needed — session mode | transaction mode (breaks advisory locks, prepared statements, temp tables) |
| Redis | in Swarm, one replica ([07](07-prod.md#redis)), `go-redis`: rate-limit counters ([16](16-rate-limits.md)), cache on measured need · managed with HA when grown | business data, queues or sessions in Redis |
| Queue | Postgres table (`FOR UPDATE SKIP LOCKED`) | Kafka, RabbitMQ |
| Jobs | in-process or `cmd/worker` · Airflow for ETL | Go binaries wrapped in DAGs |
| Auth | managed IdP (Auth0, platform IdP, regional OIDC) + own signed cookie | own IdP, Keycloak |
| Payments | merchant of record or local provider, plus `fake` | handling cards |
| Email | Resend | own SMTP |
| LLM | official SDK, model chosen per task, cost ceiling ([01](01-system-design.md)) | uncapped calls |
| Config | env vars, `.env.example`, secrets via `*_FILE` | viper, tracked `.env` |
| Logs | `log/slog` JSON → Alloy → Loki | zap, logrus, `log.Printf` |
| Metrics | Alloy (cAdvisor, node) → Prometheus → Grafana | provider monitoring as primary |
| Alerts | Grafana alerting → messenger bot: Slack (default, SOC 2) or Telegram (no SOC 2), [15](15-security.md#vendors) | email-only, alerts clicked in UI |
| AI ops | Grafana MCP, Viewer token, `--disable-write` | Editor tokens for agents |
| Runtime | Docker Swarm · compose of the same shape for dev | Kubernetes |
| Edge | Cloudflare (DNS, WAF, TLS, Tunnel + Access) → Caddy | a second WAF/L7 behind Cloudflare |
| Images | ours: multi-stage, `distroless/static:nonroot` · every image, every env: pinned `tag@digest` | `latest`, root |
| IaC | Terraform, remote locked state | console changes |
| CI | Jenkins in the private network ([08](08-release.md)), or local ([07](07-prod.md#topology--start-here)) | manual deploys from a laptop, `docker.sock` on prod nodes |
| Tests | stdlib `testing`, real Postgres in a container, Playwright ([12](12-tests.md)) | testify, mock frameworks, SQLite stand-ins |
| Security scans | `govulncheck`, Trivy for images, `gitleaks` ([08](08-release.md#ci-jenkinsfile)) | unscanned images, pins never bumped |
| Code quality | SonarQube Community Build, self-hosted ([13](13-code-quality.md)) | silenced findings, a lowered gate |
| Analytics | business `event` lines ([04](04-logs.md)) in Grafana · a third-party tag only when marketing needs it: off unless `ANALYTICS_ID` is set, consent banner if it sets cookies, action names and numbers only, CSP per [01](01-system-design.md#web-security) | tag on by default, user text or PII in events |
| Docs | Markdown in repo · MkDocs for user docs | docs outside the repo |
| Tasks | the user's tracker ([11](11-tasks.md)) | task lists in the repo, chat or agent memory |

