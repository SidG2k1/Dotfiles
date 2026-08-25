#!/usr/bin/env bash

# Regression: install.sh must let Homebrew manage owned dependencies, install
# missing ones, and skip dependencies already supplied outside Homebrew.

set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

FIXTURE_REPO="$TEST_ROOT/repo"
FAKE_BIN="$TEST_ROOT/bin"
FAKE_HOME="$TEST_ROOT/home"
FAKE_PREFIX="$TEST_ROOT/homebrew"
BREW_LOG="$TEST_ROOT/brew.log"
EXTERNAL_APP="$TEST_ROOT/External.app"

mkdir -p \
	"$FIXTURE_REPO/vim" \
	"$FAKE_BIN" \
	"$FAKE_HOME" \
	"$FAKE_PREFIX/Caskroom/owned-app" \
	"$EXTERNAL_APP"

cp "$REPO/install.sh" "$FIXTURE_REPO/install.sh"
if [ -f "$REPO/lib/brew-dependencies.sh" ]; then
	mkdir -p "$FIXTURE_REPO/lib"
	cp "$REPO/lib/brew-dependencies.sh" "$FIXTURE_REPO/lib/brew-dependencies.sh"
fi

printf '%s\n' \
	'brew "external-tool"' \
	'brew "owned-tool"' \
	'brew "missing-tool"' \
	'cask "external-app"' \
	'cask "owned-app"' \
	'cask "missing-app"' \
	>"$FIXTURE_REPO/Brewfile"
printf '' >"$FIXTURE_REPO/manifest.tsv"
printf '' >"$FIXTURE_REPO/vim/plugins.txt"

for tool in external-tool owned-tool; do
	printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/$tool"
	chmod +x "$FAKE_BIN/$tool"
done
printf '#!/bin/sh\nexit 99\n' >"$FAKE_BIN/jq"
chmod +x "$FAKE_BIN/jq"

printf '%s\n' \
	'#!/usr/bin/env bash' \
	'set -u' \
	'case "${1:-}" in' \
	'  --prefix) printf "%s\n" "$TEST_BREW_PREFIX" ;;' \
	'  list)' \
	'    [ "${2:-}" = --formula ] && [ "${3:-}" = owned-tool ]' \
	'    ;;' \
	'  info)' \
	'    case "${4:-}" in' \
	'      external-app)' \
	'        printf '\''{"casks":[{"artifacts":[{"app":["External.app"],"target":"%s"}]}]}\n'\'' "$TEST_EXTERNAL_APP"' \
	'        ;;' \
	'      *)' \
	'        printf '\''{"casks":[{"artifacts":[{"app":["Missing.app"]}]}]}\n'\''' \
	'        ;;' \
	'    esac' \
	'    ;;' \
	'  ruby)' \
	'    [ "${HOMEBREW_DEVELOPER:-}" = 1 ] || exit 2' \
	'    python3 -c '\''import json, sys; data=json.load(sys.stdin); [print(value) for artifact in data["casks"][0]["artifacts"] if isinstance(artifact, dict) for value in [artifact.get("target"), (artifact.get("app") or [None])[0], (artifact.get("font") or [None])[0], (artifact.get("binary") or [None])[-1]] if value]'\''' \
	'    ;;' \
	'  bundle)' \
	'    printf "brew-skip=%s\ncask-skip=%s\n" \' \
	'      "${HOMEBREW_BUNDLE_BREW_SKIP:-}" \' \
	'      "${HOMEBREW_BUNDLE_CASK_SKIP:-}" \' \
	'      >"$TEST_BREW_LOG"' \
	'    ;;' \
	'  *) exit 1 ;;' \
	'esac' \
	>"$FAKE_BIN/brew"
chmod +x "$FAKE_BIN/brew"

env \
	HOME="$FAKE_HOME" \
	PATH="$FAKE_BIN:$PATH" \
	TEST_BREW_PREFIX="$FAKE_PREFIX" \
	TEST_EXTERNAL_APP="$EXTERNAL_APP" \
	TEST_BREW_LOG="$BREW_LOG" \
	HOMEBREW_BUNDLE_BREW_SKIP=preexisting-formula \
	HOMEBREW_BUNDLE_CASK_SKIP=preexisting-cask \
	"$FIXTURE_REPO/install.sh" --only brew >/dev/null

EXPECTED="$TEST_ROOT/expected"
printf '%s\n' \
	'brew-skip=preexisting-formula external-tool' \
	'cask-skip=preexisting-cask external-app' \
	>"$EXPECTED"

diff -u "$EXPECTED" "$BREW_LOG"
