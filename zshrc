#!/usr/bin/env zsh
# ~/.zshrc - personal laptop
#
# Sourced by INTERACTIVE shells only. Anything that must also hold for scripts,
# `zsh -c`, CI or an agent's shell goes in this repo's `zshenv` (-> ~/.zshenv),
# which every zsh reads. The eza stdin/hang guard lives there for that reason.
#
# Machine-specific values do not belong in this file - it is public. The last
# line sources ~/.zshrc.local, which is the seam for them.

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================
# EXTENDED_GLOB is needed here, at the top, for the (#q...) glob qualifier in the
# cache check below. It used to be set ~200 lines further down, which silently
# made this whole fast path dead code. (The rest of the globbing options still
# live in the "Navigation / globbing" section.)
setopt EXTENDED_GLOB

# The dump path must be explicit. A bare `compinit` writes ~/.zcompdump, so the
# old `~/.zcompdump-*` glob could never match anything and every shell paid for a
# full completion-function scan. Versioning the dump by $ZSH_VERSION also avoids
# feeding a dump built by another zsh to a freshly upgraded one.
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
[[ -d "${ZSH_COMPDUMP:h}" ]] || mkdir -p "${ZSH_COMPDUMP:h}"

autoload -Uz compinit
# (#qN mh-24) = "exists, and modified less than 24 hours ago" -> trust the cache
# and skip the security/scan pass. Otherwise do the full compinit, which rewrites
# the dump and restarts the 24h clock.
if [[ -n $ZSH_COMPDUMP(#qNmh-24) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
  # compinit rewrites the dump only when the set of completion functions has
  # actually changed, so after a no-op check the mtime stays old and every later
  # shell would keep taking the slow path forever. Touch it to restart the clock.
  touch "$ZSH_COMPDUMP"
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Colored man pages
export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;36m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'
export LESS_TERMCAP_ue=$'\e[0m'

# ============================================================================
# PATH
# ============================================================================
# -U keeps $path (and therefore $PATH) unique: re-sourcing this file, nested
# shells, and tool hooks that prepend their own bin dir stop accumulating dupes.
typeset -U path PATH

export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Homebrew prefix, used below for brew-installed plugins and SDKs.
# `brew shellenv` normally exports it from ~/.zprofile, but this repo does not
# install a zprofile (see manifest.tsv), and /opt/homebrew/bin usually reaches
# PATH via /etc/paths.d/homebrew without it - so derive the prefix rather than
# assume the variable is set. Left empty when brew is not installed, which makes
# every consumer below fall through its guard.
if [[ -z "$HOMEBREW_PREFIX" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    export HOMEBREW_PREFIX=/opt/homebrew      # Apple Silicon
  elif [[ -x /usr/local/bin/brew ]]; then
    export HOMEBREW_PREFIX=/usr/local         # Intel
  fi
fi

# uv / pipx env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ============================================================================
# LAZY-LOADED TOOLS
# ============================================================================

# NVM - lazy load (saves ~300ms on startup).
# Opt-in on ~/.nvm actually existing. These node/npm/npx functions take priority
# over any binary of the same name, so on a machine managed by proto / mise /
# asdf they would shadow the real shims and try to source a nonexistent
# ~/.nvm/nvm.sh - i.e. `node` would appear installed and do nothing.
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  export NVM_DIR="$HOME/.nvm"
  _nvm_load() {
    unset -f nvm node npm npx
    \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  }
  nvm()  { _nvm_load; nvm "$@"; }
  node() { _nvm_load; node "$@"; }
  npm()  { _nvm_load; npm "$@"; }
  npx()  { _nvm_load; npx "$@"; }
fi

# Google Cloud SDK - lazy load. The function is harmless when the SDK is absent:
# both source lines are guarded, and the recursive call then reports
# "command not found: gcloud" exactly as an uninstalled tool should.
gcloud() {
  unset -f gcloud
  [ -f "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc" ] && . "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
  [ -f "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc" ] && . "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"
  gcloud "$@"
}

# ============================================================================
# FZF
# ============================================================================
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
# fd walks gitignore-aware and skips .git; fzf's built-in find walk crawls
# everything. Same $+commands test as the eza aliases below, and for the same
# reason. --hidden so dotfiles are findable; .git excluded explicitly because
# --hidden would otherwise surface it.
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
# Previews are opt-in per tool: an fzf preview command that is not installed
# leaves a blank pane with an error in it on every keystroke.
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:50%:wrap"
fi
if (( $+commands[eza] )); then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always -- {} | head -200'"
fi

# ============================================================================
# ZOXIDE (smart cd)
# ============================================================================
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# ============================================================================
# ALIASES
# ============================================================================
alias o='open'
alias clr='clear'
alias v='vim'
alias r='ranger'

# Modern CLI replacements.
# These shadow *core* commands, so they are defined only when the replacement is
# installed - an unconditional `alias ls=eza` breaks `ls` in every shell on a
# machine that has no eza, including during the bootstrap that would install it.
#
# The test is $+commands[...] (the external-command table) and NOT
# `command -v eza`: zshenv defines an eza() wrapper function, which would make
# `command -v eza` succeed even where the binary is missing.
#
# --icons=auto, spelled with its value: eza >= 0.23 gives --icons an OPTIONAL
# value, so a bare `--icons` swallows the next word and `eza --icons .` dies with
# "invalid value '.' for '--icons [<WHEN>]'". `auto` also does the right thing
# when output is piped (icons off).
if (( $+commands[eza] )); then
  alias ls='eza --icons=auto'
  alias ll='eza -la --icons=auto --git'
  alias la='eza -a --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
fi
(( $+commands[bat] )) && alias cat='bat --paging=never'

# Dev
# bash5: brew's modern bash, not the 3.2 in /bin. The -n test matters - with an
# empty prefix the path would collapse to /bin/bash, which exists and is 3.2.
[[ -n "$HOMEBREW_PREFIX" && -x "$HOMEBREW_PREFIX/bin/bash" ]] && alias bash5="$HOMEBREW_PREFIX/bin/bash"
alias fsz='du -sh '
alias ssh='ssh -o VisualHostKey=yes'
alias symcrypt='gpg -c --no-symkey-cache'

# yt-dlp has no self-update path when installed as a uv tool; remind, then run.
if (( $+commands[yt-dlp] )); then
  yt-dlp() {
    print -r -- 'Manual update: uv tool upgrade yt-dlp'
    command yt-dlp "$@"
  }
fi

# Mount the personal cloud drive. Needs rclone plus a remote named "onedrive"
# configured by `rclone config` (machine-local, never in this repo).
(( $+commands[rclone] )) && alias onedrive='rclone --vfs-cache-mode writes mount onedrive: ~/OneDrive &'

# ============================================================================
# FUNCTIONS
# ============================================================================

# Git branch switcher with fzf — reflog-ordered, falls back to local branches
git-switch() {
  local branches
  branches=$(git reflog show --pretty='%gs' --grep-reflog='checkout: ' \
    | awk '{print $NF}' \
    | awk '!seen[$0]++')
  branches="$branches"$'\n'"$(git branch --format='%(refname:short)')"
  branches=$(echo "$branches" | awk '!seen[$0]++')

  local branch
  branch=$(echo "$branches" | fzf \
    --height=80% --reverse \
    --prompt="Switch branch: " \
    --preview 'git log --oneline --decorate --color=always {} | head -30' \
    --preview-window=down:10:wrap)

  [[ -n "$branch" ]] || return 1
  git checkout "$branch"
}

# ============================================================================
# HISTORY
# ============================================================================
export HISTSIZE=1000000
export SAVEHIST=1000000
export HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt EXTENDED_HISTORY
setopt APPEND_HISTORY
# SHARE_HISTORY already implies INC_APPEND_HISTORY (it imports and appends as you
# go), so setting both is redundant.
setopt SHARE_HISTORY

# Navigation / globbing QoL  (EXTENDED_GLOB is set at the top of this file)
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# ============================================================================
# ENV
# ============================================================================
export EDITOR=vim
export VISUAL="$EDITOR"
export CLICOLOR=1
export HOMEBREW_NO_ANALYTICS=1

# ============================================================================
# PROMPT
# ============================================================================
# Falls back to zsh's default prompt when starship is absent.
command -v starship >/dev/null && eval "$(starship init zsh)"

# ============================================================================
# KEY BINDINGS
# ============================================================================
# vi mode. `bindkey -v` and `set -o vi` are the same operation; only one is kept.
bindkey -v
export KEYTIMEOUT=1
# Ctrl-R / Ctrl-T / Alt-C come from fzf's shell integration below.

# ============================================================================
# VI-MODE CURSOR SHAPE
# ============================================================================
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'   # NORMAL — block
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'   # INSERT — beam
  fi
}
zle -N zle-keymap-select

function zle-line-init { echo -ne '\e[5 q'; }
zle -N zle-line-init

# Restore the beam cursor before running a command. Registered as a hook rather
# than defined as `preexec()`: a bare function definition IS the preexec hook and
# silently replaces whatever other one exists (direnv, tool integrations,
# ~/.zshrc.local), with no error to notice.
autoload -Uz add-zsh-hook
_beam_cursor_preexec() { echo -ne '\e[5 q'; }
add-zsh-hook preexec _beam_cursor_preexec

# ============================================================================
# SHELL INTEGRATIONS
# ============================================================================
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fzf >/dev/null && source <(fzf --zsh)
# After fzf on purpose: atuin takes Ctrl-R over from fzf's integration (Ctrl-T
# and Alt-C stay fzf's). Absent, Ctrl-R stays on fzf.
if command -v atuin >/dev/null; then
  eval "$(atuin init zsh)"
  # atuin binds Ctrl-R in viins only (vicmd gets / and k, vim-style), which
  # leaves fzf's vicmd Ctrl-R in place - one search in insert mode, another in
  # normal mode. Bind atuin's own vicmd widget so Ctrl-R is atuin in both.
  bindkey -M vicmd '^r' atuin-search-vicmd
fi

# ============================================================================
# ZSH PLUGINS (brew-installed) — KEEP LAST
# ============================================================================
# zsh-syntax-highlighting wraps the zle widgets that exist when it is sourced, so
# it has to come after every `zle -N` above and after fzf's integration (which
# rebinds Ctrl-R/Ctrl-T). It used to be sourced before both, despite the comment
# claiming otherwise. Autosuggestions goes immediately before it.
if [ -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ============================================================================
# MACHINE-LOCAL OVERRIDES — must be last
# ============================================================================
# The one seam for everything that cannot be in a public repo or is true of only
# one machine: work aliases, extra PATH entries, tokens, host-specific paths.
# Untracked by design; absent on a fresh machine, hence the -f guard.
#
# Sourced here AND named by the stub install.sh writes to ~/.zshrc, because
# either file may be the only one in play: the stub is what a `wrap` install
# produces, this line is what survives if someone symlinks this file directly.
# The marker keeps that belt-and-braces from running the file twice - measured:
# without it a `path+=` or a counter in ~/.zshrc.local executed on every shell
# twice. The stub tests the same variable before sourcing.
if [ -f "$HOME/.zshrc.local" ] && [ -z "${_DOTFILES_ZSHRC_LOCAL_SOURCED:-}" ]; then
  _DOTFILES_ZSHRC_LOCAL_SOURCED=1
  source "$HOME/.zshrc.local"
fi
