# mvp-system-design

A template for taking an MVP from an empty repo to production.

Rules, not code: what to build, with what, in which order. Each choice favours:

- **Performance:** a Go modular monolith, Postgres, no framework or ORM between the code and the database.
- **Proven, stable tech:** boring tools with long track records, every version pinned, every provider swappable.
- **Fast implementation:** one repo, one image, one way to do each thing, so a small team (or an AI agent) ships without debating basics.

Security, privacy, rate limits, observability, backups and release are in from day one, not added after launch.

## What's inside

| Doc | Covers |
|---|---|
| [01 system design](docs/01-system-design.md) | shape, rules, web security, webhooks, Postgres roles, isolation, data model, indexes |
| [02 stack](docs/02-stack.md) | use / don't use |
| [03 folders](docs/03-folders.md) | repo layout |
| [04 logs](docs/04-logs.md) | log line, levels, labels, pipeline |
| [05 dev](docs/05-dev.md) | local stack, fakes, tests |
| [06 stage](docs/06-stage.md) | pre-prod rehearsal |
| [07 prod](docs/07-prod.md) | topology, Swarm, Redis, buckets, secrets, backups |
| [08 release](docs/08-release.md) | CI, deploy, rollback, pins |
| [09 cloud](docs/09-cloud.md) | provider-agnostic rules, buy list, Terraform |
| [10 alerts](docs/10-alerts.md) | rules, routing, dashboards |
| [11 tasks](docs/11-tasks.md) | tracker, task format, sync |
| [12 tests](docs/12-tests.md) | tiers, 99% coverage, UI video, Jenkins stages |
| [13 code quality](docs/13-code-quality.md) | SonarQube, gate, agent rules |
| [14 UI](docs/14-ui.md) | look, motion, springs, sources, how to apply, recipes |
| [15 security](docs/15-security.md) | map, threat model, authz, sign-in, audit, input, uploads, outbound, tokens, LLM, people, supply chain, vendors, launch, incident |
| [16 rate limits](docs/16-rate-limits.md) | every non-read action: per user and global, second/minute, day, month, enforce or alert, events |

Environments: `dev` · `stage` · `prod` (the `ENVIRONMENT` value, file names, hostnames).

## How to use it

1. Read this README, then `docs/` in order.
2. Build phase by phase ([Build order](#build-order)). Tech outside [02](docs/02-stack.md) is a deliberate decision, recorded as a deviation.
3. Record the commit you follow and every deviation in your project ([Adopting](#adopting)).

### With an AI agent

Model: Claude Opus 5.5 or GPT-6.1 Sol, effort medium or higher.

1. Paste into the agent in your project:

   ```text
   Add the mvp-system-design skill from https://github.com/viskvortsovkrsk/mvp-system-design (skills/mvp-system-design), then build this project like mvp-system-design.
   ```

2. Copy [agent-rules.md](agent-rules.md) into the project's `CLAUDE.md` (Claude) or `AGENTS.md` (other agents): how every session thinks, keeps it simple, changes only what's asked and verifies.

### Build order

| Phase | Do |
|---|---|
| Day 1 | 01 rules · 02 · 03 · 04 · 05 · 11 · 12 · 13 · 14 · 15 through vendors · 16 · 08 CI through build |
| Before the first prod user | 01 web security, webhooks · 06 · 07 start here · 08 deploy · 09 · 10 · 15 launch, incident · one restore drill |
| Grown | 07 grown |

### What only you can do

Accounts, money, legal: the agent can't. Personal account and 2FA (hardware key for owners) everywhere; credentials into the secret manager or `~/.config/<project>/`, their places into `docs/env/<env>.md` ([03](docs/03-folders.md#environment-files)).

| Phase | Do | Doc |
|---|---|---|
| Day 1 | AI agent subscription: Claude or GPT, model per [With an AI agent](#with-an-ai-agent) | — |
| Day 1 | GitHub: org, repo, `main` protected, secret scanning on | [15](docs/15-security.md#people-and-accounts) |
| Day 1 | Tracker: Jira project, API token for the agent | [11](docs/11-tasks.md) |
| Day 1 | Claude Design canvas for the look | [14](docs/14-ui.md) |
| Day 1 | Buy the domain; DNS to Cloudflare | [02](docs/02-stack.md) |
| Before the first prod user | Cloud: stage and prod accounts, billing, budget alerts, root locked away | [09](docs/09-cloud.md) |
| Before the first prod user | Cloudflare: WAF, Tunnel, Access with SSO for admin tools | [07](docs/07-prod.md#topology--start-here) |
| Before the first prod user | Auth0: tenants for dev, stage, prod | [02](docs/02-stack.md) |
| Before the first prod user | Resend: verify the domain (SPF, DKIM, DMARC) | [02](docs/02-stack.md) |
| Before the first prod user | Payments: merchant of record or local provider; company checks, sandbox and live keys | [02](docs/02-stack.md) |
| Before the first prod user | LLM provider: API account, monthly spend limit | [01](docs/01-system-design.md#rules) |
| Before the first prod user | Slack: workspace, on-call, team and business digest channels, bot | [10](docs/10-alerts.md#routing) |
| Before the first prod user | External uptime check and dead man's switch receiver | [10](docs/10-alerts.md#outside-the-cluster) |
| Before the first prod user | Enter human secrets (provider keys) in the secret manager | [07](docs/07-prod.md#secrets) |
| Before the first prod user | Legal entity, terms, privacy notice text, DPAs with vendors, security contact mailbox | [01](docs/01-system-design.md#data-model) · [15](docs/15-security.md#launch) |

### Adopting

Each project keeps `docs/00-mvp-system-design.md`:

```md
# 00 · MVP system design

Follows mvp-system-design `<sha>`.

| Doc | Deviation | Why |
|---|---|---|
| 12 | coverage report-only | legacy code at 40% |
```

Re-align: `git -C <mvp-system-design> log -p <sha>..main -- README.md docs/` → apply → bump `<sha>`.

## Contact

- Questions, ideas, mistakes: [GitHub issues](https://github.com/viskvortsovkrsk/mvp-system-design/issues).
- Directly: [LinkedIn](https://www.linkedin.com/in/viskvortsov).

## About me

Hi, I'm Vladimir Skvortsov ([LinkedIn](https://www.linkedin.com/in/viskvortsov)).

With 15 years of experience leading technology teams of every size, I've built products and platforms from the ground up that have generated millions of dollars in license revenue.

My background goes well beyond engineering. I've worked across every side of the business, including accounting and finance, operations, marketing and sales, so I approach technology as a business tool rather than an end in itself. That perspective helps me make pragmatic architecture decisions, align teams around commercial goals, and bring products to market faster.

Today I focus on AI-driven products, helping companies design scalable systems, launch new products, and build high-performing teams. I'm based in Dubai and work with clients internationally.

## License

[MIT](LICENSE)
