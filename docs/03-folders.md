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
go.mod
cmd/<bin>/               main.go (+ templates/, static/ via go:embed)
internal/<pkg>/          store/ (queries.go, migrations/), session/, applog/, blob/ …
e2e/                     Go e2e against the running stack; browser/ = Playwright
dags/                    Airflow DAGs (Python), tests/ inside
deploy/
  stack.yml              Swarm stack, stage + prod
  stage.env  prod.env    non-secret per-env values (TAG, hosts, replicas)
  Caddyfile
  deploy.sh  migrate.sh  secrets.sh
  cloud.sh               the only provider-specific shell: secret_get, registry_login
  observability/         alloy/, loki/, prometheus/, grafana/ (datasources, alerting, dashboards)
  terraform/             modules/, shared/, stage/, prod/
scripts/                 dev and ops helpers (reset-db.sh, test.sh, tunnel.sh, load/)
sql/                     one-off ops queries, never app code
docs/                    00-mvp-system-design.md, NN-topic.md, releases/<ver>.md, incidents/YYYY-MM-DD-slug.md
```

## Rules

- No secrets in the tree, even gitignored. Local ones: `~/.config/<project>/`, mode 600.
- No binaries, dumps, `dist/`, `tmp/`, `reports/` in git.
- Agents can't read secrets: `.claude/settings.json` has `{"permissions": {"deny": ["Read(~/.config/<project>/**)"]}}`.
- Migrations: `internal/store/migrations/NNNNNN_verb_noun.sql`. Never renumber after merge; CI rejects duplicate numbers.
- `deploy/observability/` is mounted by dev compose and prod stack alike. One copy.
- Docs: one topic per file, numbered, each decision with its reason and what it supersedes. Change them in the same PR as the code.
- `CLAUDE.md`: shared agent rules (think first, simplest change, touch only what's asked, verify; answer as done / not done / next; tasks per [11](11-tasks.md#sync); SonarQube per [13](13-code-quality.md#agents)) + project invariants (ports, paths, "never X"). Facts that drift go to `docs/`, not here.
