# dotfiles

Public, credential-free configuration for a macOS (Apple Silicon) development
laptop: zsh with vi mode, vim with native packages, Ghostty, starship, and the Claude
Code / Codex agent setup. No identity, keys, tokens, hostnames, or absolute
`/Users/...` paths are tracked here — those live in machine-local files this repo
deliberately does not own (see [Machine-local layer](#machine-local-layer)).
Everything degrades gracefully: a missing tool costs a feature, never `ls`,
`cat`, `cd`, `git`, or shell startup.

## Quick start

```sh
git clone https://github.com/SidG2k1/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh                         # idempotent; --dry-run prints the plan
bin/dotfiles-doctor                  # verifies every install landed + deps resolve
```

`install.sh` runs `brew bundle --file=Brewfile` itself (`--skip-brew` opts out);
the per-feature extras in `Brewfile.optional` are the one dependency step it
leaves to you. Beyond that it reads `manifest.tsv` and nothing else. Re-running
it is safe. It never overwrites a file it does not own — see the strategies below
for why that distinction exists.

Then do the parts a script cannot: `setup.md`.

## Install strategies

"Install a dotfile" is not one operation. Some targets the repo can own
outright; others are actively rewritten by the tool that reads them, or carry
machine identity that a symlink would destroy. Picking the wrong strategy is how
dotfiles repos silently eat a working machine's config.

| Strategy | Mechanism | Use when |
| --- | --- | --- |
| `link` | symlink target → repo file | the repo owns the file outright and no tool writes to it (`vimrc`, `starship.toml`) |
| `wrap` | target is a stub that sources the repo file, then `~/*.local` | the config needs a per-machine tail (`~/.zshrc`) |
| `include` | repo file pulled in via the tool's own include directive; target stays user-owned | the target holds identity or tool-written blocks (`~/.gitconfig`, and its `[filter "lfs"]`) |
| `append-once` | marker-delimited block (`# >>> dotfiles` … `# <<< dotfiles`), rewritten in place | the tool and the human both edit the same file (`~/.config/ghostty/config`) |
| `merge-json` | `jq` merge of the tracked key subset | the app writes the file from its own UI (`~/.claude/settings.json`, VS Code, Docker) |
| `never` | not installed; the note records who owns the target | another tool's installer owns it and regenerates it on upgrade (`~/.zprofile`, `~/.profile`) |

**`manifest.tsv` is the single source of truth** for which file goes where, under
which strategy, and what breaks if the strategy is wrong. This README does not
duplicate that list — read the manifest. It also records what is deliberately
*not* installed, and why.

## Machine-local layer

Rule of thumb: **if a statement could be false on another machine, it goes in a
`.local` file.** Machine truth is not portable config, and asserting it in a
tracked file is worse than omitting it — a fresh machine then inherits a
confident lie (an agent hunting for a TeX engine that isn't installed, a commit
signed by a key that doesn't exist).

Every seam is untracked, optional, and absent-safe.

| Seam file | Pulled in by | Holds |
| --- | --- | --- |
| `~/.zshrc.local` | the repo `zshrc`, sourced as its last line | machine PATH entries, work aliases, anything secret-adjacent |
| `~/.zshenv.local` | `~/.zshenv`, sourced last | the rare thing *every* zsh needs, scripts included — a PATH entry a script must see, proxy vars. Keep it fast; it runs on every zsh start |
| `~/.gitconfig.local` | `[include]` in `~/.gitconfig` | identity: name, email, signing key |
| `~/.ssh/config.local` | `Include` in your own `~/.ssh/config` | per-host blocks — real hostnames never enter this repo |
| `~/.vim/after/plugin/zz-local.vim` | vim's `after/plugin` load path | per-box overrides that must win over plugin defaults |
| `~/.agents/AGENTS.local.md` | agents read it alongside `~/.agents/AGENTS.md` | claims about *this* machine's toolchain |
| `~/.agents/skills.local/<name>/SKILL.md` | symlinked into `~/.claude/skills/` and `~/.codex/skills/`, the same shape the tracked skills use | personal skills that name an internal host or a private service, so they cannot go in `agents/skills/` — see `~/.claude/skills/README.md` |

```sh
# ~/.zshrc.local
alias deploy='…'

# ~/.zshenv.local
export PATH="$HOME/.cargo/bin:$PATH"

# ~/.gitconfig.local
[user]
	email = <you@your-domain>
# Commit signing, if you use it, is configured here too - the tracked gitconfig
# sets none, because the signer path and key are machine-specific.

# ~/.ssh/config.local
Host build
	HostName <internal-host>
	User <user>

# ~/.vim/after/plugin/zz-local.vim
let g:ale_c_cc_executable = 'gcc-15'   " no clang on this box
let g:dotfiles_author = 'Your Name'    " fills {{AUTHOR}} in vim/templates/*

# ~/.agents/AGENTS.local.md
Tectonic is installed for latex.
```

## External dependencies

`Brewfile` is annotated per package with what it backs and what degrades without
it; `Brewfile.optional` is the per-feature extras; `vim/plugins.txt` is the same
for vim. `bin/dotfiles-doctor` reports what is missing, and the troubleshooting
table in `setup.md` covers the failures that do not name their cause — a vim
whose plugin features are silently inert, or `eza` hanging in a non-TTY shell.

## Safety

- **`.gitignore` is an allowlist**: ignore everything, then re-include the
  specific tracked paths. A denylist of patterns only blocks the leaks you
  already thought of; the failure mode is a file you never meant to add
  arriving because it matched nothing.
- **gitleaks runs in CI** over the working tree and history on every push, so a
  credential cannot land unnoticed even if the allowlist is widened by mistake.
- **Identity is deliberately absent.** `gitconfig` carries no email and no
  signing key; they live in `~/.gitconfig.local`, which is included but never
  tracked. Commit signing therefore does nothing until you create that file.
- Never copy whole application state directories in. Auth databases, histories,
  sessions, and project-trust files are excluded on purpose — re-authenticate
  instead of migrating them.
