# mvp-system-design

**Struggling with vibe coding?**\
**Found out it's not as easy as it first looked?**\
**Discovered that keeping an app running after launch is much harder than building it?**

Then this repo is for you.

A template for taking an MVP from an empty repo to production.

Rules, not code: what to build, with what, in which order. Each choice favours:

- **Performance:** a Go modular monolith, Postgres, no framework or ORM between the code and the database.
- **Proven, stable tech:** boring tools with long track records, every version pinned, every provider swappable.
- **Fast implementation:** one repo, one image, one way to do each thing, so a small team (or an AI agent) ships without debating basics.

Security, privacy, rate limits, observability, backups and release are in from day one, not added after launch.

Not technical? Start with the [FAQ](FAQ.md): why these choices, in plain language.

## How to use it: with an AI agent

Model: Claude Opus 5.5 or GPT-6.1 Sol, effort medium or higher.

1. Paste into the agent in your project:

   ```text
   Add the mvp-system-design skill from https://github.com/viskvortsovkrsk/mvp-system-design (skills/mvp-system-design), then build this project like mvp-system-design.
   ```

2. Copy [agent-rules.md](agent-rules.md) into the project's `CLAUDE.md` (Claude) or `AGENTS.md` (other agents): how every session thinks, keeps it simple, changes only what's asked and verifies.

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
| [08 release](docs/08-release.md) | git flow, CI, deploy, rollback, pins |
| [09 cloud](docs/09-cloud.md) | provider-agnostic rules, buy list, Terraform |
| [10 alerts](docs/10-alerts.md) | rules, routing, dashboards |
| [11 tasks](docs/11-tasks.md) | tracker, task format, sync |
| [12 tests](docs/12-tests.md) | tiers, 99% coverage, UI video, Jenkins stages |
| [13 code quality](docs/13-code-quality.md) | SonarQube, gate, agent rules |
| [14 UI](docs/14-ui.md) | look, motion, springs, sources, how to apply, recipes |
| [15 security](docs/15-security.md) | map, threat model, authz, sign-in, audit, input, uploads, outbound, tokens, LLM, people, supply chain, vendors, launch, incident |
| [16 rate limits](docs/16-rate-limits.md) | every non-read action: per user and global, second/minute, day, month, enforce or alert, events |

Environments: `dev` · `stage` · `prod` (the `ENVIRONMENT` value, file names, hostnames).

## Build order

| Phase | Do |
|---|---|
| Day 1 | 01 rules · 02 · 03 · 04 · 05 · 11 · 12 · 13 · 14 · 15 through vendors · 16 · 08 CI through build |
| Before the first prod user | 01 web security, webhooks · 06 · 07 start here · 08 deploy · 09 · 10 · 15 launch, incident · one restore drill |
| Grown | 07 grown |

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
