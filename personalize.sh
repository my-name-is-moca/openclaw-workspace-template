#!/bin/bash
# ============================================
# OpenClaw Profile Personalization
# Usage: ./personalize.sh <profile>
# Example: ./personalize.sh defidash
#
# Interactively fills USER.md with your preferences.
# Run after setup.sh, before starting the gateway.
# ============================================

set -e

PROFILE=${1:-dev}
PROFILE_DIR="$HOME/.openclaw-${PROFILE}"
WORKSPACE="${PROFILE_DIR}/workspace"
USER_MD="${WORKSPACE}/USER.md"

# Colors
G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'

if [ ! -d "$WORKSPACE" ]; then
    echo -e "\033[0;31m❌ Profile '${PROFILE}' not found. Run setup.sh first.${N}"
    exit 1
fi

echo -e "${G}👤 OpenClaw Profile Personalization${N}"
echo "   Profile: ${PROFILE}"
echo "   File:    ${USER_MD}"
echo ""

# --- Collect info ---
read -p "$(echo -e "${C}Your name: ${N}")" USER_NAME
read -p "$(echo -e "${C}What should the agent call you: ${N}")" CALL_ME
read -p "$(echo -e "${C}Timezone (e.g. Asia/Seoul): ${N}")" TZ_INPUT
read -p "$(echo -e "${C}Primary language (e.g. Korean, English): ${N}")" LANG_INPUT
echo ""

echo -e "${Y}Skills & Context${N}"
read -p "$(echo -e "${C}What are you strong at: ${N}")" STRONG_AT
read -p "$(echo -e "${C}What are you currently learning: ${N}")" LEARNING
read -p "$(echo -e "${C}Current focus/project: ${N}")" FOCUS
echo ""

echo -e "${Y}Communication Preferences${N}"
echo "  Enter preferences one per line. Empty line to finish."
echo "  Examples: 'Always include critical perspective', 'Reply in Korean + English'"
COMM_PREFS=""
while true; do
    read -p "  - " line
    [ -z "$line" ] && break
    COMM_PREFS="${COMM_PREFS}\n- ${line}"
done
echo ""

echo -e "${Y}What do you value?${N}"
echo "  Enter values one per line. Empty line to finish."
echo "  Examples: 'Honest feedback over polite agreement', 'Show tradeoffs'"
VALUES=""
while true; do
    read -p "  - " line
    [ -z "$line" ] && break
    VALUES="${VALUES}\n- ${line}"
done
echo ""

echo -e "${Y}Pet peeves?${N}"
echo "  Enter pet peeves one per line. Empty line to finish."
echo "  Examples: 'Don't say Great question!', 'No unnecessary hedging'"
PEEVES=""
while true; do
    read -p "  - " line
    [ -z "$line" ] && break
    PEEVES="${PEEVES}\n- ${line}"
done

# --- Write USER.md ---
cat > "$USER_MD" << EOF
# USER.md - About the Owner

## Profile

- **Name**: ${USER_NAME}
- **Call me**: ${CALL_ME}
- **Timezone**: ${TZ_INPUT}
- **Language**: ${LANG_INPUT}

## Skills & Context

- **Strong at**: ${STRONG_AT}
- **Learning**: ${LEARNING}
- **Current focus**: ${FOCUS}

## Communication Preferences

$(echo -e "$COMM_PREFS")

## What I Value

$(echo -e "$VALUES")

## Pet Peeves

$(echo -e "$PEEVES")

---

_This is your personal context. Every agent in every session reads this._
EOF

echo ""
echo -e "${G}✅ USER.md written to ${USER_MD}${N}"
echo ""

# --- Also apply to agent workspaces if dev-team ---
AGENT_WORKSPACES=$(find "$PROFILE_DIR" -maxdepth 1 -type d -name "workspace-*" 2>/dev/null)
if [ -n "$AGENT_WORKSPACES" ]; then
    echo -e "${G}📋 Copying USER.md to agent workspaces...${N}"
    for ws in $AGENT_WORKSPACES; do
        cp "$USER_MD" "$ws/USER.md"
        echo "   → $(basename $ws)/"
    done
fi

echo ""
echo -e "${G}Done! Start your gateway (use env vars, not --profile flag):${N}"
echo "   export OPENCLAW_PROFILE=\"${PROFILE}\" && openclaw gateway --port \$(jq -r '.gateway.port' ${PROFILE_DIR}/openclaw.json)"
