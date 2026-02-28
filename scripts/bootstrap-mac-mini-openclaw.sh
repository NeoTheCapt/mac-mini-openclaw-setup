#!/usr/bin/env bash
set -euo pipefail

# Mac mini (macOS) bootstrap for OpenClaw + Telegram.
# - Primary model: openai/gpt-5.2
# - Fallback model: openrouter/minimax/minimax-m2.5
# - Channel: Telegram (DM policy: pairing)
#
# IMPORTANT:
#   - Do NOT commit secrets.
#   - Run this script as your normal macOS user (not root).
#
# Required env vars (export before running):
#   OPENAI_API_KEY="..."
#   OPENROUTER_API_KEY="..."          # required for fallback model
#   TELEGRAM_BOT_TOKEN="123:ABC..."   # BotFather token
#
# Optional:
#   OPENCLAW_GATEWAY_PORT=18789

say() { printf "\n==> %s\n" "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS (Darwin) only."

: "${OPENAI_API_KEY:?Missing env OPENAI_API_KEY}"
: "${OPENROUTER_API_KEY:?Missing env OPENROUTER_API_KEY}"
: "${TELEGRAM_BOT_TOKEN:?Missing env TELEGRAM_BOT_TOKEN}"

GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

say "1) Ensure Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  cat <<'EOF'
Xcode Command Line Tools are required (for native builds, git, etc.).

Run this, complete the GUI installer, then re-run this script:
  xcode-select --install
EOF
  exit 2
fi

say "2) Install Homebrew (if missing)"
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load brew into PATH for this shell
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)" || true
fi
command -v brew >/dev/null 2>&1 || die "brew not found after install"

say "3) Install Node.js 22+ (via Homebrew)"
if ! command -v node >/dev/null 2>&1; then
  brew install node@22
  brew link --force --overwrite node@22
else
  # Compare major version
  major="$(node -v | sed 's/^v//' | cut -d. -f1)"
  if [[ "$major" -lt 22 ]]; then
    brew install node@22
    brew link --force --overwrite node@22
  fi
fi

node -v
npm -v

say "4) Install OpenClaw CLI"
if ! command -v openclaw >/dev/null 2>&1; then
  npm install -g openclaw@latest
fi
openclaw --version

say "5) Write secrets for the daemon (launchd) into ~/.openclaw/.env"
mkdir -p "$HOME/.openclaw"
ENV_FILE="$HOME/.openclaw/.env"

# Append (idempotent-ish). You can manually edit later.
# We avoid printing secret values.
{
  echo "# OpenClaw daemon env (secrets). Do NOT commit/share."
  echo "OPENAI_API_KEY=${OPENAI_API_KEY}"
  echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}"
  echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

say "6) Run OpenClaw onboarding (non-interactive) + install daemon"
# Use secret ref mode so auth profiles store env refs, not plaintext keys.
# Non-interactive ref mode requires provider env vars in this process *and* daemon env.
openclaw onboard --non-interactive \
  --mode local \
  --flow quickstart \
  --auth-choice openai-api-key \
  --secret-input-mode ref \
  --gateway-port "$GATEWAY_PORT" \
  --gateway-bind loopback \
  --install-daemon \
  --daemon-runtime node \
  --skip-skills \
  --accept-risk

say "7) Set default model routing (primary + fallback)"
openclaw config set agents.defaults.model.primary '"openai/gpt-5.2"'
openclaw config set agents.defaults.model.fallbacks '["openrouter/minimax/minimax-m2.5"]'

say "8) Configure Telegram channel (default account)"
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.botToken "\"$TELEGRAM_BOT_TOKEN\""
openclaw config set channels.telegram.dmPolicy '"pairing"'

say "9) Restart gateway to apply config"
openclaw gateway restart

say "10) Quick checks"
openclaw gateway status || true
openclaw channels status || true
openclaw models status || true

echo ""
echo "NEXT STEPS (required for Telegram DM):"
echo "1) Open Telegram, DM your bot once (send 'hi')."
echo "2) Approve the pairing request on the Mac mini:"
echo "   openclaw pairing list telegram"
echo "   openclaw pairing approve telegram <CODE> --notify"
echo ""
echo "Optional: open the Control UI:"
echo "  openclaw dashboard"
