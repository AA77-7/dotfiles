# CLAUDE.md — Dotfiles

Personal shell and app configuration.

## Install

```bash
git clone https://github.com/AA77-7/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

## Contents

| Path | What it does |
|------|-------------|
| `zsh/.zshrc` | Personal zsh config — oh-my-zsh, aliases, pyenv, Docker, AWS, bun |
| `iterm2/com.googlecode.iterm2.plist` | Full iTerm2 preferences (profiles, colors, keybindings) |
| `git/.gitconfig` | Global git config |
| `install.sh` | Copies everything into place, backs up existing files |

## Notes

- Stripped of all IMC/work config (LiteLLM, Kerberos, Hadoop, IMC SSH)
- Plugins needed: `zsh-autosuggestions`, `zsh-syntax-highlighting` (setup.sh installs these)
- API keys live in `~/.secrets`, sourced by `.zshrc` — never in this repo
