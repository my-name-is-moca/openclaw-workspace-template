#!/bin/bash
# ============================================
# OpenClaw Profile Setup (Non-Interactive)
# Usage: ./setup.sh <profile> [template] [port]
# Example: ./setup.sh dev base 18889
#          ./setup.sh basecard dev-team 18989
# ============================================

set -e

PROFILE=${1:-dev}
TEMPLATE=${2:-base}
PORT=${3:-$((18789 + RANDOM % 200 + 100))}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_DIR="$HOME/.openclaw-${PROFILE}"
VAULT_DIR="${SOPS_VAULT:-$HOME/sops}"
WORKSPACE="${PROFILE_DIR}/workspace"

# Colors
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'

echo -e "${G}🦞 OpenClaw Profile Setup${N}"
echo "   Profile:  ${PROFILE}"
echo "   Template: ${TEMPLATE}"
echo "   Port:     ${PORT}"
echo "   Dir:      ${PROFILE_DIR}"
echo ""

# ==========================================
# 1. Load secrets from ~/sops vault
# ==========================================
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
    echo -e "${R}❌ Age key not found at $SOPS_AGE_KEY_FILE${N}"
    echo "   Run: cd ~/sops && ./vault.sh init"
    exit 1
fi

ENC_FILE="${VAULT_DIR}/.env.enc"
if [ ! -f "$ENC_FILE" ]; then
    echo -e "${R}❌ Vault not found at ${ENC_FILE}${N}"
    echo "   Run: cd ~/sops && ./vault.sh encrypt"
    exit 1
fi

echo -e "${G}🔐 Decrypting secrets from vault...${N}"
TEMP_ENV=$(mktemp)
sops --decrypt --input-type dotenv --output-type dotenv "$ENC_FILE" > "$TEMP_ENV"
source "$TEMP_ENV"

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${R}❌ ANTHROPIC_API_KEY not found in vault${N}"
    rm -f "$TEMP_ENV"
    exit 1
fi
echo -e "${G}   ✅ Keys loaded${N}"

# ==========================================
# 2. Run openclaw onboard (non-interactive)
# ==========================================
echo -e "${G}⚙️  Running onboard...${N}"

ONBOARD_ARGS=(
    --non-interactive
    --accept-risk
    --flow quickstart
    --mode local
    --auth-choice token
    --token "$ANTHROPIC_API_KEY"
    --token-provider anthropic
    --gateway-port "$PORT"
    --gateway-bind loopback
    --gateway-auth token
    --node-manager pnpm
    --skip-channels
    --skip-skills
    --skip-daemon
    --skip-ui
    --skip-health
    --workspace "$WORKSPACE"
)

# Auto-inject all available API keys from vault
[ -n "$GEMINI_API_KEY" ]      && ONBOARD_ARGS+=(--gemini-api-key "$GEMINI_API_KEY")
[ -n "$OPENAI_API_KEY" ]      && ONBOARD_ARGS+=(--openai-api-key "$OPENAI_API_KEY")
[ -n "$OPENROUTER_API_KEY" ]  && ONBOARD_ARGS+=(--openrouter-api-key "$OPENROUTER_API_KEY")
[ -n "$XAI_API_KEY" ]         && ONBOARD_ARGS+=(--xai-api-key "$XAI_API_KEY")
[ -n "$MISTRAL_API_KEY" ]     && ONBOARD_ARGS+=(--mistral-api-key "$MISTRAL_API_KEY")
[ -n "$TOGETHER_API_KEY" ]    && ONBOARD_ARGS+=(--together-api-key "$TOGETHER_API_KEY")
[ -n "$HUGGINGFACE_API_KEY" ] && ONBOARD_ARGS+=(--huggingface-api-key "$HUGGINGFACE_API_KEY")
[ -n "$VENICE_API_KEY" ]      && ONBOARD_ARGS+=(--venice-api-key "$VENICE_API_KEY")
[ -n "$MOONSHOT_API_KEY" ]    && ONBOARD_ARGS+=(--moonshot-api-key "$MOONSHOT_API_KEY")
[ -n "$ZAI_API_KEY" ]         && ONBOARD_ARGS+=(--zai-api-key "$ZAI_API_KEY")
[ -n "$LITELLM_API_KEY" ]     && ONBOARD_ARGS+=(--litellm-api-key "$LITELLM_API_KEY")

# Show which keys are being injected
echo -e "${G}   Keys: ANTHROPIC=✅ $([ -n "$GEMINI_API_KEY" ] && echo "GEMINI=✅") $([ -n "$OPENAI_API_KEY" ] && echo "OPENAI=✅") $([ -n "$OPENROUTER_API_KEY" ] && echo "OPENROUTER=✅") $([ -n "$XAI_API_KEY" ] && echo "XAI=✅")${N}"

openclaw --profile "$PROFILE" onboard "${ONBOARD_ARGS[@]}" \
    2>&1 || echo -e "${Y}⚠️  Onboard warnings (continuing...)${N}"

# ==========================================
# 3. Deploy .env to profile
# ==========================================
echo -e "${G}🔑 Deploying secrets...${N}"
cp "$TEMP_ENV" "${PROFILE_DIR}/.env"
chmod 600 "${PROFILE_DIR}/.env"
rm -f "$TEMP_ENV"

# ==========================================
# 4. Patch openclaw.json
# ==========================================
echo -e "${G}📝 Configuring openclaw.json...${N}"

python3 << PYEOF
import json, os

config_path = os.path.expanduser("~/.openclaw-${PROFILE}/openclaw.json")
c = json.load(open(config_path))

# Web search
brave_key = os.environ.get("BRAVE_API_KEY", "")
if brave_key:
    c.setdefault("tools", {})["web"] = {
        "search": {"enabled": True, "apiKey": brave_key},
        "fetch": {"enabled": True}
    }

# Memory search (Gemini)
gemini_key = os.environ.get("GEMINI_API_KEY", "")
if gemini_key:
    c.setdefault("agents", {}).setdefault("defaults", {})["memorySearch"] = {
        "provider": "gemini",
        "model": "gemini-embedding-001",
        "query": {"hybrid": {"enabled": True, "vectorWeight": 0.7, "textWeight": 0.3}}
    }

# Performance
defaults = c.setdefault("agents", {}).setdefault("defaults", {})
defaults["maxConcurrent"] = 8
defaults["subagents"] = {"maxConcurrent": 16, "model": "claude-sonnet-4-20250514"}
defaults.setdefault("compaction", {})["mode"] = "safeguard"

# Hooks (internal only, no webhook token needed)
c["hooks"] = {
    "internal": {
        "enabled": True,
        "entries": {
            "session-memory": {"enabled": True},
            "command-logger": {"enabled": True}
        }
    }
}

json.dump(c, open(config_path, "w"), indent=2)
print("   ✅ Config patched")
PYEOF

# ==========================================
# 5. Deploy workspace files from template
# ==========================================
echo -e "${G}📋 Applying template: ${TEMPLATE}${N}"

TEMPLATE_DIR="${SCRIPT_DIR}/workspace/templates"

# Copy base template (force overwrite bootstrap defaults)
if [ -d "${TEMPLATE_DIR}/base" ]; then
    for f in "${TEMPLATE_DIR}/base/"*; do
        [ -f "$f" ] && cp "$f" "$WORKSPACE/" 2>/dev/null || true
    done
fi

# Copy specific template (overrides base)
if [ -d "${TEMPLATE_DIR}/${TEMPLATE}" ] && [ "$TEMPLATE" != "base" ]; then
    for f in "${TEMPLATE_DIR}/${TEMPLATE}/"*; do
        [ -f "$f" ] && cp "$f" "$WORKSPACE/" 2>/dev/null || true
    done
fi

# Ensure dirs exist
mkdir -p "$WORKSPACE/memory" "$WORKSPACE/skills"

# Remove bootstrap defaults (we have our own)
rm -f "$WORKSPACE/BOOTSTRAP.md"

# For non-base templates, copy the main workspace curated files
# (AGENTS.md, SOUL.md, HEARTBEAT.md, TOOLS.md from the script's workspace/)
for f in AGENTS.md SOUL.md HEARTBEAT.md TOOLS.md; do
    [ -f "${SCRIPT_DIR}/workspace/${f}" ] && cp "${SCRIPT_DIR}/workspace/${f}" "$WORKSPACE/"
done

# Copy skill registry if available
[ -f "${SCRIPT_DIR}/workspace/skill-registry.json" ] && \
    cp "${SCRIPT_DIR}/workspace/skill-registry.json" "$WORKSPACE/"

# ==========================================
# 6. Dev-team: create agent workspaces
# ==========================================
if [ "$TEMPLATE" = "dev-team" ]; then
    echo -e "${G}👥 Creating agent workspaces...${N}"
    for agent in frontend backend contract; do
        agent_ws="${PROFILE_DIR}/workspace-${agent}"
        mkdir -p "${agent_ws}/memory"
        [ ! -f "${agent_ws}/AGENTS.md" ] && cat > "${agent_ws}/AGENTS.md" << EOF
# AGENTS.md - ${agent^} Agent

## Role
${agent^} development agent.

## Rules
- Work only in your assigned repo under repos/
- Create feature branches, never push to main
- Run tests before creating PRs
EOF
    done
    mkdir -p "${PROFILE_DIR}/repos"
    echo -e "${G}   📂 Created repos/ for git clones${N}"
fi

# ==========================================
# 7. Telegram Bot Setup (interactive)
# ==========================================
PROFILE_UPPER=$(echo "$PROFILE" | tr '[:lower:]' '[:upper:]')
BOT_TOKEN_VAR="TELEGRAM_BOT_TOKEN_${PROFILE_UPPER}"

# Check if token already exists in vault
EXISTING_TOKEN=$(eval echo "\${$BOT_TOKEN_VAR:-}")

if [ -n "$EXISTING_TOKEN" ]; then
    echo -e "${G}🤖 Telegram bot token found in vault (${BOT_TOKEN_VAR})${N}"
    TG_TOKEN="$EXISTING_TOKEN"
else
    echo ""
    echo -e "${Y}🤖 Telegram Bot Setup${N}"
    echo "   Create a bot via @BotFather → /newbot"
    echo "   Recommended name: ${PROFILE}-bot"
    echo ""
    read -p "   Paste bot token (or Enter to skip): " TG_TOKEN
fi

if [ -n "$TG_TOKEN" ]; then
    # Patch openclaw.json with telegram config
    python3 << PYEOF2
import json, os
config_path = os.path.expanduser("~/.openclaw-${PROFILE}/openclaw.json")
c = json.load(open(config_path))
c.setdefault("channels", {})["telegram"] = {
    "enabled": True,
    "botToken": "${TG_TOKEN}",
    "dmPolicy": "pairing",
    "groupPolicy": "allowlist",
    "groups": {},
    "streamMode": "partial"
}
c.setdefault("plugins", {}).setdefault("entries", {})["telegram"] = {"enabled": True}
json.dump(c, open(config_path, "w"), indent=2)
print("   ✅ Telegram configured")
PYEOF2

    # Save to vault if new token
    if [ -z "$EXISTING_TOKEN" ] && [ -f "$ENC_FILE" ]; then
        echo -e "${G}🔐 Saving token to vault as ${BOT_TOKEN_VAR}...${N}"
        # Decrypt → append → re-encrypt
        TEMP_VAULT=$(mktemp)
        sops --decrypt --input-type dotenv --output-type dotenv "$ENC_FILE" > "$TEMP_VAULT"

        # Remove existing line if any, then append
        grep -v "^${BOT_TOKEN_VAR}=" "$TEMP_VAULT" > "${TEMP_VAULT}.tmp" || true
        echo "${BOT_TOKEN_VAR}=${TG_TOKEN}" >> "${TEMP_VAULT}.tmp"
        mv "${TEMP_VAULT}.tmp" "$TEMP_VAULT"

        # Re-encrypt
        AGE_PUB=$(grep "public key:" "$SOPS_AGE_KEY_FILE" | awk '{print $NF}')
        sops --encrypt --age "$AGE_PUB" --input-type dotenv --output-type dotenv "$TEMP_VAULT" > "$ENC_FILE"
        rm -f "$TEMP_VAULT"
        echo -e "${G}   ✅ Token saved to vault${N}"

        # Also update profile .env
        echo "${BOT_TOKEN_VAR}=${TG_TOKEN}" >> "${PROFILE_DIR}/.env"

        # Commit vault changes
        (cd "$VAULT_DIR" && git add -A && git commit -m "add ${BOT_TOKEN_VAR}" && git push) 2>/dev/null || true
    fi

    echo ""
    echo -e "${Y}📱 Next: Create a Telegram group for this profile${N}"
    echo "   1. Create group (enable Topics in group settings)"
    echo "   2. Add @$(echo $TG_TOKEN | cut -d: -f1) bot to group"
    echo "   3. Send a message, then run:"
    echo "      openclaw --profile ${PROFILE} configure --section telegram"
    echo "   4. Or manually add group ID to openclaw.json"
fi

# ==========================================
# 8. Kill any orphan gateway for this profile
# ==========================================
pkill -f "openclaw-gateway.*${PORT}" 2>/dev/null || true

# ==========================================
# Done!
# ==========================================
echo ""
echo -e "${G}✅ Profile '${PROFILE}' ready!${N}"
echo ""
echo "   Start gateway:"
echo "   openclaw --profile ${PROFILE} gateway --port ${PORT}"
echo ""
[ "$TEMPLATE" = "dev-team" ] && echo "   Clone repos: cd ${PROFILE_DIR}/repos && git clone <url>"
