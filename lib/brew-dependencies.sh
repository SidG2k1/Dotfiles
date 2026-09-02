#!/usr/bin/env bash

# Shared Brewfile probes. Configs care whether a dependency works, while
# Homebrew Bundle cares whether Homebrew owns it; callers use both answers.

brew_prefix() {
	if [ -n "${HOMEBREW_PREFIX:-}" ]; then
		printf '%s' "$HOMEBREW_PREFIX"
	elif command -v brew >/dev/null 2>&1; then
		brew --prefix 2>/dev/null || printf '/opt/homebrew'
	else
		printf '/opt/homebrew'
	fi
}

cask_present() {
	local name=$1 pfx=$2 artifact token=${1##*/}
	[ -d "$pfx/Caskroom/$token" ] && return 0
	command -v brew >/dev/null 2>&1 || return 1

	while IFS= read -r artifact; do
		[ -n "$artifact" ] || continue
		case $artifact in
			/*) [ -e "$artifact" ] && return 0 ;;
			*)
				if [ -e "/Applications/$artifact" ] || [ -e "$HOME/Applications/$artifact" ]; then
					return 0
				fi
				;;
		esac
	done < <(
		HOMEBREW_NO_AUTO_UPDATE=1 brew info --cask --json=v2 "$name" 2>/dev/null |
			HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_DEVELOPER=1 brew ruby -rjson -e '
				cask = Array(JSON.parse(STDIN.read)["casks"]).first || {}
				Array(cask["artifacts"]).grep(Hash).each do |item|
					paths = [item["target"], Array(item["app"]).first, Array(item["font"]).first]
					binary = Array(item["binary"]); paths << (binary[1] || binary[0])
					paths.compact.each { |path| puts path }
				end
			' 2>/dev/null
	)
	return 1
}

pkg_present() {
	local kind=$1 name=$2 pfx token
	pfx=$(brew_prefix)
	token=${name##*/}
	case $token in
		git-delta) command -v delta >/dev/null 2>&1 ;;
		ripgrep) command -v rg >/dev/null 2>&1 ;;
		zsh-autosuggestions)
			[ -f "$pfx/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] ;;
		zsh-syntax-highlighting)
			[ -f "$pfx/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] ;;
		*)
			if [ "$kind" = cask ]; then
				cask_present "$name" "$pfx"
			else
				command -v "$token" >/dev/null 2>&1
			fi
			;;
	esac
}

pkg_homebrew_owned() {
	local kind=$1 name=$2 pfx token
	command -v brew >/dev/null 2>&1 || return 1
	pfx=$(brew_prefix)
	token=${name##*/}
	if [ "$kind" = cask ]; then
		[ -d "$pfx/Caskroom/$token" ]
	else
		HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula "$name" >/dev/null 2>&1
	fi
}

brewfile_entries() {
	awk '
		/^[[:space:]]*(brew|cask)[[:space:]]+"/ {
			kind = $1
			name = $0; sub(/^[^"]*"/, "", name); sub(/".*$/, "", name)
			printf "%s\t%s\n", kind, name
		}
	' "$1"
}

external_brewfile_entries() {
	local brewfile=$1 kind name
	while IFS=$'\t' read -r kind name; do
		[ -n "${name:-}" ] || continue
		if pkg_present "$kind" "$name" && ! pkg_homebrew_owned "$kind" "$name"; then
			printf '%s\t%s\n' "$kind" "$name"
		fi
	done < <(brewfile_entries "$brewfile")
}
