# Personal skills — layout, linking, and porting between tools

One copy of this file, symlinked into `~/.claude/skills/README.md` and `~/.codex/skills/README.md`,
the same way `~/.agents/AGENTS.md` feeds both tools' instruction files.

Nothing in either skills directory should be a real file. Every entry is a symlink into `~/.agents/`,
so a skill is edited in one place and adopted by a tool by adding one link.

## Two layers

The only difference is whether the real content sits in the public dotfiles repo.

**Portable** — `github.com/SidG2k1/Dotfiles` is public, so this layer must name no internal host.

```
~/dotfiles/agents/skills/<name>/SKILL.md                                     # committed
~/.agents/skills/<name>  -> /Users/sid.gupta/dotfiles/agents/skills/<name>      (absolute)
~/.claude/skills/<name>  -> ../../.agents/skills/<name>                         (relative)
~/.codex/skills/<name>   -> ../../.agents/skills/<name>                         (relative)
```

**Local-only** — for anything naming internal infrastructure, a private host, or a fact that could be
false on another machine.

```
~/.agents/skills.local/<name>/SKILL.md                       # untracked, never committed
~/.claude/skills/<name>  -> ../../.agents/skills.local/<name>
~/.codex/skills/<name>   -> ../../.agents/skills.local/<name>
```

`skills.local/` is a seam in the dotfiles machine-local layer alongside `~/.zshrc.local` and
`~/.agents/AGENTS.local.md` — see **Machine-local layer** in `~/dotfiles/README.md`. Its test: *if a
statement could be false on another machine, it goes in a `.local` file.* The naming carries the
signal — a real directory under `skills.local/` is deliberate; a real directory under
`~/.agents/skills/` or in a tool's skills dir is a mistake.

## Adding one

```bash
# local-only
mkdir -p ~/.agents/skills.local/<name>            # author SKILL.md here
ln -s ../../.agents/skills.local/<name> ~/.claude/skills/<name>
ln -s ../../.agents/skills.local/<name> ~/.codex/skills/<name>

# portable
mkdir -p ~/dotfiles/agents/skills/<name>
ln -s /Users/sid.gupta/dotfiles/agents/skills/<name> ~/.agents/skills/<name>
ln -s ../../.agents/skills/<name> ~/.claude/skills/<name>
ln -s ../../.agents/skills/<name> ~/.codex/skills/<name>
```

Both layers link every tool. Linking only one is what leaves a skill working in one harness and
absent in the other — and Codex is the easy one to forget, because `~/.codex/skills/` also holds
`.system/`, so it never looks empty.

Portable takes two more steps, because dotfiles tracks by allowlist and installs by manifest:

1. a `!/agents/skills/<name>/SKILL.md` line in `~/dotfiles/.gitignore` — without it `git add` refuses
   and `git status` stays silent, so the skill is live here and backed up nowhere
2. three rows in `~/dotfiles/manifest.tsv`, one per link target — what `install.sh` replays to rebuild
   the links on a new machine

Skip either and the skill works on this machine and vanishes on the next.

Verify the paths land on one file rather than merely existing — a dangling link fails silently and the
skill just never appears:

```bash
stat -L -f %i ~/.agents/skills{,.local}/<name>/SKILL.md \
              ~/.{claude,codex}/skills/<name>/SKILL.md 2>/dev/null
```

`-L` matters: without it macOS `stat` reports the symlink's own inode, so identical files look
different and you chase a problem that isn't there.

## Porting a skill between Claude Code and Codex

The shared shape is real: both discover `<name>/SKILL.md` under their skills directory, both parse YAML
frontmatter with `name` and `description`, and both use sibling `scripts/`, `references/`, `assets/`,
`agents/` directories for bundled resources. Most skills move by symlink alone, which is why the local
layer points both tools at one file.

What is not shared is frontmatter keys. Unknown keys are ignored rather than fatal, so a skill carrying
another tool's keys still loads — it just silently loses that behavior.

| Key | Honored by | Effect |
| --- | --- | --- |
| `name`, `description` | both | discovery and match |
| `metadata.short-description` | Codex | short label; Claude Code ignores it |
| `disable-model-invocation` | Claude Code | hides it from the model, leaving `/<name>` for you to type |
| `argument-hint` | Claude Code | argument hint on the slash command |
| `allowed-tools` | Claude Code | tool grant for the skill |

Two cautions when bringing in a skill written for another tool:

- **Shell-exec markers are live in Claude Code.** A `` !`cmd` `` or a ```` ```! ```` fence executes on
  load. In tools that treat those as plain text they are inert, so a skill can carry one harmlessly and
  then run it here. Read the body before linking a skill you did not write.
- **Oversized `SKILL.md` is skipped, not truncated.** Claude Code drops a skill whose file exceeds its
  size ceiling, so a large ported skill can go quiet with no error. Split detail into `references/`.

`~/.codex/skills/.system/` is Codex's own managed set (`skill-creator`, `review-agent`, `openai-docs`, …).
Leave it alone; personal skills go beside it, not inside it.

## Three things that look broken but aren't

**A skill missing from the model's list.** `disable-model-invocation: true` hides it from the listing
the model sees while leaving `/<name>` working. Check frontmatter before debugging the link.

**A skill in `~/dotfiles/agents/skills/` with no link anywhere.** Vendored third-party skills are
deliberately unlinked — the skills CLI updates them from upstream and symlinking the vendored copy
would pin a stale snapshot. `~/dotfiles/manifest.tsv` names them under *"NOT rows in this manifest, on
purpose"*. Do not link them to close the gap.

**No off-machine copy of the local layer.** Accepted, not overlooked: the alternative puts internal
hostnames in a repo on an external account, and a skill here is a few KB — quicker to re-author than to
sync safely. `~/.agents/skills.local/` has local git history for undo. Do not add a remote without
deciding that question again.
