# profile — REFERENCE ONLY. The installer does not install this file.
#
# manifest.tsv marks the ~/.profile target `never`, for the same reason as
# zprofile: installer-generated env hooks live there and are regenerated on
# upgrade, so overwriting the file silently removes working integrations. The one
# line below is itself such a hook - `uv` / the rust-toolchain installers write it
# - which is exactly the point.
#
# ~/.profile is read by sh and bash LOGIN shells. zsh never reads it, so on this
# machine it only matters inside `sh -l` / `bash -l` (some IDEs, some remote
# tooling, some launchd wrappers). Keep it POSIX sh: no zsh syntax here.
#
# The guard matters because ~/.local/bin/env only exists after uv (or another
# installer that ships it) has run; an unguarded `.` on a missing file aborts the
# rest of the login profile.
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
