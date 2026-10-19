This repo is the reference model for new projects. It holds rules, not code (apart from `scripts/check.sh` and `skills/`).

When told to build or align a project "like mvp-system-design":
1. Read README.md, then every file in docs/ in order.
2. Apply them phase by phase (README "Build order"). Tech outside docs/02-stack.md needs the user's approval first.
3. Record the commit followed and every deviation in the project's docs/00-mvp-system-design.md (format: agent-rules.md rule 1).

When editing this repo:
- Terse: rules, tables, short code blocks. No prose, no tutorials.
- Each fact lives in exactly one doc; other docs point to it.
- Stay provider-agnostic: cloud provider names (AWS, GCP, Azure, Yandex…) appear only in docs/09-cloud.md.
- Stay project-agnostic: name none of our projects or clients, not even as a source or an example. Rules and code blocks stand on their own.
- `scripts/check.sh` must pass; it runs as the pre-commit hook once `git config core.hooksPath scripts/hooks` is set.
