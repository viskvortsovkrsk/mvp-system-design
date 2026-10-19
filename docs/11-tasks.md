# 11 · Tasks

Every task and its detail live in the tracker. A task and a doc disagree → the doc wins.

## Tracker

- The user picks it at project start: Jira (default, SOC 2), Linear (SOC 2) or Todoist (no SOC 2), [15](15-security.md#vendors). The agent asks, offering the default, never picks.
- Needs: MCP server or API for the agent; projects, sections, labels, priority, due dates, comments.
- One project per repo: `<project>-development`. Description: repo path, docs to start from, the legend below, "maintained by the agent: new work goes here, closed when done".
- Tracker, project name and id, and [Sync](#sync) go into the project's `.claude/CLAUDE.md`.

| Section | Holds |
|---|---|
| (none) | backlog |
| In progress | started |
| Needs decision | waits on the user; options named, recommended first |
| Checks | a verification after a deploy or a wait; due date set |

- Labels: one area per task, closed list in the description (`app` `infra` `ops` `security` …). `you` = only the user can do it.
- Priority: 1 prod or security at risk, or blocks a release or milestone · 2 confirmed bug · 3 normal · 4 cleanup.

## Task

- Title: short, imperative, one action. Different people or times → separate tasks.
- Description stands alone, no chat needed: problem, why it matters, what to do. Links: the PR, the source (alert, email, log query).
- Due date for anything time-bound: deadline, re-check, expiry (a week early).
- Review with many findings → parent task + numbered subtasks, each with `file:line` evidence and the fix.

## Sync

- Never ask whether to file. A turn that leaves anything open (gap, follow-up, decision, check) files it before it ends and reports it as done.
- Before adding: search open and completed tasks; parallel sessions file and close too. Update rather than duplicate.
- Every create or update gets a comment: what changed, how it was established, what was ruled out.
- Done = shipped and verified, never intended.
- Touch a task with a stale description → fix it.
- Read the tracker before any status report.
