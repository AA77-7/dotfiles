#!/usr/bin/env bash
# =============================================================================
# Bootstrap — run this FIRST on a brand new Mac with nothing installed.
# dotfiles repo is PUBLIC so this can be curled directly.
#
# One command — paste into Terminal on the new Mac:
#
#   curl -fsSL https://raw.githubusercontent.com/AA77-7/dotfiles/main/bootstrap.sh | bash
#
# OR if you have a GitHub token, you can curl it:
#   curl -fsSL -H "Authorization: token YOUR_GITHUB_TOKEN" \
#     https://raw.githubusercontent.com/AA77-7/polymarket_bot/main/deploy/bootstrap.sh | bash
# =============================================================================
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "\n${BLUE}[bootstrap]${NC} $*"; }
success() { echo -e "${GREEN}  ✓${NC} $*"; }
warn()    { echo -e "${YELLOW}  !${NC} $*"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Mac Mini Bootstrap               ║${NC}"
echo -e "${BLUE}║  Step 0: Get git + Homebrew onto macOS   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# 1. Xcode Command Line Tools (includes git, make, clang)
# =============================================================================
info "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
    success "Already installed at $(xcode-select -p)"
else
    echo "  Installing Xcode Command Line Tools..."
    echo "  A dialog box will appear — click 'Install' and wait (~5 minutes)."
    echo ""

    # Trigger the GUI installer
    xcode-select --install 2>/dev/null

    # Wait for the user to complete the GUI installation
    echo "  Waiting for installation to complete..."
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
    # Extra settle time for the install to fully finalize
    sleep 3
    success "Xcode Command Line Tools installed"
fi

# Accept the Xcode license silently
sudo xcodebuild -license accept 2>/dev/null || true

# =============================================================================
# 2. Homebrew
# =============================================================================
info "Homebrew"

if command -v brew &>/dev/null; then
    success "Already installed: $(brew --version | head -1)"
else
    echo "  Installing Homebrew (will ask for your password)..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Put brew on PATH for this session
if [[ -f /opt/homebrew/bin/brew ]]; then
    # Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Persist to .zprofile for future sessions
    BREW_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
elif [[ -f /usr/local/bin/brew ]]; then
    # Intel
    eval "$(/usr/local/bin/brew shellenv)"
    BREW_LINE='eval "$(/usr/local/bin/brew shellenv)"'
fi

if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    echo "" >> "$HOME/.zprofile"
    echo "# Homebrew" >> "$HOME/.zprofile"
    echo "$BREW_LINE" >> "$HOME/.zprofile"
fi

command -v brew &>/dev/null || { echo "Homebrew not on PATH after install — restart Terminal and re-run."; exit 1; }
success "Homebrew $(brew --version | head -1) at $(which brew)"

# =============================================================================
# 3. Git (brew version — newer than Xcode's bundled git)
# =============================================================================
info "Git"
brew install git --quiet 2>/dev/null || true
success "git $(git --version | cut -d' ' -f3)"

# =============================================================================
# 4. Clone dotfiles (public) and run full setup
# =============================================================================
info "Cloning dotfiles and launching setup..."

DOTFILES_DIR="$HOME/Documents/code/dotfiles"
mkdir -p "$HOME/Documents/code"

if [[ -d "$DOTFILES_DIR" ]]; then
    git -C "$DOTFILES_DIR" pull --quiet
else
    git clone https://github.com/AA77-7/dotfiles.git "$DOTFILES_DIR"
fi

success "dotfiles ready at $DOTFILES_DIR"
echo ""
echo -e "${GREEN}Bootstrap complete. Launching full setup...${NC}"
echo ""

bash "$DOTFILES_DIR/setup.sh"
