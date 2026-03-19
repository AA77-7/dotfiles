# Performance tracking
ZSHRC_START=$(($(date +%s%N)/1000000))

# ============================================================================
# Environment Variables
# ============================================================================

# API keys — loaded from .env in polymarket_bot repo (set by setup.sh)
[ -f ~/.secrets ] && source ~/.secrets

# Personal project directories
export CODE_DIR="$HOME/Documents/code"

# History
export HISTSIZE=50000
export SAVEHIST=50000
export HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Silence macOS zsh deprecation warning
export BASH_SILENCE_DEPRECATION_WARNING=1

# AWS
export AWS_SHARED_CREDENTIALS_FILE=${AWS_SHARED_CREDENTIALS_FILE:-~/.aws/credentials}

# ============================================================================
# Path
# ============================================================================

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.poetry/bin:/usr/local/bin:$PATH"

# Homebrew (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

# ============================================================================
# Oh-My-Zsh
# ============================================================================

if [ -d "$HOME/.oh-my-zsh" ]; then
    export ZSH="$HOME/.oh-my-zsh"
    ZSH_THEME="robbyrussell"

    zstyle ':omz:update' mode reminder
    zstyle ':omz:update' frequency 13

    DISABLE_MAGIC_FUNCTIONS="true"

    plugins=(
        git
        history-substring-search
        zsh-autosuggestions
        zsh-syntax-highlighting
    )

    source $ZSH/oh-my-zsh.sh
else
    echo "Oh-My-Zsh not installed. Run setup.sh to install."
fi

# ============================================================================
# General Aliases
# ============================================================================

alias ll='ls -la'
alias la='ls -la'

# Better ls with eza if available
if command -v eza &>/dev/null; then
    alias ls='eza --icons'
    alias ll='eza -la --icons --git'
    alias lt='eza --tree --icons -L 2'
fi

# Better cat with bat if available
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# Navigation
alias cdc='cd $CODE_DIR'
alias cdp='cd $CODE_DIR/polymarket_bot'
alias cdh='cd $CODE_DIR/health-platform'
alias cds='cd $CODE_DIR/schoolguard'
alias cdw='cd $CODE_DIR/shamsalassil-website'
alias cdg='cd $HOME/Documents/gradschool'

# Git shortcuts
alias gs='git status'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'

# Bot
alias bot='cd $CODE_DIR/polymarket_bot && tail -f logs/cron.log'
alias botrun='cd $CODE_DIR/polymarket_bot && BOT_MODE=ULTRA .venv/bin/python main.py'

# ============================================================================
# Docker
# ============================================================================

alias dk='docker'
alias dkc='docker compose'
alias dockerclean='docker ps -q -a -f status=exited | xargs docker rm -v && docker rmi -f $(docker images -f "dangling=true" -q) 2>/dev/null || true'

# Quick exec into a running container by name pattern
dex() {
    local container=$(docker ps --format '{{.Names}}' | grep -i "$1" | head -1)
    if [ -n "$container" ]; then
        echo "Connecting to: $container"
        docker exec -it "$container" bash
    else
        echo "No running container matching '$1'"
        docker ps --format "  - {{.Names}}"
    fi
}

# ============================================================================
# AWS
# ============================================================================

awsp() {
    if [ -z "$1" ]; then
        echo "Current profile: ${AWS_PROFILE:-default}"
        grep '^\[' "${AWS_SHARED_CREDENTIALS_FILE}" 2>/dev/null
    else
        export AWS_PROFILE="$1"
        echo "AWS_PROFILE=$1"
    fi
}

# ============================================================================
# Python / pyenv
# ============================================================================

if command -v pyenv &>/dev/null; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
fi

# ============================================================================
# Utility Functions
# ============================================================================

# Set iTerm2 tab title
title() { echo -ne "\033]0;$*\007"; }

# Quick port check
port() { lsof -i ":${1}" | grep LISTEN; }

# Make a dir and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# ============================================================================
# bun completions
# ============================================================================

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ============================================================================
# SCM Breeze (if installed)
# ============================================================================

[ -s "$HOME/.scm_breeze/scm_breeze.sh" ] && source "$HOME/.scm_breeze/scm_breeze.sh"

# ============================================================================
# OpenClaw
# ============================================================================

if command -v openclaw &>/dev/null; then
    [ -s "$HOME/.openclaw/completions/openclaw.zsh" ] && source "$HOME/.openclaw/completions/openclaw.zsh"
    alias ocgs='openclaw --profile gradschool'
    alias ocgs-browser='openclaw --profile gradschool browser --browser-profile gradschool'
    ocgs-ask() { openclaw --profile gradschool agent --agent main --message "$*"; }
fi

# ============================================================================
# Performance Report
# ============================================================================

ZSHRC_END=$(($(date +%s%N)/1000000))
echo "==> .zshrc loaded in $((ZSHRC_END - ZSHRC_START))ms <=="

# Default working directory
cd "$CODE_DIR" 2>/dev/null || true
