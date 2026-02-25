# GLOBAL_AGENTS.md - Team-Wide Rules

> All agents read this file at session start, before their own AGENTS.md.

## Project

- **Name**: (your project name)
- **Goal**: (one-line goal)
- **Stack**: (tech stack)

## Conventions

- Branch naming: `feature/{topic}-{description}`
- Commit style: conventional commits
- PR merges require at least 1 review

## Session Structure

| Topic | Role | Prefix |
|-------|------|--------|
| General (HQ) | Project management | `hq-` |
| Frontend | UI/UX development | `fe-` |
| Backend | API/server | `be-` |
| Contract | Smart contracts | `sc-` |

## Cron Job Naming

Format: `{prefix}-{purpose}-{interval}`
- Each session manages only its own prefix
- Check `cron list` before creating new jobs

## Shared Rules

- API spec changes → notify other sessions
- Shared types live in `packages/shared/`
- No destructive commands without asking
- Private data stays private

---

_Customize this for your team. Delete sections you don't need._
