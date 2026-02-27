#!/bin/bash
# ============================================
# OpenClaw Profile Setup (Non-Interactive)
# Usage: ./setup.sh <profile> [template] [port] [agents]
# Example: ./setup.sh dev base 18889
#          ./setup.sh defidash dev-team 19789 frontend,sdk,website
#          ./setup.sh myapp dev-team 19889 frontend,backend,devops
# ============================================

set -e

PROFILE=${1:-dev}
TEMPLATE=${2:-base}
PORT=${3:-$((18789 + RANDOM % 200 + 100))}
AGENTS_CSV=${4:-frontend,backend,contract}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_DIR="$HOME/.openclaw-${PROFILE}"
VAULT_DIR="${SOPS_VAULT:-$HOME/sops}"
WORKSPACE="${PROFILE_DIR}/workspace"

# Colors
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'

# ==========================================
# Environment variables (workaround for --profile flag bugs)
# ==========================================
# Note: Many openclaw subcommands ignore --profile flag and write to wrong paths.
# Using env vars ensures commands target the correct profile directory.
export OPENCLAW_PROFILE="$PROFILE"
export OPENCLAW_STATE_DIR="$HOME/.openclaw-$PROFILE"
export OPENCLAW_CONFIG_PATH="$HOME/.openclaw-$PROFILE/openclaw.json"

echo -e "${G}🦞 OpenClaw Profile Setup${N}"
echo "   Profile:  ${PROFILE}"
echo "   Template: ${TEMPLATE}"
echo "   Port:     ${PORT}"
echo "   Dir:      ${PROFILE_DIR}"
[ "$TEMPLATE" = "dev-team" ] && echo "   Agents:   ${AGENTS_CSV}"
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
    --node-manager npm
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

echo -e "${G}   Keys: ANTHROPIC=✅ $([ -n "$GEMINI_API_KEY" ] && echo "GEMINI=✅") $([ -n "$OPENAI_API_KEY" ] && echo "OPENAI=✅") $([ -n "$OPENROUTER_API_KEY" ] && echo "OPENROUTER=✅") $([ -n "$XAI_API_KEY" ] && echo "XAI=✅")${N}"

# Use env vars instead of --profile flag (which doesn't work for many subcommands)
openclaw onboard "${ONBOARD_ARGS[@]}" \
    2>&1 || echo -e "${Y}⚠️  Onboard warnings (continuing...)${N}"

# ==========================================
# 3. Deploy .env to profile
# ==========================================
echo -e "${G}🔑 Deploying secrets...${N}"
cp "$TEMP_ENV" "${PROFILE_DIR}/.env"
chmod 600 "${PROFILE_DIR}/.env"
rm -f "$TEMP_ENV"

# ==========================================
# 4. Telegram Bot Setup (interactive, before config patch)
# ==========================================
PROFILE_UPPER=$(echo "$PROFILE" | tr '[:lower:]' '[:upper:]')
BOT_TOKEN_VAR="TELEGRAM_BOT_TOKEN_${PROFILE_UPPER}"
EXISTING_TOKEN=$(eval echo "\${$BOT_TOKEN_VAR:-}")
TG_TOKEN=""

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

    # Save new token to vault
    if [ -n "$TG_TOKEN" ] && [ -f "$ENC_FILE" ]; then
        echo -e "${G}🔐 Saving token to vault as ${BOT_TOKEN_VAR}...${N}"
        TEMP_VAULT=$(mktemp)
        sops --decrypt --input-type dotenv --output-type dotenv "$ENC_FILE" > "$TEMP_VAULT"
        grep -v "^${BOT_TOKEN_VAR}=" "$TEMP_VAULT" > "${TEMP_VAULT}.tmp" || true
        echo "${BOT_TOKEN_VAR}=${TG_TOKEN}" >> "${TEMP_VAULT}.tmp"
        mv "${TEMP_VAULT}.tmp" "$TEMP_VAULT"
        AGE_PUB=$(grep "public key:" "$SOPS_AGE_KEY_FILE" | awk '{print $NF}')
        sops --encrypt --age "$AGE_PUB" --input-type dotenv --output-type dotenv "$TEMP_VAULT" > "$ENC_FILE"
        rm -f "$TEMP_VAULT"
        echo "${BOT_TOKEN_VAR}=${TG_TOKEN}" >> "${PROFILE_DIR}/.env"
        (cd "$VAULT_DIR" && git add -A && git commit -m "add ${BOT_TOKEN_VAR}" && git push) 2>/dev/null || true
        echo -e "${G}   ✅ Token saved to vault${N}"
    fi
fi

# ==========================================
# 5. Patch openclaw.json (single pass, docs-compliant)
# ==========================================
echo -e "${G}📝 Configuring openclaw.json...${N}"

# Verify config file exists (Bug fix: onboard might write to wrong path due to --profile issues)
if [ ! -f "${PROFILE_DIR}/openclaw.json" ]; then
    echo -e "${R}❌ Config file not found at ${PROFILE_DIR}/openclaw.json${N}"
    echo "   This usually means onboard wrote to wrong path due to --profile bug"
    echo "   Check ~/.openclaw-dev/openclaw.json for misplaced config"
    if [ -f "$HOME/.openclaw-dev/openclaw.json" ]; then
        echo -e "${Y}   Moving config from wrong location...${N}"
        mv "$HOME/.openclaw-dev/openclaw.json" "${PROFILE_DIR}/openclaw.json"
    else
        echo "   Creating minimal config..."
        mkdir -p "${PROFILE_DIR}"
        cat > "${PROFILE_DIR}/openclaw.json" << 'JSONEOF'
{
  "gateway": {
    "port": $PORT,
    "bind": "loopback"
  },
  "agents": {
    "defaults": {}
  }
}
JSONEOF
    fi
fi

python3 << PYEOF
import json, os

config_path = os.path.expanduser("~/.openclaw-${PROFILE}/openclaw.json")
c = json.load(open(config_path))

# --- Remove any invalid keys doctor would complain about ---
for bad_key in ["discovery", "auth", "wizard", "streaming"]:
    c.pop(bad_key, None)

# --- agents.defaults ---
defaults = c.setdefault("agents", {}).setdefault("defaults", {})

# Performance (docs: agents.defaults.maxConcurrent)
defaults["maxConcurrent"] = 8

# Subagents (docs: agents.defaults.subagents -- not in reference but used by runtime)
defaults["subagents"] = {"maxConcurrent": 16, "model": "claude-sonnet-4-20250514"}

# Compaction (docs: agents.defaults.compaction) + memoryFlush
defaults["compaction"] = {"mode": "safeguard", "memoryFlush": {"enabled": True}}

# Memory search (Gemini embeddings)
gemini_key = os.environ.get("GEMINI_API_KEY", "")
if gemini_key:
    defaults["memorySearch"] = {
        "provider": "gemini",
        "model": "gemini-embedding-001",
        "query": {"hybrid": {"enabled": True, "vectorWeight": 0.7, "textWeight": 0.3}}
    }

# --- tools.web (docs: tools section) ---
brave_key = os.environ.get("BRAVE_API_KEY", "")
if brave_key:
    c.setdefault("tools", {})["web"] = {
        "search": {"enabled": True, "apiKey": brave_key},
        "fetch": {"enabled": True}
    }

# --- hooks.internal (docs: hooks.internal.enabled + entries) ---
c["hooks"] = {
    "internal": {
        "enabled": True,
        "entries": {
            "session-memory": {"enabled": True},
            "command-logger": {"enabled": True}
        }
    }
}

# --- channels.telegram (docs: channels.telegram) ---
tg_token = "${TG_TOKEN}"
if tg_token:
    c.setdefault("channels", {})["telegram"] = {
        "enabled": True,
        "botToken": tg_token,
        "dmPolicy": "pairing",
        "groupPolicy": "allowlist",
        "groups": {},
        "streaming": "partial"  # docs: "streaming" not "streamMode"
    }

# --- Enable telegram plugin if token is set ---
if tg_token:
    c.setdefault("plugins", {}).setdefault("entries", {})["telegram"] = {"enabled": True}

# --- Final save ---
json.dump(c, open(config_path, "w"), indent=2)
print("   ✅ Config patched (docs-compliant)")
PYEOF

# Bug fix: Enable telegram plugin (--skip-channels means plugin stays disabled)
# Use env vars instead of --profile flag
if [ -n "$TG_TOKEN" ]; then
    echo -e "${G}🔌 Enabling telegram plugin...${N}"
    openclaw plugins enable telegram || echo -e "${Y}⚠️  Plugin enable failed (check manually)${N}"
fi

# ==========================================
# 6. Deploy workspace files from template
# ==========================================
echo -e "${G}📋 Applying template: ${TEMPLATE}${N}"

TEMPLATE_DIR="${SCRIPT_DIR}/workspace/templates"

# Always copy curated workspace files from script repo
# (overrides bootstrap defaults from onboard)
for f in AGENTS.md SOUL.md HEARTBEAT.md TOOLS.md USER.md IDENTITY.md BOOT.md MEMORY.md; do
    [ -f "${SCRIPT_DIR}/workspace/${f}" ] && cp "${SCRIPT_DIR}/workspace/${f}" "$WORKSPACE/"
done

# Copy base template files (won't overwrite above)
if [ -d "${TEMPLATE_DIR}/base" ]; then
    for f in "${TEMPLATE_DIR}/base/"*; do
        [ -f "$f" ] && cp -n "$f" "$WORKSPACE/" 2>/dev/null || true
    done
fi

# Copy specific template (overrides)
if [ -d "${TEMPLATE_DIR}/${TEMPLATE}" ] && [ "$TEMPLATE" != "base" ]; then
    for f in "${TEMPLATE_DIR}/${TEMPLATE}/"*; do
        [ -f "$f" ] && cp "$f" "$WORKSPACE/" 2>/dev/null || true
    done
fi

# Copy global dir (team-wide rules)
if [ -d "${SCRIPT_DIR}/workspace/global" ]; then
    mkdir -p "${PROFILE_DIR}/global"
    cp -r "${SCRIPT_DIR}/workspace/global/"* "${PROFILE_DIR}/global/" 2>/dev/null || true
    echo -e "${G}   📋 global/GLOBAL_AGENTS.md deployed${N}"
fi

# Ensure dirs exist
mkdir -p "$WORKSPACE/memory" "$WORKSPACE/skills"

# Copy templates dir for dev profile
[ -d "${SCRIPT_DIR}/workspace/templates" ] && cp -r "${SCRIPT_DIR}/workspace/templates" "$WORKSPACE/" 2>/dev/null || true

# Remove bootstrap (we have our own files)
rm -f "$WORKSPACE/BOOTSTRAP.md"

# Copy skill registry if available
[ -f "${SCRIPT_DIR}/workspace/skill-registry.json" ] && \
    cp "${SCRIPT_DIR}/workspace/skill-registry.json" "$WORKSPACE/"

# ==========================================
# 7. Dev-team: create agent workspaces
# ==========================================
if [ "$TEMPLATE" = "dev-team" ]; then
    echo -e "${G}👥 Creating agent workspaces...${N}"
    IFS=',' read -ra AGENTS <<< "$AGENTS_CSV"
    
    # Build agents list for openclaw.json
    AGENTS_JSON="["
    AGENTS_JSON+="{\"id\":\"pm\",\"default\":true,\"name\":\"Project Manager\",\"workspace\":\"${PROFILE_DIR}/workspace\"}"
    for agent in "${AGENTS[@]}"; do
        agent=$(echo "$agent" | xargs)  # trim whitespace
        agent_ws="${PROFILE_DIR}/workspace-${agent}"
        mkdir -p "${agent_ws}/memory" "${agent_ws}/skills"
        AGENT_UPPER=$(echo "$agent" | sed 's/./\U&/')
        [ ! -f "${agent_ws}/AGENTS.md" ] && cat > "${agent_ws}/AGENTS.md" << EOF
# AGENTS.md - ${AGENT_UPPER} Agent

## Role
${AGENT_UPPER} development agent.

## Rules
- Work only in your assigned repo under repos/
- Create feature branches, never push to main
- Run tests before creating PRs
EOF
        [ ! -f "${agent_ws}/SOUL.md" ] && cp "${SCRIPT_DIR}/workspace/SOUL.md" "${agent_ws}/" 2>/dev/null || true
        AGENTS_JSON+=",{\"id\":\"${agent}\",\"name\":\"${AGENT_UPPER} Dev\",\"workspace\":\"${agent_ws}\"}"
        echo -e "${G}   📂 workspace-${agent}/${N}"
    done
    AGENTS_JSON+="]"
    
    # Patch openclaw.json with dynamic agents list
    python3 << PYEOF
import json
config_path = "${PROFILE_DIR}/openclaw.json"
c = json.load(open(config_path))
c["agents"]["list"] = json.loads('${AGENTS_JSON}')
json.dump(c, open(config_path, "w"), indent=2)
PYEOF
    
    mkdir -p "${PROFILE_DIR}/repos"
    echo -e "${G}   📂 Created repos/ for git clones${N}"
    echo -e "${G}   👥 Agents: pm (HQ), ${AGENTS_CSV}${N}"
fi

# ==========================================
# 8. Install gateway daemon (launchd/systemd)
# ==========================================
echo -e "${G}🔧 Installing gateway daemon...${N}"
# Use env vars instead of --profile flag 
openclaw gateway install 2>&1 || echo -e "${Y}⚠️  Daemon install skipped (manual: openclaw gateway install)${N}"

# ==========================================
# 9. Kill any orphan gateway for this profile
# ==========================================
pkill -f "openclaw-gateway.*${PORT}" 2>/dev/null || true

# ==========================================
# 10. Verification
# ==========================================
echo -e "${G}🔍 Verifying setup...${N}"

# Check config file exists and has correct port
if [ -f "${PROFILE_DIR}/openclaw.json" ]; then
    ACTUAL_PORT=$(python3 -c "import json; print(json.load(open('${PROFILE_DIR}/openclaw.json')).get('gateway', {}).get('port', 'missing'))")
    echo -e "${G}   ✅ Config file: ${PROFILE_DIR}/openclaw.json (port: $ACTUAL_PORT)${N}"
else
    echo -e "${R}   ❌ Config file missing${N}"
fi

# Check telegram plugin status if token was provided
if [ -n "$TG_TOKEN" ]; then
    TG_PLUGIN_STATUS=$(openclaw plugins list | grep telegram | grep enabled || echo "disabled")
    if [[ "$TG_PLUGIN_STATUS" == *"enabled"* ]]; then
        echo -e "${G}   ✅ Telegram plugin: enabled${N}"
    else
        echo -e "${Y}   ⚠️  Telegram plugin: not enabled (may need manual fix)${N}"
    fi
fi

# Check workspace files
WORKSPACE_FILES="AGENTS.md SOUL.md USER.md TOOLS.md HEARTBEAT.md"
MISSING_FILES=""
for file in $WORKSPACE_FILES; do
    if [ -f "${WORKSPACE}/${file}" ]; then
        echo -e "${G}   ✅ Workspace file: ${file}${N}"
    else
        MISSING_FILES="${MISSING_FILES} ${file}"
    fi
done
[ -n "$MISSING_FILES" ] && echo -e "${Y}   ⚠️  Missing workspace files:${MISSING_FILES}${N}"

# ==========================================
# Done!
# ==========================================
echo ""
echo -e "${G}✅ Profile '${PROFILE}' ready!${N}"
echo ""
echo "   Start gateway (use env vars, not --profile flag):"
echo "   export OPENCLAW_PROFILE=\"${PROFILE}\" && openclaw gateway start"
echo "   (or foreground: export OPENCLAW_PROFILE=\"${PROFILE}\" && openclaw gateway --port ${PORT})"
echo ""
if [ -n "$TG_TOKEN" ]; then
    echo -e "${Y}📱 Telegram setup:${N}"
    echo "   1. Create a Telegram group"
    echo "   2. Add bot to group (make admin)"
    echo "   3. export OPENCLAW_PROFILE=\"${PROFILE}\" && openclaw configure --section telegram"
fi
echo ""
echo -e "${Y}👤 Personalize:${N}"
echo "   Edit ${WORKSPACE}/USER.md with your preferences"
[ "$TEMPLATE" = "dev-team" ] && echo "   Clone repos: cd ${PROFILE_DIR}/repos && git clone <url>"

# ==========================================
# 11. Generate shell alias
# ==========================================
ALIAS_NAME="oc-${PROFILE}"
ALIAS_LINE="alias ${ALIAS_NAME}='OPENCLAW_PROFILE=${PROFILE} OPENCLAW_STATE_DIR=\$HOME/.openclaw-${PROFILE} OPENCLAW_CONFIG_PATH=\$HOME/.openclaw-${PROFILE}/openclaw.json openclaw'"

# Add to .zshrc if not already present
SHELL_RC="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"

if ! grep -qF "${ALIAS_NAME}=" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# OpenClaw profile alias (auto-generated by setup.sh)" >> "$SHELL_RC"
    echo "${ALIAS_LINE}" >> "$SHELL_RC"
    echo -e "${G}🔗 Shell alias added: ${ALIAS_NAME}${N}"
    echo "   Usage: ${ALIAS_NAME} status"
    echo "   Reload: source ${SHELL_RC}"
else
    echo -e "${G}🔗 Shell alias already exists: ${ALIAS_NAME}${N}"
fi
