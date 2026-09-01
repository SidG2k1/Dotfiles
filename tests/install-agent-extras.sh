#!/usr/bin/env bash

# Regression: install.sh must link vendored skills into every tool's skills
# dir, install the gh-stack gh extension exactly once, and never reinstall a
# vendored skill that is already present.

set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-agent-extras-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

FIXTURE_REPO="$TEST_ROOT/repo"
FAKE_BIN="$TEST_ROOT/bin"
FAKE_HOME="$TEST_ROOT/home"
GH_LOG="$TEST_ROOT/gh.log"
NPX_LOG="$TEST_ROOT/npx.log"

mkdir -p \
	"$FIXTURE_REPO/vim" \
	"$FIXTURE_REPO/lib" \
	"$FAKE_BIN" \
	"$FAKE_HOME/.agents/skills/gh-stack" \
	"$FAKE_HOME/.agents/skills/find-skills"

cp "$REPO/install.sh" "$FIXTURE_REPO/install.sh"
cp "$REPO/lib/brew-dependencies.sh" "$FIXTURE_REPO/lib/brew-dependencies.sh"
printf '' >"$FIXTURE_REPO/manifest.tsv"
printf '' >"$FIXTURE_REPO/vim/plugins.txt"
printf '' >"$FIXTURE_REPO/Brewfile"

printf '%s\n' '---' 'name: stub' '---' >"$FAKE_HOME/.agents/skills/gh-stack/SKILL.md"
printf '%s\n' '---' 'name: stub' '---' >"$FAKE_HOME/.agents/skills/find-skills/SKILL.md"

# gh: extension list reflects whether install has run; install appends to a log.
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'set -u' \
	'case "${1:-} ${2:-}" in' \
	'  "extension list") [ -f "$TEST_GH_STATE" ] && printf "gh stack\tgithub/gh-stack\tv0.1.0\n"; exit 0 ;;' \
	'  "extension install") printf "install %s\n" "${3:-}" >>"$TEST_GH_LOG"; touch "$TEST_GH_STATE"; exit 0 ;;' \
	'  *) exit 1 ;;' \
	'esac' \
	>"$FAKE_BIN/gh"
chmod +x "$FAKE_BIN/gh"

# npx must not run: both vendored skills already exist in ~/.agents/skills.
printf '#!/bin/sh\necho "npx $*" >>"$TEST_NPX_LOG"\nexit 99\n' >"$FAKE_BIN/npx"
chmod +x "$FAKE_BIN/npx"

run_install() {
	env \
		HOME="$FAKE_HOME" \
		PATH="$FAKE_BIN:$PATH" \
		TEST_GH_LOG="$GH_LOG" \
		TEST_GH_STATE="$TEST_ROOT/gh-stack-installed" \
		TEST_NPX_LOG="$NPX_LOG" \
		"$FIXTURE_REPO/install.sh" --only agents --skip-brew >/dev/null
}

run_install
run_install  # second run must be idempotent

for tool in claude codex; do
	for skill in gh-stack find-skills; do
		link="$FAKE_HOME/.$tool/skills/$skill"
		[ "$(readlink "$link")" = "../../.agents/skills/$skill" ] ||
			{ echo "FAIL: $link is not a relative link to ~/.agents"; exit 1; }
		[ -f "$link/SKILL.md" ] || { echo "FAIL: $link does not resolve"; exit 1; }
	done
done

EXPECTED="$TEST_ROOT/expected"
printf 'install github/gh-stack\n' >"$EXPECTED"
diff -u "$EXPECTED" "$GH_LOG"

[ ! -s "$NPX_LOG" ] || { echo "FAIL: npx was invoked for already-present skills"; cat "$NPX_LOG"; exit 1; }
