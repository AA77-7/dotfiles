#!/usr/bin/env bash
# =============================================================================
# Personal Mac Mini — Full Setup Script
# Repo: AA77-7/dotfiles (public — machine setup, not project-specific)
# Tested on macOS Sequoia (Apple Silicon). Run once on a fresh machine.
#
# One command on a brand new Mac (paste into Terminal):
#   curl -fsSL https://raw.githubusercontent.com/AA77-7/dotfiles/main/bootstrap.sh | bash
#
# Or after bootstrap:
#   bash ~/Documents/code/dotfiles/setup.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "\n${BLUE}[setup]${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  !${NC} $*"; }
die()     { echo -e "${RED}  ✗ ERROR:${NC} $*" >&2; exit 1; }

CODE_DIR="$HOME/Documents/code"
BOT_DIR="$CODE_DIR/polymarket_bot"
PLIST_DIR="$HOME/Library/LaunchAgents"
LOCAL_IP="unknown"   # set in step 6; default here avoids set -u crash

# Create critical directories early — launchd plists reference these paths
# before step 13 would otherwise create them
mkdir -p "$BOT_DIR/data" "$BOT_DIR/logs" "$PLIST_DIR" "$CODE_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Personal Mac Mini — Full Setup       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# STEP 1 — Xcode Command Line Tools
# =============================================================================
info "Step 1/16 — Xcode Command Line Tools"
if ! xcode-select -p &>/dev/null; then
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "  A dialog appeared — click Install, wait ~5 min, then re-run this script."
    exit 0
fi
success "$(xcode-select -p)"
sudo xcodebuild -license accept 2>/dev/null || true

# =============================================================================
# STEP 2 — Rosetta 2 (Apple Silicon only)
# =============================================================================
info "Step 2/16 — Rosetta 2"
if [[ "$(uname -m)" == "arm64" ]]; then
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        success "Already running"
    else
        softwareupdate --install-rosetta --agree-to-license 2>/dev/null \
            && success "Installed" || warn "Failed — continuing anyway"
    fi
else
    success "Intel Mac — not needed"
fi

# =============================================================================
# STEP 3 — Homebrew
# =============================================================================
info "Step 3/16 — Homebrew"
if ! command -v brew &>/dev/null; then
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH now and in future shells
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || \
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

command -v brew &>/dev/null || die "brew not found after install — restart Terminal and re-run"
brew update --quiet 2>/dev/null || true
success "$(brew --version | head -1)"

# =============================================================================
# STEP 4 — System packages
# =============================================================================
info "Step 4/16 — System packages"

for pkg in python@3.12 python@3.11 node git sqlite gh bat eza wget curl jq htop lftp uv colima docker docker-compose; do
    brew install "$pkg" 2>/dev/null || brew upgrade "$pkg" 2>/dev/null \
        && success "$pkg" \
        || warn "$pkg install failed — run manually: brew install $pkg"
done

for cask in iterm2 tailscale visual-studio-code; do
    brew install --cask "$cask" 2>/dev/null \
        && success "$cask" \
        || warn "$cask install failed — run manually: brew install --cask $cask"
done

# Ensure python3.12 is the default python3
brew link python@3.12 --force --overwrite 2>/dev/null || true

# Node 22+ required for OpenClaw
NODE_MAJOR="$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)"
NODE_MAJOR="${NODE_MAJOR:-0}"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
    warn "Node $NODE_MAJOR < 22 — upgrading..."
    brew install node@22 --quiet 2>/dev/null || true
    brew link node@22 --force --overwrite 2>/dev/null || true
fi
success "Node $(node --version)"

# =============================================================================
# STEP 5 — Git global config
# =============================================================================
info "Step 5/16 — Git configuration"
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
    echo ""
    echo -n "  Your full name for git commits: "
    read -r GIT_NAME
    echo -n "  Your email for git commits:     "
    read -r GIT_EMAIL
    git config --global user.name  "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input
git config --global fetch.prune true
success "$(git config --global user.name) <$(git config --global user.email)>"

# =============================================================================
# STEP 6 — SSH key + GitHub access
# =============================================================================
info "Step 6/16 — SSH key"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    ssh-keygen -t ed25519 -C "$(git config --global user.email 2>/dev/null)-mac-mini" \
        -f "$HOME/.ssh/id_ed25519" -N ""
fi

# Add key to macOS keychain + SSH agent
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null \
    || ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

# Harden SSH client config
SSH_CONF="$HOME/.ssh/config"
if ! grep -q "ServerAliveInterval" "$SSH_CONF" 2>/dev/null; then
    cat >> "$SSH_CONF" << 'EOF'

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOF
    chmod 600 "$SSH_CONF"
fi

# Enable Remote Login (SSH server)
sudo systemsetup -setremotelogin on 2>/dev/null \
    && success "Remote Login enabled" \
    || warn "Enable manually: System Settings > General > Sharing > Remote Login"

LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 'unknown')"

echo ""
echo -e "  ${YELLOW}ACTION REQUIRED — do this now before pressing Enter:${NC}"
echo "  1. Go to github.com → Settings → SSH and GPG keys → New SSH key"
echo "  2. Paste this key:"
echo ""
cat "$HOME/.ssh/id_ed25519.pub"
echo ""
# Verify it actually works before proceeding
while true; do
    echo -n "  Press Enter to test GitHub SSH access... "
    read -r _
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        success "GitHub SSH authenticated"
        break
    else
        warn "Not authenticated yet — add the key to GitHub and try again"
    fi
done

# =============================================================================
# STEP 7 — Oh-My-Zsh + plugins  (before dotfiles so zshrc works on first open)
# =============================================================================
info "Step 7/16 — Oh-My-Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions" --quiet
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" --quiet
success "oh-my-zsh + plugins"

# =============================================================================
# STEP 8 — Dotfiles  (uses SSH, so must come after step 6)
# =============================================================================
info "Step 8/16 — Dotfiles"
mkdir -p "$CODE_DIR"
if [[ ! -d "$CODE_DIR/dotfiles" ]]; then
    git clone git@github.com:AA77-7/dotfiles.git "$CODE_DIR/dotfiles"
fi
[[ -f "$HOME/.zshrc" ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
bash "$CODE_DIR/dotfiles/install.sh"
success ".zshrc + iTerm2 prefs + git aliases installed"

# =============================================================================
# STEP 9 — API keys → ~/.secrets
# =============================================================================
info "Step 9/16 — API keys"
SECRETS_FILE="$HOME/.secrets"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo ""
    echo "  Enter your keys. Press Enter to skip any you don't have yet."
    echo ""
    echo -n "  Anthropic API key (personal — console.anthropic.com): "; read -r ANTHROPIC_API_KEY
    echo -n "  Discord webhook URL:                                   "; read -r DISCORD_WEBHOOK
    echo -n "  OpenAI API key:                                        "; read -r OPENAI_API_KEY
    echo -n "  Google API key:                                        "; read -r GOOGLE_API_KEY
    echo -n "  Whoop access token:                                    "; read -r WHOOP_ACCESS_TOKEN
    echo -n "  Oura access token:                                     "; read -r OURA_ACCESS_TOKEN
    echo -n "  GoDaddy FTP host (e.g. ftp.shamsalassil.info):         "; read -r FTP_HOST
    echo -n "  GoDaddy FTP username:                                  "; read -r FTP_USER
    echo -n "  GoDaddy FTP password:                                  "; read -r -s FTP_PASS; echo

    cat > "$SECRETS_FILE" << EOF
# Personal secrets — chmod 600, never commit
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"
export DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
export BOT_MODE=ULTRA
export WHOOP_ACCESS_TOKEN="${WHOOP_ACCESS_TOKEN:-}"
export OURA_ACCESS_TOKEN="${OURA_ACCESS_TOKEN:-}"
export FTP_HOST="${FTP_HOST:-}"
export FTP_USER="${FTP_USER:-}"
export FTP_PASS="${FTP_PASS:-}"
export FTP_REMOTE_DIR=/public_html
EOF
    chmod 600 "$SECRETS_FILE"
    success "~/.secrets created"
else
    warn "~/.secrets exists — skipping (edit manually if needed)"
fi

set -o allexport; source "$SECRETS_FILE"; set +o allexport

# =============================================================================
# STEP 10 — Clone personal repos  (SSH URLs — works because key is in agent)
# =============================================================================
info "Step 10/16 — Clone repos"

clone_or_pull() {
    local repo="$1" dir="$2"
    if [[ ! -d "$dir" ]]; then
        git clone "git@github.com:AA77-7/${repo}.git" "$dir" && success "cloned $repo"
    else
        git -C "$dir" pull --quiet && success "$repo up to date"
    fi
}

clone_or_pull "polymarket_bot"       "$CODE_DIR/polymarket_bot"
clone_or_pull "health-platform"      "$CODE_DIR/health-platform"
clone_or_pull "schoolguard"          "$CODE_DIR/schoolguard"
clone_or_pull "shamsalassil-website" "$CODE_DIR/shamsalassil-website"
clone_or_pull "gradschool"           "$HOME/Documents/gradschool"

# =============================================================================
# STEP 11 — AI tools: Claude Code, Gemini, Codex, OpenClaw
# =============================================================================
info "Step 11/16 — AI coding tools"

npm_install() {
    local pkg="$1" bin="$2"
    if ! command -v "$bin" &>/dev/null; then
        npm install -g "$pkg" --silent 2>/dev/null && success "$bin installed" || warn "$bin install failed"
    else
        success "$bin already installed"
    fi
}

npm_install "@anthropic-ai/claude-code" "claude"
npm_install "@google/gemini-cli"        "gemini"
npm_install "@openai/codex"             "codex"
npm_install "openclaw"                  "openclaw"

# Seed OpenClaw workspace from repo
if command -v openclaw &>/dev/null && [[ ! -d "$HOME/.openclaw/workspace" ]]; then
    mkdir -p "$HOME/.openclaw/workspace"
    if [[ ! -d "$CODE_DIR/openclaw-workspace" ]]; then
        git clone git@github.com:AA77-7/openclaw-workspace.git \
            "$CODE_DIR/openclaw-workspace" 2>/dev/null || true
    fi
    [[ -d "$CODE_DIR/openclaw-workspace" ]] && \
        cp -r "$CODE_DIR/openclaw-workspace/." "$HOME/.openclaw/workspace/" 2>/dev/null && \
        success "OpenClaw workspace seeded" || true
fi

# =============================================================================
# STEP 12 — Docker (Colima) + health platform jobs
# =============================================================================
info "Step 12/16 — Docker + health platform"

# Start Colima
if ! colima status 2>/dev/null | grep -q "Running"; then
    colima start --cpu 2 --memory 4 --disk 20 --runtime docker 2>/dev/null \
        && success "Colima started" || warn "colima start failed — run 'colima start' manually"
else
    success "Colima already running"
fi

# Boot agent for Colima
COLIMA_PLIST="$PLIST_DIR/com.colima.plist"
mkdir -p "$PLIST_DIR"
if [[ ! -f "$COLIMA_PLIST" ]]; then
    COLIMA_BIN="$(which colima)"
    cat > "$COLIMA_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.colima</string>
    <key>ProgramArguments</key><array>
        <string>${COLIMA_BIN}</string><string>start</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
    <key>StandardOutPath</key><string>$BOT_DIR/logs/colima.log</string>
    <key>StandardErrorPath</key><string>$BOT_DIR/logs/colima.err.log</string>
</dict></plist>
EOF
    launchctl load "$COLIMA_PLIST" 2>/dev/null || true
    success "Colima boot agent installed"
fi

# Start health platform DB + Redis (needed for daily sync job)
HP_COMPOSE="$CODE_DIR/health-platform/docker-compose.yml"
if [[ -f "$HP_COMPOSE" ]]; then
    docker-compose -f "$HP_COMPOSE" up -d db redis 2>/dev/null \
        && success "Health platform DB + Redis started" \
        || warn "docker-compose up failed — run manually: docker-compose -f $HP_COMPOSE up -d db redis"
fi

# health-platform .env
HP_DIR="$CODE_DIR/health-platform"
HP_ENV="$HP_DIR/.env"
if [[ -f "$HP_DIR/.env.example" && ! -f "$HP_ENV" ]]; then
    cp "$HP_DIR/.env.example" "$HP_ENV"
    sed -i '' "s|^WHOOP_ACCESS_TOKEN=.*|WHOOP_ACCESS_TOKEN=${WHOOP_ACCESS_TOKEN:-}|" "$HP_ENV"
    sed -i '' "s|^OURA_ACCESS_TOKEN=.*|OURA_ACCESS_TOKEN=${OURA_ACCESS_TOKEN:-}|" "$HP_ENV"
    success "health-platform .env created"
fi

# uv is installed by brew above; confirm path
UV_BIN="$(which uv 2>/dev/null || echo '/opt/homebrew/bin/uv')"

# Daily health sync at 3:15am
HP_SYNC_PLIST="$PLIST_DIR/com.health-platform-sync.plist"
if [[ ! -f "$HP_SYNC_PLIST" ]]; then
    cat > "$HP_SYNC_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>com.health-platform-sync</string>
    <key>ProgramArguments</key><array>
        <string>${UV_BIN}</string><string>run</string>
        <string>python</string><string>scripts/ingest_all.py</string>
    </array>
    <key>WorkingDirectory</key><string>${HP_DIR}</string>
    <key>StartCalendarInterval</key><dict>
        <key>Hour</key><integer>3</integer><key>Minute</key><integer>15</integer>
    </dict>
    <key>EnvironmentVariables</key><dict>
        <key>WHOOP_ACCESS_TOKEN</key><string>${WHOOP_ACCESS_TOKEN:-}</string>
        <key>OURA_ACCESS_TOKEN</key><string>${OURA_ACCESS_TOKEN:-}</string>
    </dict>
    <key>StandardOutPath</key><string>$BOT_DIR/logs/health-sync.log</string>
    <key>StandardErrorPath</key><string>$BOT_DIR/logs/health-sync.err.log</string>
    <key>RunAtLoad</key><false/>
</dict></plist>
EOF
    launchctl load "$HP_SYNC_PLIST" 2>/dev/null || true
    success "Health sync scheduled daily at 3:15am"
fi

# =============================================================================
# STEP 13 — Polymarket bot venv + launchd
# =============================================================================
info "Step 13/16 — Polymarket bot"
# BOT_DIR already set above
VENV_PATH="$BOT_DIR/.venv"

python3.12 -m venv "$VENV_PATH"
"$VENV_PATH/bin/pip" install --upgrade pip --quiet
"$VENV_PATH/bin/pip" install -r "$BOT_DIR/requirements.txt" --quiet
# dirs already created at top of script; ensure they exist post-clone too
mkdir -p "$BOT_DIR/data" "$BOT_DIR/logs"

BOT_ENV="$BOT_DIR/.env"
if [[ ! -f "$BOT_ENV" ]]; then
    cp "$BOT_DIR/.env.example" "$BOT_ENV"
    sed -i '' "s|^DISCORD_WEBHOOK=.*|DISCORD_WEBHOOK=${DISCORD_WEBHOOK:-}|"    "$BOT_ENV"
    sed -i '' "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}|" "$BOT_ENV"
fi

install_plist() {
    local name="$1"
    local src="$BOT_DIR/deploy/launchd/${name}.plist"
    local dst="$PLIST_DIR/${name}.plist"
    sed \
        -e "s|REPLACE_WITH_REPO_PATH|$BOT_DIR|g" \
        -e "s|REPLACE_WITH_VENV_PYTHON|$VENV_PATH/bin/python|g" \
        -e "s|REPLACE_WITH_DISCORD_WEBHOOK|${DISCORD_WEBHOOK:-}|g" \
        -e "s|REPLACE_WITH_ANTHROPIC_KEY|${ANTHROPIC_API_KEY:-}|g" \
        "$src" > "$dst"
    launchctl unload "$dst" 2>/dev/null || true
    launchctl load  "$dst"
    success "$name loaded"
}

chmod +x "$BOT_DIR/deploy/scripts/health_check.sh"
install_plist "com.polymarket-bot"
install_plist "com.polymarket-bot-health"

# =============================================================================
# STEP 14 — Tailscale
# =============================================================================
info "Step 14/16 — Tailscale"
if [[ -d "/Applications/Tailscale.app" ]]; then
    success "Tailscale installed — open the app and sign in to enable remote SSH"
else
    warn "Not found — install from tailscale.com/download/mac"
fi

# =============================================================================
# STEP 15 — Power settings (always on)
# =============================================================================
info "Step 15/16 — Power settings"
sudo pmset -a sleep 0        && success "Machine sleep disabled"        || warn "pmset sleep failed"
sudo pmset -a displaysleep 30 && success "Display sleep: 30 min"        || warn "pmset displaysleep failed"
sudo pmset -a disksleep 0    && success "Disk sleep disabled"           || warn "pmset disksleep failed"
sudo pmset -a womp 1         && success "Wake on network access: on"    || warn "pmset womp failed"

# =============================================================================
# STEP 16 — Bot smoke test
# =============================================================================
info "Step 16/16 — Bot smoke test"
cd "$BOT_DIR"
BOT_MODE=ULTRA "$VENV_PATH/bin/python" main.py \
    && success "Bot ran successfully" \
    || warn "Bot had errors — check $BOT_DIR/logs/cron.log"

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Setup complete!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Machine:    $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "  Local SSH:  ssh $(whoami)@${LOCAL_IP}"
echo "  Remote SSH: open Tailscale.app → sign in → ssh $(whoami)@<100.x.x.x>"
echo ""
echo "  Three things to do now:"
echo "    1. Open Tailscale.app → sign in with personal account → note your 100.x.x.x IP"
echo "    2. Run: claude        → sign in with PERSONAL Anthropic account"
echo "    3. Run: openclaw      → configure your workspace"
echo ""
echo "  ⚠  MacBook: disable the RESEARCH cron on your laptop now that Mac Mini is running:"
echo "     crontab -e   →   comment out the polymarket_bot line"
echo ""
echo "  Logs:  tail -f $BOT_DIR/logs/cron.log"
echo "  DB:    sqlite3 $BOT_DIR/data/polymarket.db"
echo ""
echo "  AI:    claude | gemini | codex | openclaw"
