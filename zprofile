#!/usr/bin/env zsh
# zprofile — REFERENCE ONLY. The installer does not install this file.
#
# manifest.tsv marks the ~/.zprofile target `never`. On a real machine that file
# is owned by other tools' installers - Homebrew's shellenv snippet, container and
# VM shell hooks, language-toolchain env lines - which append to it and rewrite it
# on upgrade. Symlinking or copying over it silently deletes working integrations
# that nothing will tell you are gone. Copy the line you want by hand, or put it
# in ~/.zshenv.local (see this repo's `zshenv`).
#
# ~/.zprofile is read by LOGIN zsh shells only, before ~/.zshrc.
#
# The line below is usually redundant. The Homebrew installer writes
# /etc/paths.d/homebrew, and macOS `path_helper` - run from /etc/zprofile for
# every login shell - already puts the brew bin dir on PATH. `brew shellenv` adds
# HOMEBREW_PREFIX / HOMEBREW_CELLAR / MANPATH / INFOPATH and puts brew's bin
# ahead of the system dirs instead of after them; keep it only if you want that.
# This repo's `zshrc` derives HOMEBREW_PREFIX itself and does not depend on it.
#
# Guarded and prefix-agnostic: /opt/homebrew is Apple Silicon, /usr/local Intel.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
