# Laptop setup

## Base tools

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install bat direnv eza fzf git-delta gnupg jq neovim ranger starship uv yt-dlp zoxide zsh-autosuggestions zsh-syntax-highlighting
brew install --cask 1password ghostty visual-studio-code font-jetbrains-mono-nerd-font
```

The shell also supports optional Bun, NVM, Google Cloud CLI, rclone, and Tectonic
installs. Its guards allow those tools to be absent.

Back up an existing destination before linking a tracked file. Use the mapping
in `README.md`; do not link entire application state directories.

## Private and machine-local setup

Never put these values or files in this repository:

- Environment files, API keys, OAuth tokens, cloud credential databases, and
  CLI authentication state.
- SSH or GPG private keys.
- Claude/Codex authentication, memories, histories, sessions, project trust,
  browser hashes, and application-generated MCP paths.
- Vim swap, undo, view, or viminfo files.

Restore secrets from a password manager or encrypted backup, then restrict local
environment files:

```sh
chmod 600 "$HOME/.env"
```

Sign in again rather than copying authentication databases:

```sh
gh auth login
gcloud auth login
aws sso login --profile PROFILE
```

Sign in to 1Password and enable its SSH agent. Complete the public Git
configuration with local identity values:

```sh
git config --global user.email "EMAIL"
git config --global user.signingkey "SSH_PUBLIC_KEY"
```

Configure rclone interactively for the `onedrive` shell alias. Recreate Goose,
GWS, and organization-specific cloud endpoints locally.

Warp settings sync is enabled on the current machine; use account sync instead
of copying its generated `settings.toml`.

## Agent configuration

`agents/AGENTS.md` is the source for shared instructions. Install it at:

- `~/.agents/AGENTS.md`
- `~/.claude/CLAUDE.md`
- `~/.codex/AGENTS.md`

Install `agents/skills/*` under `~/.agents/skills/`. Recreate the Claude
compatibility links as relative symlinks:

```sh
mkdir -p "$HOME/.claude/skills"
for skill in autopush find-skills gh-stack memdump memload pr_update; do
  ln -s "../../.agents/skills/$skill" "$HOME/.claude/skills/$skill"
done
```

Install `agents/skill-lock.json` as `~/.agents/.skill-lock.json`.
Copy `agents/claude/settings.json` to `~/.claude/settings.json`. Start
`~/.codex/config.toml` from `agents/codex/config.toml`, then let Codex add
its installation-specific marketplace paths and MCP configuration. Do not copy
`auth.json`, `settings.local.json`, databases, memories, or history.
Reconfigure local Beeper/OpenUI MCP endpoints and CodexBar provider or browser
integration after installing those applications; do not migrate their cookie,
session, or state files.

## Editors

The Vim bundle directories are third-party checkouts and are intentionally not
vendored. Install their equivalents through a plugin manager.

The Neovim configuration is staged. Before activating it, remove the legacy
Pathogen, ALE, and Airline setup inherited from `vimrc`; otherwise both plugin
systems load. Then install it as `~/.config/nvim`.

Install VS Code extensions by identifier instead of copying the generated
extension manifest:

```sh
for extension in \
  anthropic.claude-code \
  enkia.tokyo-night \
  formulahendry.code-runner \
  github.vscode-github-actions \
  github.vscode-pull-request-github \
  ms-python.python \
  ms-python.vscode-pylance \
  ms-python.vscode-python-envs \
  ms-toolsai.jupyter \
  ms-vsliveshare.vsliveshare
do
  code --install-extension "$extension"
done
```

## Pinned AltTab source build

The local build uses AltTab 10.12.0, before the later Pro subsystem and tree
restructure. This intentionally gives up later upstream work.

```sh
git clone git@github.com:lwouis/alt-tab-macos.git
cd alt-tab-macos
git switch -c pre-pro 317a485bcb090bf2b29e3f78872218f0099e1d62
```

Keep Sparkle available for manual checks, but disable automatic updates in all
three places so an existing user default cannot re-enable them:

- Set `SUEnableAutomaticChecks` to `false` in `Info.plist`.
- Set the default `updatePolicy` to `.manual` in
  `src/logic/Preferences.swift`.
- In `src/logic/events/PreferencesEvents.swift`, force both
  `automaticallyDownloadsUpdates` and `automaticallyChecksForUpdates` to
  `false`.

Select full Xcode and initialize it:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

Build the workspace; building the project directly does not resolve its CocoaPod
modules:

```sh
xcodebuild -workspace alt-tab-macos.xcworkspace \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

Ad-hoc sign, verify, and install the local build:

```sh
codesign --force --deep --sign - DerivedData/Build/Products/Debug/AltTab.app
codesign --verify --deep --strict --verbose=2 \
  DerivedData/Build/Products/Debug/AltTab.app
killall AltTab
rsync -a --delete DerivedData/Build/Products/Debug/AltTab.app/ \
  /Applications/AltTab.app/
open /Applications/AltTab.app
```

The app is not notarized, so `spctl` may reject it even when local launch works.
If macOS shows stale permissions after rebuilding, reset and re-grant them:

```sh
killall AltTab
tccutil reset ScreenCapture com.lwouis.alt-tab-macos
tccutil reset Accessibility com.lwouis.alt-tab-macos
open /Applications/AltTab.app
```

Enable AltTab again under **Privacy & Security → Screen & System Audio
Recording** and **Privacy & Security → Accessibility**. If approval is still not
detected, remove and re-add `/Applications/AltTab.app` in both lists.
