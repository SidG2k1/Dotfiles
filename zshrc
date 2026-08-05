#!/usr/bin/env zsh
# ~/.zshrc - personal laptop

set -o vi

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================
setopt HIST_IGNORE_SPACE
autoload -Uz compinit
# Rebuild dump once per day; use cached dump otherwise
if [[ -n ~/.zcompdump-*(#qN.mh+24) ]] || [[ ! -f ~/.zcompdump-* ]]; then
  compinit
else
  compinit -C
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
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# uv / pipx env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ============================================================================
# LAZY-LOADED TOOLS
# ============================================================================

# NVM - lazy load (saves ~300ms on startup)
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}
node() { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"; node "$@"; }
npm()  { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"; npm "$@"; }
npx()  { unset -f nvm node npm npx; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"; npx "$@"; }

# Google Cloud SDK - lazy load
gcloud() {
  unset -f gcloud
  [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ] && . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
  [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ] && . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
  gcloud "$@"
}

# ============================================================================
# FZF
# ============================================================================
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:50%:wrap"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {} | head -200'"

# ============================================================================
# ZOXIDE (smart cd)
# ============================================================================
_zoxide_cache="${HOME}/.zsh/.zoxide_init.zsh"
if command -v zoxide >/dev/null; then
  if [[ ! -f "$_zoxide_cache" ]] || [[ "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
    mkdir -p "${HOME}/.zsh"
    zoxide init zsh > "$_zoxide_cache"
  fi
  source "$_zoxide_cache"
fi

# ============================================================================
# ALIASES
# ============================================================================
alias o='open'
alias clr='clear'
alias v='vim'
alias p='python3'
alias python='python3'
alias r='ranger'
alias m='math'
alias shred=' shred -uvz'

# Modern CLI replacements
# Wrap eza: v0.23+ reads stdin for paths when not a TTY (e.g. Claude Code's
# bash tool, GitHub Actions), producing no output unless a path is given.
# See https://github.com/eza-community/eza/issues/1568
eza() {
  local a
  for a in "$@"; do [[ "$a" != -* ]] && { command eza "$@"; return; }; done
  command eza "$@" .
}
alias ls='eza --icons'
alias ll='eza -la --icons --git'
alias la='eza -a --icons'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'

# Dev
alias bash5='/opt/homebrew/bin/bash'
alias g++14="g++ -std=c++14 -Wall -g"
alias fsz='du -sh '
alias ssh='ssh -o VisualHostKey=yes'
alias symcrypt='gpg -c --no-symkey-cache'
yt-dlp() {
  print -r -- 'Manual update: uv tool upgrade yt-dlp'
  command yt-dlp "$@"
}
alias onedrive='rclone --vfs-cache-mode writes mount onedrive: ~/OneDrive &'

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
# PROMPT
# ============================================================================
command -v starship >/dev/null && eval "$(starship init zsh)"

# ============================================================================
# ZSH PLUGINS (brew-installed)
# ============================================================================
if [ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Syntax highlighting (must be at the end)
if [ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ============================================================================
# KEY BINDINGS
# ============================================================================
bindkey -v
export KEYTIMEOUT=1
# Ctrl-R / Ctrl-T / Alt-C handled by fzf shell integration below

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

preexec() { echo -ne '\e[5 q'; }

# ============================================================================
# SHELL INTEGRATIONS
# ============================================================================
command -v direnv >/dev/null && eval "$(direnv hook zsh)"
command -v fzf >/dev/null && source <(fzf --zsh)

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
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Navigation / globbing QoL
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt EXTENDED_GLOB

# ============================================================================
# ENV
# ============================================================================
export EDITOR=vim
export VISUAL="$EDITOR"
export CLICOLOR=1
export HOMEBREW_NO_ANALYTICS=1
