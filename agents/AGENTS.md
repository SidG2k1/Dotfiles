Use `uv` over `python3` when you can, use matplotlib/seaborn/yfinance and any other libs as needed
Do not include AI-generation branding in PR descriptions or commits
Tectonic is installed for latex
Audio transcription (local, on-device): `uv run --python 3.12 --with mlx-whisper` driving `mlx_whisper.transcribe(..., path_or_hf_repo="mlx-community/whisper-large-v3-turbo")` — Metal GPU, ~10x realtime on Apple Silicon, no cloud. Loop over files, write `.txt`+`.srt`, skip already-done for resumability. ffmpeg decodes most formats (incl. `.aac`). For speaker labels, switch to WhisperX (needs a free HF token).
When adding a personal skill under `~/.agents/skills/`, symlink that skill directory into `~/.claude/skills/` and verify both paths resolve to the same `SKILL.md`.

## Prose for Humans (PR descriptions, docs, comments, commit messages)

These apply to all prose I write for human readers — PR descriptions, markdown docs, inline comments, commit messages, Slack/chat drafts.

- **Don't duplicate source-of-truth.** If code, git log, GitHub, or a tracker owns a fact (region lists, PR tables, merged dates, status snapshots, "recently changed files"), don't restate it in prose — it will rot. Point at the SoT.
- **Document the non-obvious.** Keep rationale, constraints, and cross-cutting invariants that a competent engineer cannot derive from reading the code. Cut anything they could. Test: *"could a reader figure this out from the code in five minutes?"* If yes, drop it.
- **Delete completed-work narratives.** Active checklists and open blockers belong. Done steps do not — they become trivia. When a path goes live, remove its go-live notes.
- **Reader-priority order, not dependency order.** Lead with what's live and simple; put deferred/complicated content after. Don't organize by causal chain when the reader wants current reality first.
- **High information density.** Pick one definition; don't restate it three ways. Cut restating or hedging clauses. Asymmetric section sizes are fine — reflect reality, don't pad for symmetry.
- **Every heading earns its place.** If cutting a heading leaves the doc still answering its core question, the heading was padding. No scaffolding sections for their own sake.
- **Terse over thorough.** Bias toward shorter. Tables and bullets over paragraphs when the content is list-shaped.
