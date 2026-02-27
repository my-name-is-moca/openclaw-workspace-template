# 🦞 OpenClaw Workspace Template

Automated OpenClaw profile setup with secret management (sops/age), workspace templates, and multi-agent dev team support.

## Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed (`npm install -g openclaw`)
- Node.js >= 22
- [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) for secret management
- A sops vault at `~/sops` (see [Secret Management](#secret-management))

## Quick Start

### 1. Clone

```bash
git clone https://github.com/my-name-is-moca/openclaw-workspace-template.git ~/oc-template
cd ~/oc-template
```

### 2. Setup a profile

```bash
# Basic profile (single agent)
./setup.sh <profile> base <port>

# Dev team profile (multi-agent)
./setup.sh <profile> dev-team <port> <agents>
```

**Examples:**

```bash
# Personal dev environment
./setup.sh dev base 18889

# DeFi project with 3 repo agents
./setup.sh defidash dev-team 19789 frontend,sdk,website

# Web app with standard team
./setup.sh myapp dev-team 19889 frontend,backend,devops

# Single agent, default port
./setup.sh research base
```

### 3. Personalize

```bash
./personalize.sh <profile>
```

Interactive CLI that fills `USER.md` with your preferences (name, language, communication style, values). This file is read by all agents at session start.

### 4. Start the gateway

```bash
# Use environment variables (workaround for --profile flag bugs)
export OPENCLAW_PROFILE="<profile>" && openclaw gateway --port <port>

# Or get port from config
export OPENCLAW_PROFILE="<profile>" && openclaw gateway --port $(jq -r '.gateway.port' ~/.openclaw-<profile>/openclaw.json)
```

### 5. Connect Telegram (optional)

```bash
# 1. Create a Telegram group
# 2. Add your bot to the group (make admin)
# 3. Configure
export OPENCLAW_PROFILE="<profile>" && openclaw configure --section telegram
```

## Known Issues & Workarounds

### `--profile` Flag Bug

Many OpenClaw subcommands ignore the `--profile` flag and write to the wrong directory (usually `~/.openclaw-dev/` instead of `~/.openclaw-<profile>/`). 

**Symptoms:**
- `openclaw --profile myapp plugins enable telegram` writes to wrong config
- Telegram plugin enabled but not reflected in your profile
- Gateway can't find expected config/data

**Solution:** Use environment variables instead of `--profile`:

```bash
# Instead of: openclaw --profile myapp gateway start
export OPENCLAW_PROFILE="myapp"
export OPENCLAW_STATE_DIR="$HOME/.openclaw-myapp" 
export OPENCLAW_CONFIG_PATH="$HOME/.openclaw-myapp/openclaw.json"
openclaw gateway start
```

The setup scripts in this template automatically use env vars to avoid this issue.

## What `setup.sh` does

1. **Decrypts secrets** from `~/sops` vault (API keys, tokens)
2. **Runs `openclaw onboard`** (non-interactive, creates profile dir)
3. **Deploys `.env`** with all API keys
4. **Sets up Telegram bot** (from vault or interactive)
5. **Patches `openclaw.json`** with:
   - Gemini embedding memory search (hybrid: 70% vector + 30% text)
   - Memory flush on compaction
   - Hooks (session-memory, command-logger)
   - Brave search integration
6. **Copies workspace files** (AGENTS.md, SOUL.md, USER.md, TOOLS.md, HEARTBEAT.md)
7. **Deploys `global/GLOBAL_AGENTS.md`** (team-wide shared rules)
8. **[dev-team only]** Creates per-agent workspaces + patches `agents.list`
9. **Runs `openclaw doctor`** to validate

## Templates

### `base`

Single agent workspace. Good for personal assistants, research, trading bots.

```bash
./setup.sh mybot base 18889
```

### `dev-team`

Multi-agent development team. Each agent gets its own workspace.

```bash
./setup.sh defidash dev-team 19789 frontend,sdk,website
```

Creates:
```
~/.openclaw-defidash/
├── openclaw.json              # Gateway config (agents.list populated)
├── .env                       # API keys from vault
├── global/
│   └── GLOBAL_AGENTS.md       # Team-wide rules & conventions
├── workspace/                 # PM / HQ agent
│   ├── AGENTS.md
│   ├── SOUL.md
│   ├── USER.md
│   ├── TOOLS.md
│   ├── HEARTBEAT.md
│   └── memory/
├── workspace-frontend/        # Frontend agent
│   ├── AGENTS.md
│   ├── SOUL.md
│   └── memory/
├── workspace-sdk/             # SDK agent
│   ├── AGENTS.md
│   ├── SOUL.md
│   └── memory/
├── workspace-website/         # Website agent
│   ├── AGENTS.md
│   ├── SOUL.md
│   └── memory/
└── repos/                     # Git repos (clone here)
```

The 4th argument is a comma-separated list of agents. No limit — use whatever makes sense for your project:

```bash
# Monorepo
./setup.sh app dev-team 19789 frontend,backend

# Microservices
./setup.sh platform dev-team 19789 api,auth,payments,notifications,devops

# Research team
./setup.sh lab dev-team 19789 researcher,analyst,writer
```

### `trading`

Autonomous trading bot with risk management rules.

### `research`

Deep research agent with structured report output.

## Workspace Files

Every agent reads these files at session start:

| File | Purpose | Injected? |
|------|---------|-----------|
| `AGENTS.md` | Operating rules, memory policy, behavior | ✅ Every turn |
| `SOUL.md` | Persona, tone, boundaries | ✅ Every turn |
| `USER.md` | Owner profile, preferences, communication style | ✅ Every turn |
| `IDENTITY.md` | Agent name, vibe, emoji (filled on first conversation) | ✅ Every turn |
| `TOOLS.md` | Local environment notes (SSH hosts, cameras, etc.) | ✅ Every turn |
| `HEARTBEAT.md` | Periodic check tasks | ✅ On heartbeat |
| `BOOT.md` | Gateway startup tasks (requires hooks) | On startup |
| `MEMORY.md` | Curated long-term memory (main session only) | ✅ Every turn |
| `memory/*.md` | Daily logs (accessed via memory_search) | On demand |

`global/GLOBAL_AGENTS.md` is read by all agents across all workspaces — use it for team conventions, cron naming, shared rules.

## Orchestration

For multi-agent workflow orchestration, two options integrate with this template:

### Antfarm (Recommended for getting started)

Deterministic YAML workflows with automatic retry, verification, and PR creation.

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/snarktank/antfarm/v0.5.1/scripts/install.sh | bash

# Install bundled workflows
antfarm install

# Run a feature
antfarm workflow run feature-dev "Add OAuth authentication"

# Monitor
antfarm dashboard
```

Custom workflows for multi-repo projects: see [Antfarm docs](https://github.com/snarktank/antfarm/blob/main/docs/creating-workflows.md).

### Lobster (Native OpenClaw workflow engine)

Typed pipeline runtime with approval gates. More flexible for multi-repo orchestration.

```bash
# Install the CLI
npm install -g @openclaw/lobster

# Enable in config
# Add "lobster" to tools.alsoAllow in openclaw.json
```

See [Lobster docs](https://docs.openclaw.ai/tools/lobster).

### Comparison

| | Antfarm | Lobster |
|---|---------|---------|
| Setup | One command | Manual YAML |
| Multi-repo | Custom workflow needed | Native via agent-send |
| Retry/loops | Built-in | PR pending |
| Dashboard | ✅ Web UI | ❌ |
| Verification | Built-in verifier agent | Manual step |
| PR creation | Built-in | Manual step |
| Dependencies | SQLite + cron | None (OpenClaw native) |

## Secret Management

This template uses [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) for secret management.

### Setup vault (one-time)

```bash
# Install
brew install sops age

# Create age key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Create vault
mkdir -p ~/sops
cd ~/sops
git init

# Create .env with your secrets
cat > .env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-xxx
GEMINI_API_KEY=AIza-xxx
OPENROUTER_API_KEY=sk-or-xxx
BRAVE_API_KEY=BSA-xxx
GITHUB_TOKEN=ghp_xxx
TELEGRAM_BOT_TOKEN_DEV=123:ABC
EOF

# Encrypt
AGE_PUB=$(grep "public key:" ~/.config/sops/age/keys.txt | awk '{print $NF}')
sops --encrypt --age "$AGE_PUB" --input-type dotenv --output-type dotenv .env > .env.enc
rm .env

# Commit
git add .env.enc
git commit -m "initial vault"
```

### Bot token naming

Telegram bot tokens are auto-detected from vault by profile name:

| Profile | Vault variable |
|---------|---------------|
| `dev` | `TELEGRAM_BOT_TOKEN_DEV` |
| `defidash` | `TELEGRAM_BOT_TOKEN_DEFIDASH` |
| `myapp` | `TELEGRAM_BOT_TOKEN_MYAPP` |

If not found in vault, setup.sh prompts interactively and saves to vault.

## Troubleshooting

### Config file not found

```bash
❌ Config file not found at ~/.openclaw-myapp/openclaw.json
```

**Cause:** OpenClaw onboard wrote config to wrong path due to `--profile` flag bug.

**Fix:** Check if config exists in `~/.openclaw-dev/openclaw.json` and move it:
```bash
mv ~/.openclaw-dev/openclaw.json ~/.openclaw-myapp/openclaw.json
```

Or re-run setup.sh (it will auto-detect and fix this).

### Telegram plugin not enabled

```bash
⚠️ Telegram plugin: not enabled (may need manual fix)
```

**Cause:** Plugin registration failed due to config path issues.

**Fix:**
```bash
export OPENCLAW_PROFILE="myapp"
openclaw plugins enable telegram
openclaw plugins list | grep telegram  # verify enabled
```

### Gateway won't start

**Check config:**
```bash
jq . ~/.openclaw-myapp/openclaw.json  # should be valid JSON
```

**Check port conflicts:**
```bash
lsof -i :18889  # replace with your port
```

**Check daemon status:**
```bash
export OPENCLAW_PROFILE="myapp"
openclaw gateway status
```

### Shell Aliases (recommended)

`setup.sh` auto-generates a shell alias in `~/.zshrc` for safe profile access:

```bash
# Auto-generated by setup.sh
alias oc-defidash='OPENCLAW_PROFILE=defidash OPENCLAW_STATE_DIR=$HOME/.openclaw-defidash OPENCLAW_CONFIG_PATH=$HOME/.openclaw-defidash/openclaw.json openclaw'
```

Usage:
```bash
oc-defidash status          # safe — always targets defidash config
oc-defidash plugins list    # no risk of overwriting dev config
oc-defidash gateway restart
```

⚠️ **Never use `openclaw --profile <name>` directly** — many subcommands ignore the flag and modify the wrong config. Always use the alias or set env vars manually.

### Memory search not working

**Cause:** Missing Gemini API key or wrong embedding model.

**Fix:** Add `GEMINI_API_KEY` to your `~/sops/.env` and re-run setup.sh.

## Full Example: DeFiDash Dev Team

```bash
# 1. Setup
cd ~/oc-template
./setup.sh defidash dev-team 19789 frontend,sdk,website

# 2. Personalize
./personalize.sh defidash

# 3. Clone repos
cd ~/.openclaw-defidash/repos
git clone https://github.com/curg-13/defidash-frontend.git
git clone https://github.com/curg-13/defidash-sdk.git
git clone https://github.com/curg-13/defidash-website.git

# 4. Edit team rules (optional)
vim ~/.openclaw-defidash/global/GLOBAL_AGENTS.md

# 5. Start gateway (use the auto-generated alias)
source ~/.zshrc
oc-defidash gateway start

# 6. (Optional) Install Antfarm for workflow orchestration
curl -fsSL https://raw.githubusercontent.com/snarktank/antfarm/v0.5.1/scripts/install.sh | bash
antfarm install
```

## License

MIT
