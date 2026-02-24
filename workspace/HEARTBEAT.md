# HEARTBEAT.md - Skill Curator

## Weekly Skill Discovery (rotate daily)

### Monday: ClawHub Trending
```bash
npx clawhub@latest search "trending" --limit 10
npx clawhub@latest search "new" --limit 10
```
Update skill-registry.json with findings.

### Wednesday: Awesome OpenClaw Skills
Check https://github.com/VoltAgent/awesome-openclaw-skills for new additions.

### Friday: Community Scan
Web search for new OpenClaw skills, tips, and workflows.
Check Discord/Reddit for community recommendations.

## Daily: Installed Skills Health
```bash
npx clawhub@latest update --all 2>&1 | head -20
```

## Skill Cleanup (Monthly)
- Check lastUsed dates in skill-registry.json
- Skills unused for 30+ days → candidate for disable/delete
- Report to user before deleting
