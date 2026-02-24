#!/bin/bash
# ============================================
# OpenClaw Profile Setup Script
# Usage: ./setup.sh <profile-name> [template]
# Example: ./setup.sh dev
#          ./setup.sh basecard dev-team
# ============================================

set -e

PROFILE=${1:-dev}
TEMPLATE=${2:-base}  # base, dev-team, trading, research
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🦞 OpenClaw Profile Setup: ${PROFILE}${NC}"
echo -e "   Template: ${TEMPLATE}"
echo ""

# ==========================================
# 1. Load secrets (vault or plain .env)
# ==========================================
ENV_FILE="${SCRIPT_DIR}/.env"
ENC_FILE="${SCRIPT_DIR}/.env.enc"

if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}🔑 Loading secrets from .env${NC}"
    source "$ENV_FILE"
elif [ -f "$ENC_FILE" ]; then
    echo -e "${GREEN}🔐 Decrypting secrets from .env.enc (sops + age)${NC}"
    if ! command -v sops &>/dev/null; then
        echo -e "${RED}❌ sops not installed. Run: brew install sops${NC}"
        exit 1
    fi
    # Decrypt to temp file, source it, then delete
    TEMP_ENV=$(mktemp)
    sops --decrypt --input-type dotenv --output-type dotenv "$ENC_FILE" > "$TEMP_ENV" 2>/dev/null
    source "$TEMP_ENV"
    rm -f "$TEMP_ENV"
else
    echo -e "${RED}❌ No secrets found. Either:${NC}"
    echo "   1. Copy .env.example → .env and fill in your keys"
    echo "   2. Create .env.enc: sops --encrypt --age <pubkey> .env > .env.enc"
    exit 1
fi

# Check required key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${RED}❌ ANTHROPIC_API_KEY not found in secrets${NC}"
    exit 1
fi

# ==========================================
# 2. Determine ports (avoid conflicts)
# ==========================================
BASE_PORT=18789
case "$PROFILE" in
    dev)       PORT=$((BASE_PORT + 100)) ;;  # 18889
    basecard)  PORT=$((BASE_PORT + 200)) ;;  # 18989
    *)         PORT=$((BASE_PORT + 300)) ;;  # 19089
esac

PROFILE_DIR="$HOME/.openclaw-${PROFILE}"

echo -e "${YELLOW}📁 Profile dir: ${PROFILE_DIR}${NC}"
echo -e "${YELLOW}🔌 Gateway port: ${PORT}${NC}"
echo ""

# ==========================================
# 3. Run non-interactive onboard
# ==========================================
echo -e "${GREEN}⚙️  Running onboard...${NC}"

ONBOARD_ARGS=(
    --profile "$PROFILE"
    onboard
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
    --workspace "${PROFILE_DIR}/workspace"
)

# Add optional keys
[ -n "$GEMINI_API_KEY" ] && ONBOARD_ARGS+=(--gemini-api-key "$GEMINI_API_KEY")
[ -n "$OPENROUTER_API_KEY" ] && ONBOARD_ARGS+=(--openrouter-api-key "$OPENROUTER_API_KEY")
[ -n "$BRAVE_API_KEY" ] && ONBOARD_ARGS+=(--brave-api-key "$BRAVE_API_KEY" 2>/dev/null || true)

openclaw "${ONBOARD_ARGS[@]}" 2>&1 || {
    echo -e "${YELLOW}⚠️  Onboard had warnings (may be ok). Continuing...${NC}"
}

# ==========================================
# 4. Copy template files
# ==========================================
echo -e "${GREEN}📋 Applying template: ${TEMPLATE}${NC}"

TEMPLATE_DIR="${SCRIPT_DIR}/workspace/templates"
WORKSPACE="${PROFILE_DIR}/workspace"

# Copy base template first
if [ -d "${TEMPLATE_DIR}/base" ]; then
    cp -n "${TEMPLATE_DIR}/base/"* "${WORKSPACE}/" 2>/dev/null || true
fi

# Copy specific template (override base)
if [ -d "${TEMPLATE_DIR}/${TEMPLATE}" ] && [ "$TEMPLATE" != "base" ]; then
    cp -r "${TEMPLATE_DIR}/${TEMPLATE}/"* "${WORKSPACE}/" 2>/dev/null || true
fi

# Create memory dir
mkdir -p "${WORKSPACE}/memory"

# ==========================================
# 5. Deploy .env to profile (decrypt if needed)
# ==========================================
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "${PROFILE_DIR}/.env"
elif [ -f "$ENC_FILE" ]; then
    sops --decrypt --input-type dotenv --output-type dotenv "$ENC_FILE" > "${PROFILE_DIR}/.env"
fi
chmod 600 "${PROFILE_DIR}/.env"

# ==========================================
# 6. Copy skill-registry if it exists
# ==========================================
if [ -f "${SCRIPT_DIR}/workspace/skill-registry.json" ]; then
    cp "${SCRIPT_DIR}/workspace/skill-registry.json" "${WORKSPACE}/skill-registry.json"
fi

# ==========================================
# 7. For dev-team: create agent workspaces
# ==========================================
if [ "$TEMPLATE" = "dev-team" ]; then
    echo -e "${GREEN}👥 Creating agent workspaces...${NC}"
    for agent in frontend backend contract; do
        agent_ws="${PROFILE_DIR}/workspace-${agent}"
        mkdir -p "${agent_ws}/memory"
        # Copy base AGENTS.md if not exists
        [ ! -f "${agent_ws}/AGENTS.md" ] && cat > "${agent_ws}/AGENTS.md" << EOF
# AGENTS.md - ${agent^} Agent

## Role
${agent^} development agent for the project.

## Rules
- Work only in your assigned repo
- Create feature branches, never push to main
- Run tests before creating PRs
- Coordinate with PM for cross-repo changes
EOF
    done
    
    # Create repos directory
    mkdir -p "${PROFILE_DIR}/repos"
    echo -e "${GREEN}📂 Created repos/ directory for git clones${NC}"
fi

# ==========================================
# Done!
# ==========================================
echo ""
echo -e "${GREEN}✅ Profile '${PROFILE}' setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review: ${PROFILE_DIR}/workspace/AGENTS.md"
echo "  2. Start:  openclaw --profile ${PROFILE} gateway --port ${PORT}"
echo ""
if [ "$TEMPLATE" = "dev-team" ]; then
    echo "  3. Clone repos:"
    echo "     cd ${PROFILE_DIR}/repos"
    echo "     git clone <your-repos>"
    echo ""
fi
