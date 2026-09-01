---
name: memload
description: Read a session memory file and re-verify state against the codebase before continuing. Use when the user invokes /memload to resume from a prior /memdump.
argument-hint: [memory-file-path]
---

Resume from the memory file path supplied by the user. If no path was supplied, ask for one before continuing.

1. Read the memory file in full. Note the goal, the branch/PR state, what was done, what's still open, and any flagged gotchas.
2. Verify state against the current codebase before acting on the memory: check `git status`, the current branch, recent commits, and any files the memory references. Memory can be stale — trust what you observe over what was written.
3. If the memory mentions specific symbols, files, or flags, search and read the relevant sources to confirm they still exist and are in the expected state.
4. Once you've reconciled memory with reality, tell the user what you found, flag any drift from the memory, and ask what to tackle next.
