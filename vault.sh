#!/bin/bash
# ============================================
# Secret Vault Manager (sops + age)
# ============================================
# Usage:
#   ./vault.sh init          # Generate age key (first time)
#   ./vault.sh encrypt       # .env → .env.enc
#   ./vault.sh decrypt       # .env.enc → .env
#   ./vault.sh edit          # Edit encrypted secrets in $EDITOR
#   ./vault.sh show          # Show decrypted secrets
#   ./vault.sh import <file> # Encrypt an external .env file

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

get_pubkey() {
    grep "public key:" "$KEY_FILE" 2>/dev/null | awk '{print $NF}'
}

case "${1:-help}" in
    init)
        if [ -f "$KEY_FILE" ]; then
            echo "⚠️  Key already exists at $KEY_FILE"
            echo "   Public key: $(get_pubkey)"
        else
            mkdir -p "$(dirname "$KEY_FILE")"
            age-keygen -o "$KEY_FILE" 2>&1
            chmod 600 "$KEY_FILE"
            echo ""
            echo "✅ Key generated!"
            echo "   Public key: $(get_pubkey)"
            echo "   Key file: $KEY_FILE"
            echo ""
            echo "⚠️  BACK UP $KEY_FILE — lose it and you lose access to all secrets!"
        fi

        # Update .sops.yaml
        PUB=$(get_pubkey)
        cat > "$SCRIPT_DIR/.sops.yaml" << EOF
creation_rules:
  - path_regex: \.env\.enc$
    age: $PUB
EOF
        echo "   Updated .sops.yaml with public key"
        ;;

    encrypt)
        PUB=$(get_pubkey)
        if [ -z "$PUB" ]; then
            echo "❌ No age key found. Run: ./vault.sh init"
            exit 1
        fi
        INPUT="${2:-$SCRIPT_DIR/.env}"
        if [ ! -f "$INPUT" ]; then
            echo "❌ $INPUT not found"
            exit 1
        fi
        sops --encrypt --age "$PUB" --input-type dotenv --output-type dotenv "$INPUT" > "$SCRIPT_DIR/.env.enc"
        echo "✅ Encrypted → .env.enc"
        echo "   You can now safely commit .env.enc to git"
        echo "   Delete .env if you want: rm .env"
        ;;

    decrypt)
        if [ ! -f "$SCRIPT_DIR/.env.enc" ]; then
            echo "❌ .env.enc not found"
            exit 1
        fi
        sops --decrypt --input-type dotenv --output-type dotenv "$SCRIPT_DIR/.env.enc" > "$SCRIPT_DIR/.env"
        chmod 600 "$SCRIPT_DIR/.env"
        echo "✅ Decrypted → .env"
        ;;

    edit)
        if [ ! -f "$SCRIPT_DIR/.env.enc" ]; then
            echo "❌ .env.enc not found. Run: ./vault.sh encrypt"
            exit 1
        fi
        sops --input-type dotenv --output-type dotenv "$SCRIPT_DIR/.env.enc"
        ;;

    show)
        if [ ! -f "$SCRIPT_DIR/.env.enc" ]; then
            echo "❌ .env.enc not found"
            exit 1
        fi
        sops --decrypt --input-type dotenv --output-type dotenv "$SCRIPT_DIR/.env.enc"
        ;;

    import)
        PUB=$(get_pubkey)
        INPUT="${2}"
        if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
            echo "Usage: ./vault.sh import <path-to-.env>"
            exit 1
        fi
        sops --encrypt --age "$PUB" --input-type dotenv --output-type dotenv "$INPUT" > "$SCRIPT_DIR/.env.enc"
        echo "✅ Imported and encrypted → .env.enc"
        ;;

    help|*)
        echo "🔐 Secret Vault Manager (sops + age)"
        echo ""
        echo "Commands:"
        echo "  init     Generate age key pair (first time only)"
        echo "  encrypt  Encrypt .env → .env.enc"
        echo "  decrypt  Decrypt .env.enc → .env"
        echo "  edit     Edit encrypted secrets in \$EDITOR"
        echo "  show     Display decrypted secrets"
        echo "  import   Encrypt an external .env file"
        echo ""
        echo "Workflow:"
        echo "  1. ./vault.sh init"
        echo "  2. Fill in .env from .env.example"
        echo "  3. ./vault.sh encrypt"
        echo "  4. git add .env.enc .sops.yaml"
        echo "  5. ./setup.sh dev  ← auto-decrypts from .env.enc"
        ;;
esac
