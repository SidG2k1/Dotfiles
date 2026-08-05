# Audio transcription (local, on-device)

Reference material, not loaded every session. Pointed at from `AGENTS.md`.

Requires Apple Silicon (mlx runs on Metal) and `ffmpeg` on PATH. Nothing leaves the
machine. `whisper-large-v3-turbo` runs roughly 10x realtime; the model downloads
to the Hugging Face cache on first use.

## One file

```sh
uv run --python 3.12 --with mlx-whisper python - "$1" <<'PY'
import sys, mlx_whisper
r = mlx_whisper.transcribe(sys.argv[1],
                           path_or_hf_repo="mlx-community/whisper-large-v3-turbo")
print(r["text"])
PY
```

## A directory, resumably

Write `.txt` and `.srt` next to each input and skip inputs whose `.txt` already
exists, so an interrupted run resumes instead of restarting. `ffmpeg` handles most
containers, `.aac` included, so no pre-conversion step is needed.

```sh
uv run --python 3.12 --with mlx-whisper python - "$@" <<'PY'
import sys, pathlib, mlx_whisper

REPO = "mlx-community/whisper-large-v3-turbo"

def srt_time(t):                          # integer ms: no 00:00:60,000 rounding
    ms = round(float(t) * 1000)
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

for arg in sys.argv[1:]:
    for src in sorted(pathlib.Path(arg).rglob("*") if pathlib.Path(arg).is_dir()
                      else [pathlib.Path(arg)]):
        if src.is_dir() or src.suffix in {".txt", ".srt"}:
            continue
        txt, srt = src.with_suffix(".txt"), src.with_suffix(".srt")
        if txt.exists():                      # resumability
            print(f"skip {src.name}")
            continue
        print(f"transcribe {src.name}", flush=True)
        try:
            r = mlx_whisper.transcribe(str(src), path_or_hf_repo=REPO)
        except Exception as e:                # unreadable/non-audio file
            print(f"  failed: {e}")
            continue
        txt.write_text(r["text"].strip() + "\n")
        srt.write_text("".join(
            f"{i}\n{srt_time(seg['start'])} --> {srt_time(seg['end'])}\n"
            f"{seg['text'].strip()}\n\n"
            for i, seg in enumerate(r["segments"], 1)))
PY
```

## Speaker labels

mlx-whisper does not diarize. For "who said what", switch to WhisperX, which needs
a (free) Hugging Face token for the diarization model. Read the token from the
environment or a keychain entry — never write one into a file in this repo.
