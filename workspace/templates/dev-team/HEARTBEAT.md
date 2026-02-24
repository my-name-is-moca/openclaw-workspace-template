# HEARTBEAT.md - Dev Team PM

## Daily Morning Report (8:00 AM)
For each repo in repos/:
```bash
cd repos/<name>
git log --oneline -5
git status
git branch -a
```

Report format:
- 📊 Overall status
- 🔄 Recent commits per repo
- 🐛 Open issues
- 📝 Open PRs
- 🎯 Today's priorities

## Continuous: PR Watch
Check for new PRs across all repos.
Notify when review is needed.

## Weekly: Architecture Review
Review cross-repo dependencies and suggest improvements.
