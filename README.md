# 🦞 OpenClaw Workspace Template

A curated OpenClaw workspace template with skill management, project templates, and best practices.

## Quick Start

```bash
# 1. Create a new profile
openclaw --profile <name> onboard

# 2. Clone this template into the profile workspace
git clone https://github.com/my-name-is-moca/openclaw-workspace-template.git ~/.openclaw-<name>/workspace

# 3. Copy .env.example and fill in your API keys
cp ~/.openclaw-<name>/workspace/.env.example ~/.openclaw-<name>/.env

# 4. Start the gateway
openclaw --profile <name> gateway
```

## Structure

```
├── .env.example              # All possible env vars
├── workspace/
│   ├── AGENTS.md             # Skill curator agent
│   ├── SOUL.md               # Agent personality
│   ├── HEARTBEAT.md          # Periodic skill discovery
│   ├── TOOLS.md              # Tool notes
│   ├── skill-registry.json   # Tracked skills
│   ├── skills/               # Installed ClawHub skills
│   ├── memory/               # Agent memory
│   └── templates/            # Project templates
│       ├── base/             # Common starter files
│       ├── trading/          # Trading bot projects
│       ├── dev-team/         # Multi-repo dev teams
│       └── research/         # Research projects
```

## Templates

### Base
Minimal workspace with AGENTS.md, SOUL.md, TOOLS.md.

### Dev Team
Multi-agent development team with PM, Frontend, Backend, Contract agents.
Includes openclaw.json.template, HEARTBEAT.md for daily reports, and Antfarm integration guide.

### Trading
Autonomous trading bot with risk management rules.

### Research
Deep research agent with structured report output.

## Skill Management

The dev profile agent automatically:
- 🔍 **Discovers** new skills weekly (ClawHub, awesome-openclaw-skills)
- ✅ **Evaluates** security (VirusTotal), quality, usefulness
- 📦 **Installs** approved skills
- 🗑️ **Cleans up** unused skills monthly
- 📊 **Tracks** everything in `skill-registry.json`

## Environment Variables

See `.env.example` for all supported variables across:
- LLM providers (Anthropic, OpenAI, Gemini, OpenRouter, xAI)
- Search (Brave, Perplexity)
- Social media (X/Twitter)
- Trading (Polymarket, Binance, Bithumb)
- Infrastructure (GitHub, Telegram)

## License

MIT
