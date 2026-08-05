# Dotfiles

Public, credential-free configuration for a macOS development laptop. Private
material and machine-local state are deliberately excluded; see `setup.md` for
the corresponding setup steps.

## Layout

| Repository path | Install location |
| --- | --- |
| `zshrc`, `zprofile`, `profile` | `~/.zshrc`, `~/.zprofile`, `~/.profile` |
| `vimrc`, `vim/templates/` | `~/.vimrc`, `~/.vim/templates/` |
| `gitconfig` | `~/.gitconfig` |
| `config/*` | Matching path below `~/.config/` unless noted otherwise |
| `config/docker/daemon.json` | `~/.docker/daemon.json` |
| `config/gnupg/common.conf` | `~/.gnupg/common.conf` |
| `config/ssh/config` | `~/.ssh/config` |
| `config/vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` |
| `agents/AGENTS.md` | `~/.agents/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` |
| `agents/claude/settings.json` | `~/.claude/settings.json` |
| `agents/codex/config.toml` | Portable base for `~/.codex/config.toml` |
| `agents/skills/` | `~/.agents/skills/` |
| `agents/skill-lock.json` | `~/.agents/.skill-lock.json` |

The Neovim configuration remains staged under `config/nvim-staged/`; it is not
the active editor configuration yet.

## Safety

This repository uses an allowlist approach: only intentionally selected files
are tracked. Do not copy whole application directories into it. Run a secret
scanner over the working tree and Git history before publishing changes.
