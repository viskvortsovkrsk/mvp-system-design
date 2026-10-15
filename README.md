# mvp-system-design

How we build a project. New project → read `docs/` in order, do exactly this.
The project records which commit it follows and every deviation ([Adopting](#adopting)).

| Doc | Covers |
|---|---|
| [01 system design](docs/01-system-design.md) | shape, rules, web security, webhooks, Postgres roles, isolation, data model, indexes |
| [02 stack](docs/02-stack.md) | use / don't use |
| [03 folders](docs/03-folders.md) | repo layout |
| [04 logs](docs/04-logs.md) | log line, levels, labels, pipeline |
| [05 dev](docs/05-dev.md) | local stack, fakes, tests |
| [06 stage](docs/06-stage.md) | pre-prod rehearsal |
| [07 prod](docs/07-prod.md) | topology, Swarm, buckets, secrets, backups |
| [08 release](docs/08-release.md) | CI, deploy, rollback, pins |
| [09 cloud](docs/09-cloud.md) | provider-agnostic rules, buy list, Terraform |
| [10 alerts](docs/10-alerts.md) | rules, routing, dashboards |
| [11 tasks](docs/11-tasks.md) | tracker, task format, sync |
| [12 tests](docs/12-tests.md) | tiers, 99% coverage, UI video, Jenkins stages |
| [13 code quality](docs/13-code-quality.md) | SonarQube, gate, agent rules |
| [14 UI](docs/14-ui.md) | look, motion, springs, sources, how to apply, recipes |

Environments: `dev` · `stage` · `prod` (the `ENVIRONMENT` value, file names, hostnames).

## Build order

| Phase | Do |
|---|---|
| Day 1 | 01 rules · 02 · 03 · 04 · 05 · 11 · 12 · 13 · 14 · 08 CI through build |
| Before the first prod user | 01 web security, webhooks · 06 · 07 start here · 08 deploy · 09 · 10 · one restore drill |
| Grown | 07 grown |

## From any project

`git clone git@github.com:viskvortsovkrsk/mvp-system-design.git`, then `ln -s <mvp-system-design>/skills/mvp-system-design ~/.claude/skills/mvp-system-design`: agents in any repo then find this one when asked to build "like mvp-system-design".

## Adopting

Each project keeps `docs/00-mvp-system-design.md`:

```md
# 00 · MVP system design

Follows mvp-system-design `<sha>`.

| Doc | Deviation | Why |
|---|---|---|
| 12 | coverage report-only | legacy code at 40% |
```

Re-align: `git -C <mvp-system-design> log -p <sha>..main -- README.md docs/` → apply → bump `<sha>`.

## License

[MIT](LICENSE)
