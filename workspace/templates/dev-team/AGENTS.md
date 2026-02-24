# AGENTS.md - Dev Team Template

## Architecture
This workspace runs a multi-agent development team.

### Agent Roles
| Agent | Role | Model | Workspace |
|-------|------|-------|-----------|
| PM | Project Manager, daily reports, task coordination | Opus | workspace/ |
| Frontend | Frontend development | Sonnet | workspace-frontend/ |
| Backend | Backend development | Sonnet | workspace-backend/ |
| Contract | Smart contract development | Sonnet | workspace-contract/ |

### PM Agent Responsibilities
1. **Morning Report**: Daily status of all repos (git log, issues, PRs)
2. **Task Distribution**: Break features into sub-tasks, assign to agents
3. **Code Review Flow**: Manage review pipeline
4. **Progress Tracking**: Update memory with project status

### Cron Naming
Format: `{agent}-{purpose}-{interval}`
- `pm-report-daily` → PM daily morning report
- `fe-build-check` → Frontend build check
- `be-test-run` → Backend test run

### Git Workflow
All repos live in `repos/` directory (separate git repos).
Each agent works on its assigned repo only.
PRs go through PM for final review coordination.

## Antfarm Integration (Optional)
If antfarm is installed, use it for deterministic pipelines:
```bash
antfarm workflow run feature-dev "Add user authentication"
```

## Safety
- Never push to main directly
- Always create feature branches
- Run tests before creating PRs
- PM reviews all cross-repo changes
