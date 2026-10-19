# 03 · Folders

```
.claude/CLAUDE.md        agent rules + project invariants
.claude/settings.json    permissions.deny: what agents must not read
.mcp.json                Grafana and SonarQube MCP, read-only
.gitignore               .env, reports/, local binaries
.dockerignore            per 08
.env.example             every env var, commented; the only env file in git
README.md                what it is, how to run — one screen
version.txt              MAJOR.MINOR
Jenkinsfile
Dockerfile               one image, all binaries
compose.yaml             dev stack
sonar-project.properties SonarQube scan
src/                     all code
  go.mod  go.sum
  cmd/<bin>/             main.go (+ templates/, static/ via go:embed)
  internal/<pkg>/        store/ (queries.go, migrations/), session/, applog/, blob/ …
  e2e/                   Go e2e against the running stack; browser/ = Playwright
  dags/                  Airflow DAGs (Python), tests/ inside
deploy/
  stack.yml              Swarm stack, stage + prod
  stage.env  prod.env    non-secret per-env values (TAG, hosts, replicas)
  Caddyfile
  ratelimits.json        per 16
  redis/                 redis.conf, per 07
  deploy.sh  migrate.sh  secrets.sh
  cloud.sh               the only provider-specific shell: secret_get, registry_login
  observability/         alloy/, loki/, prometheus/, grafana/ (datasources, alerting, dashboards)
  terraform/             modules/, shared/, stage/, prod/
scripts/                 dev and ops helpers (reset-db.sh, test.sh, tunnel.sh, load/)
sql/                     one-off ops queries, never app code
docs/                    00-mvp-system-design.md, NN-topic.md, env/{dev,stage,prod}.md, releases/<ver>.md, incidents/YYYY-MM-DD-slug.md
```

## Rules

- Code lives in `src/`; the root holds build, deploy and docs. Code paths in these docs (`cmd/`, `internal/`, `e2e/`, `dags/`) are under `src/`; Go and Python commands run there.
- No secrets in the tree, even gitignored. Local ones: `~/.config/<project>/`, mode 600.
- No binaries, dumps, `dist/`, `tmp/`, `reports/` in git.
- Agents can't read secrets: `.claude/settings.json` has `{"permissions": {"deny": ["Read(~/.config/<project>/**)"]}}`.
- Migrations: `internal/store/migrations/NNNNNN_verb_noun.sql`. Never renumber after merge; CI rejects duplicate numbers.
- `deploy/observability/` is mounted by dev compose and prod stack alike. One copy.
- Docs: one topic per file, numbered, each decision with its reason and what it supersedes. Change them in the same PR as the code.
- `CLAUDE.md` (or `AGENTS.md`): [agent rules](../agent-rules.md), plus: tasks per [11](11-tasks.md#sync); SonarQube per [13](13-code-quality.md#agents); project invariants (ports, paths, "never X"). Facts that drift go to `docs/`, not here.

## Environment files

`docs/env/dev.md`, `stage.md`, `prod.md`: one per env, everything needed to reach and run it. Never secret values: where each one lives and who grants it.

```md
# prod

## Architecture
<diagram: edge → nodes → services → Postgres, Redis, buckets; zones>

## Addresses
| What | URL / host | Reached from |
|---|---|---|
| web | https://<domain> | public |
| api | https://api.<domain> | public |
| Grafana, CI, SonarQube | https://grafana.<domain> … | tunnel + SSO |
| nodes | 10.0.1.x | VPN |
| Postgres | <host>:5432 | VPN, `readonly` |

## Access
| To | How | Who grants |
|---|---|---|
| SSH | WireGuard, then `ssh <user>@<node>` | owner |
| DB | VPN, `psql` as `readonly` | owner |

## Credentials
| Name | Lives in | Used by | Get it |
|---|---|---|---|
| `db-readonly` | secret manager `<path>` | people, Grafana | owner |
| VPN config | `~/.config/<project>/wg-prod.conf` | people | owner adds a peer |

## Cloud and providers
Account / project id, region, Terraform root, IdP tenant, payment account or sandbox, email domain.

## Runbooks
Deploy, rollback, restore: links into 07, 08.
```

- Changed in the same PR as what it describes. A stale env file is a bug.
- Agents read it before any work on that env.

