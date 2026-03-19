#!/usr/bin/env bash
# =============================================================================
# Dotfiles install — run on any personal machine to get the full environment
# Usage: bash install.sh
# =============================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
success() { echo -e "${GREEN}[done]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
backup()  { [[ -f "$1" ]] && cp "$1" "$1.bak.$(date +%Y%m%d%H%M%S)" && warn "Backed up $1"; }

# zsh
backup "$HOME/.zshrc"
cp "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
success ".zshrc installed"

# iTerm2
if [[ -f "$DOTFILES/iterm2/com.googlecode.iterm2.plist" ]]; then
    cp "$DOTFILES/iterm2/com.googlecode.iterm2.plist" "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    success "iTerm2 preferences installed (restart iTerm2)"
fi

# git
if [[ -f "$DOTFILES/git/.gitconfig" ]]; then
    backup "$HOME/.gitconfig"
    cp "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
    success ".gitconfig installed"
fi

echo ""
echo "Done. Open a new terminal to load the new shell config."
