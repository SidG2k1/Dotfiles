#!/usr/bin/env bash
#
# install.sh - install this repo's configs onto a macOS machine.
#
# manifest.tsv is the source of truth: every install action below is driven by a
# row in it, and the strategy column decides HOW a target is produced. Nothing
# here hardcodes a username or a /Users/... path, and nothing writes a secret.
#
#   ./install.sh                      install everything
#   ./install.sh --dry-run            print the plan, touch nothing
#   ./install.sh --only vim           one group (see --help for the list)
#   ./install.sh --skip-brew          leave Homebrew alone
#   ./install.sh --skip-vim-plugins   do not fetch pathogen or the bundles
#
# Re-running is safe: an already-correct target is reported and left alone. Any
# target that exists and is not already correct is backed up under
# ~/dotfiles-backup/<timestamp>/ before it is replaced, and the backup path is
# printed. Targets whose strategy is include/append-once/merge-json are never
# rewritten wholesale - only the managed block or the tracked JSON keys change.
#
# Written for the bash that ships with macOS (3.2): no associative arrays, no
# ${var,,}, no mapfile.

# shellcheck disable=SC2088
# SC2088 ("tilde does not expand in quotes") is disabled file-wide and on
# purpose. A literal '~' is *data* in this script, never a path to expand:
# manifest.tsv stores targets as '~/...' strings that are parsed, and report
# output collapses $HOME back to '~' for readability. Real expansion happens
# in one place, via "$HOME". Several of these sites are case-branch patterns,
# where a per-site directive is not valid syntax (SC1124).

set -euo pipefail

# ---------------------------------------------------------------- environment

# Repo root = directory of this script, with symlinks resolved, so the clone can
# live anywhere ($HOME/dotfiles, /opt/dotfiles, a worktree).
SCRIPT_SRC="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SRC" ]; do
	SCRIPT_DIR_TMP="$(cd -P "$(dirname -- "$SCRIPT_SRC")" && pwd)"
	SCRIPT_SRC="$(readlink "$SCRIPT_SRC")"
	case "$SCRIPT_SRC" in
		/*) ;;
		*) SCRIPT_SRC="$SCRIPT_DIR_TMP/$SCRIPT_SRC" ;;
	esac
done
DOTFILES="$(cd -P "$(dirname -- "$SCRIPT_SRC")" && pwd)"
MANIFEST="$DOTFILES/manifest.tsv"
PLUGIN_LIST="$DOTFILES/vim/plugins.txt"
BREWFILE="$DOTFILES/Brewfile"
BREW_DEPENDENCIES="$DOTFILES/lib/brew-dependencies.sh"

PATHOGEN_URL="https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim"

BLOCK_START='# >>> dotfiles managed block >>>'
BLOCK_END='# <<< dotfiles managed block <<<'

BACKUP_ROOT="$HOME/dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
SKIP_BREW=0
SKIP_VIM_PLUGINS=0
ONLY=""

VALID_GROUPS="dirs brew shell vim terminal git agents tools scripts never vim-plugins"

# ------------------------------------------------------------------- plumbing

if [ -t 1 ]; then
	C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
	C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BLUE=$'\033[34m'
else
	C_RESET=""; C_DIM=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""
fi

N_OK=0
N_CHANGED=0
N_SKIPPED=0
FAILURES=()
MANUAL=()
BACKED_UP=()

heading() { printf '\n%s== %s%s\n' "$C_BOLD$C_BLUE" "$1" "$C_RESET"; }
status()  { printf '  %s%-7s%s %s\n' "$2" "$1" "$C_RESET" "$3"; }
ok()      { N_OK=$((N_OK + 1)); status ok "$C_GREEN" "$1"; }
changed() { N_CHANGED=$((N_CHANGED + 1)); status changed "$C_GREEN" "$1"; }
skipped() { N_SKIPPED=$((N_SKIPPED + 1)); status skip "$C_DIM" "$1"; }
warn()    { status warn "$C_YELLOW" "$1" >&2; }
plan()    { status plan "$C_DIM" "$1"; }
note()    {
	# Wrap a manifest note so a 300-character explanation stays readable.
	printf '%s\n' "$1" | fold -s -w 84 | while IFS= read -r _l; do
		printf '          %s%s%s\n' "$C_DIM" "$_l" "$C_RESET"
	done
}
fail() {
	# Record a failure, keep going: one broken row must not abandon the rest.
	FAILURES+=("$1")
	status FAIL "$C_RED" "$1" >&2
	if [ -n "${2:-}" ]; then note "$2" >&2; fi
}
manual() { MANUAL+=("$1"); }

die() { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage: ./install.sh [--dry-run] [--only <group>] [--skip-brew] [--skip-vim-plugins]

  --dry-run            print every action that would be taken; change nothing
  --only <group>       restrict to one group of manifest rows (below)
  --skip-brew          do not run `brew bundle`
  --skip-vim-plugins   do not fetch pathogen or clone vim/plugins.txt bundles
  -h, --help           this text

Groups. shell..never are the section headers in manifest.tsv; dirs, brew and
vim-plugins are phases of this script with no manifest rows of their own:
  dirs         only create the directories the other groups need, then stop
  shell        ~/.zshenv, ~/.zshrc
  vim          ~/.vimrc, ~/.vim/templates  (+ vim-plugins unless skipped)
  terminal     starship, Ghostty
  git          ~/.gitconfig include, global gitignore
  agents       AGENTS.md, personal skills, Claude Code settings, vendored
               skills (skills CLI) + the gh-stack gh extension
  tools        gh, VS Code, yt-dlp, gnupg, docker
  scripts      ~/bin helpers
  never        print the rows this repo deliberately does not install, and why
  brew         Homebrew bundle only
  vim-plugins  pathogen + bundles only

Directory creation runs for every group except `brew` and `never`, which touch
no target; --dry-run suppresses it like everything else.
EOF
}

# abs_of <path> -> absolute path, resolving symlinks in the PARENT chain only.
# Used to compare "where does this existing symlink point" against "where do we
# want it to point" without depending on realpath(1) being present.
abs_of() {
	local p="$1" d b
	d="$(dirname -- "$p")"
	b="$(basename -- "$p")"
	if [ -d "$d" ]; then d="$(cd -P "$d" && pwd)"; fi
	case "$b" in
		.)  printf '%s\n' "$d" ;;
		..) printf '%s\n' "$(dirname -- "$d")" ;;
		*)  printf '%s/%s\n' "${d%/}" "$b" ;;
	esac
}

# display_path <abs path> -> the same path written with a leading ~ when it is
# under $HOME, so printed output and generated files carry no username.
display_path() {
	case "$1" in
		"$HOME") printf '~\n' ;;
		"$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

# shell_path <abs path> -> the path written for embedding in a generated shell
# file: "$HOME/dotfiles/zshrc" rather than an absolute /Users/... string.
shell_path() {
	case "$1" in
		"$HOME"/*) printf '$HOME/%s\n' "${1#"$HOME"/}" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

expand_target() {
	case "$1" in
		"~/"*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
		"~") printf '%s\n' "$HOME" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

want_group() {
	[ -z "$ONLY" ] && return 0
	[ "$ONLY" = "$1" ] && return 0
	# --only vim also covers the vim plugin fetch.
	[ "$ONLY" = "vim" ] && [ "$1" = "vim-plugins" ] && return 0
	return 1
}

ensure_dir() {
	local d="$1" mode="${2:-}"
	if [ -d "$d" ]; then
		if [ -n "$mode" ] && [ "$DRY_RUN" -eq 0 ]; then chmod "$mode" "$d"; fi
		return 0
	fi
	if [ -e "$d" ] || [ -L "$d" ]; then
		fail "$(display_path "$d") exists and is not a directory" \
			"Move or remove it by hand, then re-run. The installer will not delete a non-directory that is in the way of a directory."
		return 1
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "mkdir -p $(display_path "$d")${mode:+ (mode $mode)}"
		return 0
	fi
	mkdir -p "$d"
	if [ -n "$mode" ]; then chmod "$mode" "$d"; fi
	return 0
}

ensure_parent() {
	local d
	d="$(dirname -- "$1")"
	case "$d" in
		"$HOME/.gnupg") ensure_dir "$d" 700 ;;  # gpg refuses a world-readable ~/.gnupg
		*) ensure_dir "$d" ;;
	esac
}

# backup_dest <target> -> a path under $BACKUP_ROOT that mirrors the target's
# location relative to $HOME, so the backup is self-describing.
backup_dest() {
	local t="$1" rel
	case "$t" in
		"$HOME"/*) rel="${t#"$HOME"/}" ;;
		/*) rel="ROOT/${t#/}" ;;
		*) rel="$t" ;;
	esac
	local dest="$BACKUP_ROOT/$rel" n=1
	while [ -e "$dest" ] || [ -L "$dest" ]; do
		dest="$BACKUP_ROOT/$rel.$n"
		n=$((n + 1))
	done
	printf '%s\n' "$dest"
}

# backup_move: for strategies that REPLACE the target (link, wrap). Moving is
# used rather than copy+delete so nothing can be lost to a partial copy.
backup_move() {
	local t="$1" dest
	dest="$(backup_dest "$t")"
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "backup (move) $(display_path "$t") -> $(display_path "$dest")"
		return 0
	fi
	mkdir -p "$(dirname -- "$dest")"
	mv "$t" "$dest"
	status backup "$C_YELLOW" "$(display_path "$t") -> $(display_path "$dest")"
	BACKED_UP+=("$(display_path "$dest")")
}

# backup_copy: for strategies that EDIT the target in place (include,
# append-once, merge-json). The target has to stay where it is.
backup_copy() {
	local t="$1" dest
	dest="$(backup_dest "$t")"
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "backup (copy) $(display_path "$t") -> $(display_path "$dest")"
		return 0
	fi
	mkdir -p "$(dirname -- "$dest")"
	cp -Rp "$t" "$dest"
	status backup "$C_YELLOW" "$(display_path "$t") -> $(display_path "$dest")"
	BACKED_UP+=("$(display_path "$dest")")
}

TMPDIR_SELF=""
tmpfile() {
	if [ -z "$TMPDIR_SELF" ]; then
		TMPDIR_SELF="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"
	fi
	mktemp "$TMPDIR_SELF/f.XXXXXX"
}
cleanup() { if [ -n "$TMPDIR_SELF" ]; then rm -rf "$TMPDIR_SELF"; fi; }
trap cleanup EXIT

# Write $1 (a temp file) over $2 (the real target), keeping the target's own
# mode when it already exists. Writing through with `cat` rather than `cp` so an
# existing file keeps its inode, mode and ownership; only a file we create gets
# a mode of ours.
install_content() {
	local src="$1" tgt="$2" existed=0
	if [ "$DRY_RUN" -eq 1 ]; then return 0; fi
	if [ -e "$tgt" ]; then existed=1; fi
	cat "$src" >"$tgt"
	if [ "$existed" -eq 0 ]; then chmod 644 "$tgt"; fi
}

# The in-place strategies (include, append-once, merge-json) edit the target
# where it stands. If the target is a leftover symlink INTO this repo - what an
# older link-everything install would have left - editing in place would write
# into the repo working tree instead (and for ~/.gitconfig, produce a file that
# includes itself). Move that link aside and start from a real file. A symlink
# pointing anywhere else is the user's own indirection and is honoured.
detach_repo_symlink() {
	local tgt="$1" cur cur_abs
	[ -L "$tgt" ] || return 0
	cur="$(readlink "$tgt")"
	case "$cur" in
		/*) cur_abs="$(abs_of "$cur")" ;;
		*) cur_abs="$(abs_of "$(dirname -- "$tgt")/$cur")" ;;
	esac
	case "$cur_abs" in
		"$DOTFILES"/*|"$DOTFILES")
			warn "$(display_path "$tgt") is a symlink into the repo; this strategy needs a real file"
			backup_move "$tgt"
			;;
	esac
	return 0
}

# ------------------------------------------------------------ argument parsing

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--skip-brew) SKIP_BREW=1 ;;
		--skip-vim-plugins) SKIP_VIM_PLUGINS=1 ;;
		--only)
			[ $# -ge 2 ] || die "--only needs a group name. Valid: $VALID_GROUPS"
			ONLY="$2"
			shift
			;;
		--only=*) ONLY="${1#--only=}" ;;
		-h|--help) usage; exit 0 ;;
		*) die "unknown option '$1'. Run './install.sh --help'." ;;
	esac
	shift
done

if [ -n "$ONLY" ] && [ "$ONLY" != "all" ]; then
	_found=0
	for _g in $VALID_GROUPS; do
		[ "$_g" = "$ONLY" ] && _found=1
	done
	[ "$_found" -eq 1 ] || die "unknown group '$ONLY'. Valid: $VALID_GROUPS"
fi
[ "$ONLY" = "all" ] && ONLY=""

[ -f "$MANIFEST" ] || die "manifest.tsv not found at $MANIFEST - is this the repo root?"
[ -f "$BREW_DEPENDENCIES" ] || die "dependency probes not found at $BREW_DEPENDENCIES"
# shellcheck source=lib/brew-dependencies.sh
. "$BREW_DEPENDENCIES"

# ------------------------------------------------------------------ strategies

# group_for <section header text> -> a short slug usable with --only.
group_for() {
	local raw
	raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	case "$raw" in
		shell*) printf 'shell\n' ;;
		vim*) printf 'vim\n' ;;
		prompt*|terminal*) printf 'terminal\n' ;;
		git*) printf 'git\n' ;;
		agents*) printf 'agents\n' ;;
		per-tool*|tools*) printf 'tools\n' ;;
		script*) printf 'scripts\n' ;;
		deliberately*|never*) printf 'never\n' ;;
		*) printf '%s\n' "$(printf '%s' "$raw" | tr -cs 'a-z0-9' '-')" ;;
	esac
}

# The link value for a row. Two rows in the manifest deliberately do NOT point
# at the repo:
#   * ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md point at ~/.agents/AGENTS.md so
#     all three agents read one file and the repo can move.
#   * ~/.claude/skills/<skill> and ~/.codex/skills/<skill> are RELATIVE
#     ../../.agents/skills/<skill> links, so every tool's skills dir and
#     ~/.agents resolve to the same SKILL.md.
#   * each skills dir's README.md is a RELATIVE ../../.agents/SKILLS.md link.
#     It must be matched before the <skill> rule below, which would otherwise
#     derive ../../.agents/skills/README.md from the basename.
link_value_for() {
	local src_rel="$1" src_abs="$2" tgt="$3"
	case "$tgt" in
		"$HOME/.claude/skills/README.md"|"$HOME/.codex/skills/README.md")
			printf '../../.agents/SKILLS.md\n'
			return 0
			;;
		"$HOME/.claude/skills/"*|"$HOME/.codex/skills/"*)
			printf '../../.agents/skills/%s\n' "$(basename -- "$tgt")"
			return 0
			;;
	esac
	if [ "$src_rel" = "agents/AGENTS.md" ] && [ "$tgt" != "$HOME/.agents/AGENTS.md" ]; then
		printf '%s\n' "$HOME/.agents/AGENTS.md"
		return 0
	fi
	printf '%s\n' "$src_abs"
}

do_link() {
	local src_rel="$1" src_abs="$2" tgt="$3"
	local want want_abs cur cur_abs

	want="$(link_value_for "$src_rel" "$src_abs" "$tgt")"
	case "$want" in
		/*) want_abs="$(abs_of "$want")" ;;
		*) want_abs="$(abs_of "$(dirname -- "$tgt")/$want")" ;;
	esac

	# The ~/.claude and ~/.codex links point through ~/.agents, which an earlier
	# manifest row creates - so in a dry run "not there yet" is expected and not
	# worth warning about.
	if [ ! -e "$want_abs" ] && [ "$DRY_RUN" -eq 0 ]; then
		warn "$(display_path "$tgt") points at $(display_path "$want_abs"), which does not exist"
	fi

	ensure_parent "$tgt" || return 0

	if [ -L "$tgt" ]; then
		cur="$(readlink "$tgt")"
		if [ "$cur" = "$want" ]; then
			ok "$(display_path "$tgt") -> $want"
			return 0
		fi
		case "$cur" in
			/*) cur_abs="$(abs_of "$cur")" ;;
			*) cur_abs="$(abs_of "$(dirname -- "$tgt")/$cur")" ;;
		esac
		if [ "$cur_abs" = "$want_abs" ]; then
			# Same file, different spelling (absolute vs relative). Normalise
			# quietly; nothing is at risk, so no backup.
			if [ "$DRY_RUN" -eq 1 ]; then
				plan "relink $(display_path "$tgt") -> $want (was $cur)"
			else
				ln -sfn "$want" "$tgt"
				changed "$(display_path "$tgt") -> $want (normalised from $cur)"
			fi
			return 0
		fi
		backup_move "$tgt"
	elif [ -e "$tgt" ]; then
		backup_move "$tgt"
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		plan "link $(display_path "$tgt") -> $want"
		return 0
	fi
	ln -sfn "$want" "$tgt"
	changed "$(display_path "$tgt") -> $want"
}

# wrap: the target becomes a stub that sources the repo file and then the
# machine-local tail. The repo file stays public; PATH entries, work aliases and
# anything secret-adjacent live in the .local file, which is never tracked.
do_wrap() {
	local src_abs="$1" tgt="$2"
	local localfile="${tgt}.local" tmp
	tmp="$(tmpfile)"

	{
		printf '# Managed by dotfiles install.sh - regenerated on every run, do not edit.\n'
		printf '# Repo config:   %s\n' "$(display_path "$src_abs")"
		printf '# Machine-local: %s (untracked, optional, sourced last)\n' "$(display_path "$localfile")"
		printf 'source "%s"\n' "$(shell_path "$src_abs")"
		# The repo file sources the .local tail itself and sets the marker below.
		# Testing it here keeps the stub working on its own (if the repo file ever
		# stops doing it) without sourcing the .local file twice per shell, which
		# would run any `path+=` or counter in it two times.
		printf '[ -z "${_DOTFILES_ZSHRC_LOCAL_SOURCED:-}" ] && [ -r "%s" ] && source "%s"\n' \
			"$(shell_path "$localfile")" "$(shell_path "$localfile")"
		printf ':\n'
	} >"$tmp"

	ensure_parent "$tgt" || return 0

	if [ -f "$tgt" ] && [ ! -L "$tgt" ] && cmp -s "$tmp" "$tgt"; then
		ok "$(display_path "$tgt") stub (sources $(display_path "$src_abs"), then $(display_path "$localfile"))"
		return 0
	fi

	if [ -e "$tgt" ] || [ -L "$tgt" ]; then
		backup_move "$tgt"
		manual "Your previous $(display_path "$tgt") was backed up - move any machine-specific lines from it into $(display_path "$localfile") (that file is untracked and sourced last)."
	fi

	if [ "$DRY_RUN" -eq 1 ]; then
		plan "write stub $(display_path "$tgt") -> sources $(display_path "$src_abs"), then $(display_path "$localfile")"
		return 0
	fi
	install_content "$tmp" "$tgt"
	changed "$(display_path "$tgt") stub written"
}

# include: the target stays user-owned. We append [include] directives and never
# touch anything else, because ~/.gitconfig holds identity (user.email,
# user.signingkey) and tool-written blocks like [filter "lfs"].
gitconfig_has_include() {
	local file="$1" want_abs="$2" line line_abs
	[ -f "$file" ] || return 1
	if command -v git >/dev/null 2>&1; then
		# git parses both [include] spellings and any indentation.
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			case "$line" in
				"~/"*) line_abs="$HOME/${line#\~/}" ;;
				*) line_abs="$line" ;;
			esac
			[ "$line_abs" = "$want_abs" ] && return 0
		done <<EOF
$(git config --file "$file" --get-all include.path 2>/dev/null || true)
EOF
	fi
	# Fallback for an unparseable file: literal match on either spelling.
	if grep -Fq "$want_abs" "$file"; then return 0; fi
	if grep -Fq "$(display_path "$want_abs")" "$file"; then return 0; fi
	return 1
}

do_include() {
	local src_abs="$1" tgt="$2"
	local localcfg="$HOME/.gitconfig.local"
	# Two include paths, tracked in two scalars rather than a list, so a repo
	# path containing a space cannot be split apart.
	local pend_repo="" pend_local=""

	ensure_parent "$tgt" || return 0
	detach_repo_symlink "$tgt"

	if gitconfig_has_include "$tgt" "$src_abs"; then
		ok "$(display_path "$tgt") already includes $(display_path "$src_abs")"
	else
		pend_repo="$src_abs"
	fi
	if gitconfig_has_include "$tgt" "$localcfg"; then
		ok "$(display_path "$tgt") already includes $(display_path "$localcfg")"
	else
		pend_local="$localcfg"
	fi

	if [ -n "$pend_repo" ] || [ -n "$pend_local" ]; then
		if [ -f "$tgt" ]; then backup_copy "$tgt"; fi
		if [ "$DRY_RUN" -eq 1 ]; then
			if [ -n "$pend_repo" ]; then
				plan "append [include] path = $(display_path "$pend_repo") to $(display_path "$tgt")"
			fi
			if [ -n "$pend_local" ]; then
				plan "append [include] path = $(display_path "$pend_local") to $(display_path "$tgt")"
			fi
		else
			# Guarantee we start on a fresh line; never rewrite existing bytes.
			if [ -s "$tgt" ] && [ -n "$(tail -c 1 "$tgt")" ]; then printf '\n' >>"$tgt"; fi
			{
				printf '\n# Added once by dotfiles install.sh. Everything else in this file is yours.\n'
				[ -n "$pend_repo" ] && printf '[include]\n\tpath = %s\n' "$(display_path "$pend_repo")"
				[ -n "$pend_local" ] && printf '[include]\n\tpath = %s\n' "$(display_path "$pend_local")"
				:
			} >>"$tgt"
			if [ -n "$pend_repo" ]; then
				changed "$(display_path "$tgt") includes $(display_path "$pend_repo")"
			fi
			if [ -n "$pend_local" ]; then
				changed "$(display_path "$tgt") includes $(display_path "$pend_local")"
			fi
		fi
	fi

	# Identity lives in the untracked .local file. Seed a commented template
	# only - this script never writes an email address or a key.
	if [ ! -e "$localcfg" ]; then
		if [ "$DRY_RUN" -eq 1 ]; then
			plan "create $(display_path "$localcfg") (commented identity template)"
		else
			{
				printf '# Machine-local git identity. Untracked on purpose: nothing here is public.\n'
				printf '# Included by %s.\n' "$(display_path "$tgt")"
				printf '[user]\n'
				printf '\t# name = <your name>\n'
				printf '\t# email = <your address>\n'
			} >"$localcfg"
			chmod 600 "$localcfg"
			changed "$(display_path "$localcfg") created (fill in identity)"
		fi
		manual "Fill in $(display_path "$localcfg") with [user] name and email. The tracked gitconfig sets no identity and no commit signing - both are machine-specific."
	else
		ok "$(display_path "$localcfg") exists (identity left untouched)"
	fi
}

# append-once: both the tool and the human edit this file, so the repo owns only
# the region between the markers and rewrites just that.
do_append_once() {
	local src_abs="$1" tgt="$2"
	local block desired

	block="$(tmpfile)"
	{
		printf '%s\n' "$BLOCK_START"
		printf '# Generated from %s by dotfiles install.sh.\n' "$(display_path "$src_abs")"
		printf '# Edits between these markers are overwritten - put yours outside them.\n'
		cat "$src_abs"
		printf '%s\n' "$BLOCK_END"
	} >"$block"

	ensure_parent "$tgt" || return 0
	detach_repo_symlink "$tgt"

	desired="$(tmpfile)"
	if [ -f "$tgt" ]; then
		local has_start=0 has_end=0
		if grep -Fxq "$BLOCK_START" "$tgt"; then has_start=1; fi
		if grep -Fxq "$BLOCK_END" "$tgt"; then has_end=1; fi
		if [ "$has_start" -eq 1 ] && [ "$has_end" -eq 0 ]; then
			fail "$(display_path "$tgt") has an opening managed marker with no closing one" \
				"Refusing to touch it: replacing the block would silently delete everything after the marker. Add the line '$BLOCK_END' at the end of the managed region (or delete the opening marker), then re-run."
			return 0
		fi
		awk -v s="$BLOCK_START" -v e="$BLOCK_END" -v bf="$block" '
			$0 == s { found = 1; inb = 1
				while ((getline l < bf) > 0) print l
				close(bf); next }
			inb && $0 == e { inb = 0; next }
			inb { next }
			{ print }
			END {
				if (!found) {
					if (NR > 0) print ""
					while ((getline l < bf) > 0) print l
					close(bf)
				}
			}
		' "$tgt" >"$desired"
	else
		cat "$block" >"$desired"
	fi

	if [ -f "$tgt" ] && cmp -s "$desired" "$tgt"; then
		ok "$(display_path "$tgt") managed block up to date"
		return 0
	fi

	if [ -f "$tgt" ]; then backup_copy "$tgt"; fi
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "write managed block into $(display_path "$tgt") (rest of the file untouched)"
		return 0
	fi
	install_content "$desired" "$tgt"
	changed "$(display_path "$tgt") managed block written"
}

# merge-json: the app writes this file itself, so merge the tracked key subset
# instead of linking. The tracked subset is exactly the top-level keys present
# in the repo file; the merge is recursive (jq's `*`), so nested keys the app
# added survive and only tracked keys are overwritten.
json_prune_filter() {
	# Per-target removals of keys the repo file has deliberately dropped. Kept
	# tiny and explicit: a recursive merge alone cannot delete anything, so a
	# key the repo replaced would otherwise linger and warn forever.
	local tgt="$1" src_abs="$2"
	case "$tgt" in
		*/.docker/daemon.json)
			# builder.gc.defaultKeepStorage is deprecated in favour of
			# builder.gc.policy. Drop the stale key only when the repo file no
			# longer sets it, so Docker stops warning at startup.
			if ! jq -e 'has("builder") and (.builder | has("gc")) and (.builder.gc | has("defaultKeepStorage"))' \
				"$src_abs" >/dev/null 2>&1; then
				printf 'if (.builder.gc? | type) == "object" then del(.builder.gc.defaultKeepStorage) else . end\n'
				return 0
			fi
			;;
	esac
	printf '.\n'
}

do_merge_json() {
	local src_abs="$1" tgt="$2"
	local prune desired base

	if ! command -v jq >/dev/null 2>&1; then
		fail "jq is required to merge $(display_path "$tgt") and is not on PATH" \
			"Install it with 'brew install jq' (it is in this repo's Brewfile) and re-run. jq is also what the Claude Code statusLine command pipes through, so the status line is blank without it."
		return 0
	fi
	if ! jq -e . "$src_abs" >/dev/null 2>&1; then
		fail "$(display_path "$src_abs") is not valid JSON" \
			"Fix the repo file; the installer will not merge a file it cannot parse."
		return 0
	fi

	ensure_parent "$tgt" || return 0
	detach_repo_symlink "$tgt"

	prune="$(json_prune_filter "$tgt" "$src_abs")"
	desired="$(tmpfile)"

	if [ -f "$tgt" ]; then
		if [ ! -r "$tgt" ]; then
			fail "$(display_path "$tgt") is not readable"
			return 0
		fi
		if ! jq -e . "$tgt" >/dev/null 2>&1; then
			fail "$(display_path "$tgt") is not valid JSON - not merging" \
				"Nothing was written and nothing was removed. Most often this is JSONC: comments or trailing commas, which VS Code accepts and jq does not. Strip them (or move the file aside) and re-run."
			return 0
		fi
		base="$(tmpfile)"
		if ! jq "$prune" "$tgt" >"$base" 2>/dev/null; then
			fail "could not pre-process $(display_path "$tgt") with jq"
			return 0
		fi
		if ! jq -s '.[0] * .[1]' "$base" "$src_abs" >"$desired" 2>/dev/null; then
			fail "jq merge failed for $(display_path "$tgt")"
			return 0
		fi
	else
		if ! jq '.' "$src_abs" >"$desired" 2>/dev/null; then
			fail "jq could not render $(display_path "$src_abs")"
			return 0
		fi
	fi

	if ! jq -e . "$desired" >/dev/null 2>&1; then
		fail "refusing to write $(display_path "$tgt"): merged result is not valid JSON"
		return 0
	fi

	# Compare semantically so a difference in the app's own indentation does not
	# cause a rewrite on every run.
	if [ -f "$tgt" ] && jq -e -s '.[0] == .[1]' "$tgt" "$desired" >/dev/null 2>&1; then
		ok "$(display_path "$tgt") tracked keys already merged"
		return 0
	fi

	if [ -f "$tgt" ]; then backup_copy "$tgt"; fi
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "jq-merge tracked keys of $(display_path "$src_abs") into $(display_path "$tgt")"
		return 0
	fi
	install_content "$desired" "$tgt"
	changed "$(display_path "$tgt") tracked keys merged"
}

do_never() {
	local tgt="$1" note_text="$2"
	skipped "$(display_path "$tgt") - not installed by this repo"
	if [ -n "$note_text" ]; then note "$note_text"; fi
}

# ---------------------------------------------------------------------- phases

phase_dirs() {
	heading "directories"
	# ~/.vim/undo is here because vimrc sets undodir=~/.vim/undo//; without the
	# directory vim reports an error on write for every buffer.
	for d in \
		"$HOME/bin" \
		"$HOME/.config/git" \
		"$HOME/.vim/autoload" \
		"$HOME/.vim/bundle" \
		"$HOME/.vim/backup" \
		"$HOME/.vim/swap" \
		"$HOME/.vim/undo" \
		"$HOME/.vim/after/plugin" \
		"$HOME/.agents/skills" \
		"$HOME/.claude/skills" \
		"$HOME/.codex" \
		"$HOME/.codex/skills"
	do
		if [ -d "$d" ]; then
			ok "$(display_path "$d")"
		elif ensure_dir "$d"; then
			if [ "$DRY_RUN" -eq 0 ]; then changed "$(display_path "$d") created"; fi
		fi
	done
	return 0
}

phase_brew() {
	local brew_skip="${HOMEBREW_BUNDLE_BREW_SKIP:-}"
	local cask_skip="${HOMEBREW_BUNDLE_CASK_SKIP:-}"
	local kind name
	heading "homebrew"
	if ! command -v brew >/dev/null 2>&1; then
		warn "brew not found - skipping 'brew bundle'. Nothing else in this install depends on it."
		manual "Install Homebrew (see setup.md), then run: brew bundle --file=\"\$PWD/Brewfile\". Until then eza, bat, jq, delta, fzf, zoxide, starship and direnv are missing: ls/cat/git diff and the Claude status line degrade."
		N_SKIPPED=$((N_SKIPPED + 1))
		return 0
	fi
	if [ ! -f "$BREWFILE" ]; then
		fail "Brewfile not found at $(display_path "$BREWFILE")"
		return 0
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		plan "brew bundle --file=$(display_path "$BREWFILE")"
		return 0
	fi
	while IFS=$'\t' read -r kind name; do
		[ -n "${name:-}" ] || continue
		case "$kind" in
			brew)
				case " $brew_skip " in
					*" $name "*) ;;
					*) brew_skip="${brew_skip:+$brew_skip }$name" ;;
				esac
				;;
			cask)
				case " $cask_skip " in
					*" $name "*) ;;
					*) cask_skip="${cask_skip:+$cask_skip }$name" ;;
				esac
				;;
		esac
		status reuse "$C_DIM" "$kind $name (already available outside Homebrew)"
	done < <(external_brewfile_entries "$BREWFILE")
	printf '  running brew bundle (this can take a while)...\n'
	if HOMEBREW_BUNDLE_BREW_SKIP="$brew_skip" \
		HOMEBREW_BUNDLE_CASK_SKIP="$cask_skip" \
		brew bundle --file="$BREWFILE" </dev/null; then
		changed "brew bundle completed"
	else
		fail "brew bundle reported errors" \
			"Re-run 'brew bundle --file=$(display_path "$BREWFILE")' by hand to see which formula failed. Config installs above are unaffected."
	fi
	manual "Optional per-feature extras are not installed: brew bundle --file=\"$(display_path "$DOTFILES/Brewfile.optional")\"."
	return 0
}

phase_manifest() {
	heading "manifest"
	local group="general" src tgt strat note_text src_abs raw

	# Read the manifest on fd 3 so nothing inside the loop (git, curl, brew, jq)
	# can swallow the rest of the file by reading stdin.
	while IFS=$'\t' read -r src tgt strat note_text <&3 || [ -n "${src:-}" ]; do
		# Section headers carry the group name used by --only.
		case "$src" in
			'# ---- '*' ----'*)
				raw="${src#\# ---- }"
				raw="${raw%% ----*}"
				group="$(group_for "$raw")"
				continue
				;;
			''|'#'*) continue ;;
		esac
		[ -n "${strat:-}" ] || continue
		want_group "$group" || continue

		tgt="$(expand_target "$tgt")"
		src_abs="$DOTFILES/$src"

		case "$strat" in
			never)
				do_never "$tgt" "${note_text:-}"
				continue
				;;
		esac

		if [ ! -e "$src_abs" ]; then
			fail "manifest row '$src' -> $(display_path "$tgt"): source file is missing from the repo" \
				"Either the file has not been committed yet or the manifest path is wrong. Nothing was written for this row; every other row still ran."
			continue
		fi

		case "$strat" in
			link) do_link "$src" "$src_abs" "$tgt" ;;
			wrap) do_wrap "$src_abs" "$tgt" ;;
			include) do_include "$src_abs" "$tgt" ;;
			append-once) do_append_once "$src_abs" "$tgt" ;;
			merge-json) do_merge_json "$src_abs" "$tgt" ;;
			*)
				fail "unknown strategy '$strat' for $src -> $(display_path "$tgt")" \
					"Valid strategies: link, wrap, include, append-once, merge-json, never."
				;;
		esac
	done 3<"$MANIFEST"
	return 0
}

phase_vim_plugins() {
	heading "vim plugins"
	local autoload="$HOME/.vim/autoload" bundle="$HOME/.vim/bundle"
	local repo dest tmp

	ensure_dir "$autoload" || return 0
	ensure_dir "$bundle" || return 0

	# pathogen is a single autoload file, not a bundle. vimrc runs
	# execute pathogen#infect(), which errors on EVERY launch without it.
	if [ -f "$autoload/pathogen.vim" ]; then
		ok "$(display_path "$autoload/pathogen.vim")"
	elif [ "$DRY_RUN" -eq 1 ]; then
		plan "fetch pathogen.vim -> $(display_path "$autoload/pathogen.vim")"
	elif ! command -v curl >/dev/null 2>&1; then
		fail "curl not found; cannot fetch pathogen" \
			"Fetch it by hand: curl -fLo ~/.vim/autoload/pathogen.vim --create-dirs $PATHOGEN_URL"
	else
		tmp="$(tmpfile)"
		if curl -fsSL "$PATHOGEN_URL" -o "$tmp" && grep -q 'pathogen#infect' "$tmp"; then
			cp "$tmp" "$autoload/pathogen.vim"
			chmod 644 "$autoload/pathogen.vim"
			changed "$(display_path "$autoload/pathogen.vim") fetched"
		else
			fail "could not download a usable pathogen.vim" \
				"Check network access, then fetch by hand: curl -fLo ~/.vim/autoload/pathogen.vim --create-dirs $PATHOGEN_URL"
		fi
	fi

	if [ ! -f "$PLUGIN_LIST" ]; then
		fail "$(display_path "$PLUGIN_LIST") not found; no bundles installed"
		return 0
	fi
	if ! command -v git >/dev/null 2>&1; then
		fail "git not found; cannot clone vim bundles" \
			"Install the Xcode Command Line Tools (xcode-select --install) and re-run."
		return 0
	fi

	while IFS= read -r repo <&4 || [ -n "${repo:-}" ]; do
		repo="${repo%%#*}"
		repo="$(printf '%s' "$repo" | tr -d '\r' | tr -d '[:space:]')"
		[ -n "$repo" ] || continue
		case "$repo" in
			*/*) ;;
			*) fail "vim/plugins.txt: '$repo' is not an owner/repo line"; continue ;;
		esac
		if printf '%s' "$repo" | grep -qv '^[A-Za-z0-9._-]\{1,\}/[A-Za-z0-9._-]\{1,\}$'; then
			fail "vim/plugins.txt: refusing to clone suspicious entry '$repo'"
			continue
		fi
		dest="$bundle/${repo##*/}"
		if [ -e "$dest" ]; then
			ok "$(display_path "$dest") (present; update it yourself with git -C pull)"
			continue
		fi
		if [ "$DRY_RUN" -eq 1 ]; then
			plan "git clone --depth 1 https://github.com/$repo -> $(display_path "$dest")"
			continue
		fi
		if git clone --quiet --depth 1 "https://github.com/$repo" "$dest" </dev/null; then
			changed "$(display_path "$dest") cloned"
		else
			fail "clone failed for $repo" \
				"Re-run: git clone --depth 1 https://github.com/$repo $(display_path "$dest"). The vimrc settings that plugin backs will silently do nothing until it is present."
		fi
	done 4<"$PLUGIN_LIST"
	return 0
}

# Vendored third-party skills: the skills CLI owns them as real directories in
# ~/.agents/skills (manifest.tsv names them under "NOT rows"), updated with
# `npx skills update`. This phase installs any that are missing, links them
# into each tool's skills dir, and installs the gh extension the gh-stack
# skill drives — the skill is inert without it.
VENDORED_SKILLS="github/gh-stack@gh-stack vercel-labs/skills@find-skills"

phase_agent_extras() {
	heading "vendored skills + gh extension"
	local spec name tool target
	for spec in $VENDORED_SKILLS; do
		name="${spec##*@}"
		if [ -d "$HOME/.agents/skills/$name" ]; then
			ok "vendored skill $name present"
		elif ! command -v npx >/dev/null 2>&1; then
			warn "npx not found; cannot install vendored skill $name"
			manual "Install node, then run: npx -y skills add $spec -g --agent codex -y"
			continue
		elif [ "$DRY_RUN" -eq 1 ]; then
			plan "npx -y skills add $spec -g --agent codex -y"
			continue
		elif npx -y skills add "$spec" -g --agent codex -y </dev/null; then
			changed "vendored skill $name installed from $spec"
		else
			fail "skills CLI could not install $name" \
				"Re-run by hand: npx -y skills add $spec -g --agent codex -y"
			continue
		fi
		for tool in claude codex; do
			target="$HOME/.$tool/skills/$name"
			if [ -e "$target" ] || [ -L "$target" ]; then
				ok "$(display_path "$target")"
			elif [ "$DRY_RUN" -eq 1 ]; then
				plan "ln -s ../../.agents/skills/$name $(display_path "$target")"
			else
				ln -s "../../.agents/skills/$name" "$target"
				changed "$(display_path "$target") -> ../../.agents/skills/$name"
			fi
		done
	done

	if ! command -v gh >/dev/null 2>&1; then
		warn "gh not found; skipping the gh-stack extension"
		manual "Install gh (it is in this repo's Brewfile), then run: gh extension install github/gh-stack"
	elif gh extension list 2>/dev/null | grep -q 'github/gh-stack'; then
		ok "gh extension gh-stack"
	elif [ "$DRY_RUN" -eq 1 ]; then
		plan "gh extension install github/gh-stack"
	elif gh extension install github/gh-stack </dev/null; then
		changed "gh extension gh-stack installed"
	else
		warn "gh extension install github/gh-stack failed (gh not authenticated?)"
		manual "Run 'gh auth login', then: gh extension install github/gh-stack"
	fi
	return 0
}

# ----------------------------------------------------------------------- main

printf '%sdotfiles install%s  repo: %s\n' "$C_BOLD" "$C_RESET" "$(display_path "$DOTFILES")"
if [ "$DRY_RUN" -eq 1 ]; then
	printf '%sdry run: nothing on disk will be modified.%s\n' "$C_YELLOW" "$C_RESET"
fi
if [ -n "$ONLY" ]; then printf 'only: %s\n' "$ONLY"; fi

# Directory creation is a prerequisite for nearly every row, so it runs for any
# group - except the two that touch no target at all.
case "$ONLY" in
	brew|never) ;;
	*) phase_dirs ;;
esac

if [ "$SKIP_BREW" -eq 1 ]; then
	heading "homebrew"
	skipped "brew bundle (--skip-brew)"
elif want_group brew; then
	phase_brew
fi

phase_manifest

if want_group agents; then
	phase_agent_extras
fi

if [ "$SKIP_VIM_PLUGINS" -eq 1 ]; then
	heading "vim plugins"
	skipped "pathogen + bundles (--skip-vim-plugins)"
elif want_group vim-plugins; then
	phase_vim_plugins
fi

# ------------------------------------------------------------------- epilogue

heading "summary"
printf '  %d ok, %d changed, %d skipped, %d failed\n' \
	"$N_OK" "$N_CHANGED" "$N_SKIPPED" "${#FAILURES[@]}"
if [ ${#BACKED_UP[@]} -gt 0 ]; then
	printf '  backups: %s\n' "$(display_path "$BACKUP_ROOT")"
fi

heading "still to do by hand"
i=1
say_step() { printf '  %d. %s\n' "$i" "$1"; i=$((i + 1)); }

say_step "Identity: put [user] name and email in ~/.gitconfig.local (included by ~/.gitconfig, never tracked). The tracked gitconfig sets neither identity nor commit signing, so nothing here fails without them - add signing in the same file if you want it."
say_step "Machine-local seams, all optional and all untracked: ~/.zshrc.local (PATH, work aliases), ~/.agents/AGENTS.local.md (claims about THIS machine's toolchain - which TeX engine, which runtime), ~/.vim/after/plugin/zz-local.vim (per-box vim overrides), ~/.ssh/config.local (real hostnames)."
say_step "Files this repo deliberately does not install (see the 'never' rows above): add Homebrew's shellenv line to ~/.zprofile yourself, and copy keys from agents/codex/config.toml into ~/.codex/config.toml by hand - Codex rewrites that file and linking it drops its state."
say_step "GUI permission grants no script can make: Ghostty and any terminal you use need Accessibility and Automation; AltTab needs Accessibility plus Screen Recording. Full walkthrough in setup.md."
say_step "Fonts and casks installed by brew only appear in apps after a restart of that app; JetBrainsMono Nerd Font is what the starship glyphs and eza icons need."
say_step "Mos (installed by Brewfile) does nothing until you launch it, grant it Accessibility, and turn on reverse scrolling in its own preferences window - vertical and horizontal are separate toggles. Its settings live in ~/Library/Preferences/com.caldis.Mos.plist, which cfprefsd owns and rewrites, so no tracked file in this repo can set them for you."
if [ ${#BACKED_UP[@]} -gt 0 ]; then
	say_step "Review what was moved aside in $(display_path "$BACKUP_ROOT") and fold anything machine-specific into the matching .local seam. Nothing was deleted."
fi
if [ ${#MANUAL[@]} -gt 0 ]; then
	for m in "${MANUAL[@]}"; do
		say_step "$m"
	done
fi
say_step "Open a new terminal (or run 'exec zsh'). ~/.zshenv and ~/.zshrc are only read by a fresh shell - in particular the eza stdin guard in ~/.zshenv, which is what keeps non-interactive and agent shells from hanging forever."

if [ ${#FAILURES[@]} -gt 0 ]; then
	printf '\n%s%d step(s) failed:%s\n' "$C_RED" "${#FAILURES[@]}" "$C_RESET" >&2
	for f in "${FAILURES[@]}"; do
		printf '  - %s\n' "$f" >&2
	done
	printf '\nEverything else was installed. Fix the above and re-run - this script is idempotent.\n' >&2
	exit 1
fi

printf '\n%sdone.%s\n' "$C_GREEN" "$C_RESET"
