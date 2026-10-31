# Troubleshooting

Symptom → likely cause → fix. Fix the local toolchain; do not "solve" a failure by calling a cloud
API. Run `scripts/env-check.ps1` first — it catches half of these before rendering.

## Toolchain

| Symptom | Cause | Fix |
|---|---|---|
| `'ffmpeg' is not recognized` | FFmpeg not on PATH (this machine: missing) | `winget install --id Gyan.FFmpeg -e`; reopen terminal; `ffmpeg -version` |
| `ffmpeg-skill doctor` reports missing `libass`, `drawtext`, `zscale`, `loudnorm`, `vidstab` | Lean/stripped FFmpeg build | Install gyan.dev **full** build and make it the first `ffmpeg.exe` on PATH |
| `pip install` fails building wheels on Python 3.14 | Too-new interpreter (3.13/3.14 lacks wheels for audio/ML deps) | Create the pipeline's venv with `py -3.12 -m venv ...`; never use 3.14 for these repos |
| `ModuleNotFoundError: kokoro_onnx` / `numpy` | Wrong interpreter or venv not activated | Run the pipeline with its own `py -3.12`; expose `PMV`/`PYTHON` env vars |
| `Playwright: Executable doesn't exist` / browser missing | No Chromium, or a different `PLAYWRIGHT_BROWSERS_PATH` | `npx playwright install chromium`; set `PLAYWRIGHT_BROWSERS_PATH=%LOCALAPPDATA%\ms-playwright` |
| `npx` tries to download packages at render time | Package not installed in that repo | `cd <repo> && npm install` once; avoid `npx -y` during rendering |
| `npm install` hangs / ETIMEDOUT | Registry blocked | `npm config set registry https://registry.npmmirror.com` |
| Long-path errors (`PathTooLongException`) | Deep node_modules/cache paths | Enable long paths (already on here); use short project roots like `C:\v\proj` |
| `cannot be loaded because running scripts is disabled` | Execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`; or `powershell -ExecutionPolicy Bypass -File script.ps1` |
| `running scripts is disabled` only for downloaded ZIP files | Mark-of-the-Web | `Get-ChildItem -Recurse | Unblock-File` |
| `bash: command not found` inside a `.sh` helper | Running bash script from cmd/PowerShell | Use Git Bash (`"C:\Program Files\Git\bin\bash.exe" qa-check.sh`), or translate the 3–4 commands by hand |
| `python3` not found in Git Bash | python.org install exposes `python`/`py` | Use `python` or `py -3.12`; alias it for the bash helper |

## Network / fetching

| Symptom | Cause | Fix |
|---|---|---|
| `git clone` → `Recv failure: Connection was reset` | GitHub blocked on this network (observed) | `.\scripts\install-pipelines.ps1` (auto mirrors + ZIP); or browser "Download ZIP" → extract to `%USERPROFILE%\video-skills\<name>` |
| ZIP download also fails | Mirror unavailable | Use a local proxy (`git config --global http.proxy http://127.0.0.1:7890`) or ask the user to download once manually |
| Hugging Face model download fails (Kokoro/whisper) | HF blocked | `$env:HF_ENDPOINT='https://hf-mirror.com'` before the first run |
| `explainer-video` TTS fails at render | Edge TTS endpoint unreachable | Re-run when online (MP3s cache), pass `--audio my.mp3`, or subtitle-only render |
| Fonts look wrong / missing in second run | Fonts fetched from CDN only on first run | Vendor fonts locally (see `environment.md` §5) |

## Rendering

| Symptom | Cause | Fix |
|---|---|---|
| Black or blank video frames | Page not ready when screenshot starts; wrong `seek(t)` unit | Wait for the page's ready flag (`window.__done`, `document.fonts.ready`); probe stills at 0/25/50/75% before the full render (`probe` / `--still`) |
| Animation stutters or motion blur looks wrong | Frame time not deterministic; subframe blending range mismatched | Render at the pipeline's native fps; use its subframe/blur settings instead of post-processing |
| Audio and video drift apart | Re-timed TTS after render; ffmpeg `-shortest` hiding mismatch | Re-render video to the final audio durations; check with `verify-output -CheckLoudness`; never trim audio alone |
| Voice too quiet/loud; music buries speech | Loudness mismatch between pipelines (−14 vs −16 LUFS) | Normalize at pack boundary: voice ≈ −16 LUFS, true peak ≤ −1 dBTP, duck music ≈ −18 dB under voice |
| `Tile` filter / contact sheet fails | FFmpeg build lacks `tile` | Use full gyan.dev build; or extract stills with `-ss` + `-frames:v 1` |
| Subtitles/captions missing glyphs | Font lacks CJK coverage in libass | Specify a CJK font file to `subtitles=...:force_style='FontName=Noto Sans SC'` and install that font or ship it |
| Output plays on PC but not on phone/social | `yuv444p`/odd dimensions/H.265 | Export H.264 High, `yuv420p`, even dimensions, AAC 48kHz, `+faststart` (`ffmpeg-skill export --preset reels`) |
| WSL render extremely slow on `/mnt/c/...` | 9P filesystem small-file overhead | Keep projects and node_modules inside the WSL filesystem (`~/projects`), copy the final MP4 out |
| paper-motion-video first run hangs | Downloading venv/Kokoro/fonts (5–10 min) | Let it finish once; pre-set `HF_ENDPOINT`; re-run only after it completes |

## Pipeline-specific

| Pipeline | Symptom | Fix |
|---|---|---|
| `claude-motion-design` | `python -m http.server` backgrounding fails | Start the server in a second terminal (or `Start-Job`), not with `&` |
| `claude-motion-design` | `fetch_assets.py` fails | Asset sources need network once; retry, or drop in your own music/SFX/logos/fonts with the same filenames |
| `code-video-showcase` | `.sh` helpers fail on Windows | Run in Git Bash; `render-segment.mjs` itself is cross-platform (`CHROME_EXE`/`FFMPEG_EXE`) |
| `khan-explainer` | `say: command not found` / no audio | macOS-only default. On Windows: `KHAN_TTS=kokoro` (untested) or render on a Mac; never call ElevenLabs |
| `paper-reel` | `reel doctor` reports missing whisper model / Kokoro | Run `bin/reel doctor` (Git Bash) and follow its printed commands; high Windows risk — WSL recommended |
| `paper-motion-video` | `pmv` says no internet / model missing | First run needs network; then `pmv check` must pass before delivery. Repo is very new — keep a fallback pipeline |
| `ffmpeg-skill` | Tool refuses with missing capability | Run `npx ffmpeg-skill doctor` and install the exact full-FFmpeg build it lists; `--dry-run` first |

## Escalation rules

1. Never retry the same failing command more than twice.
2. Capture the exact error line + command + version into `notes.md` of the project.
3. Switch to a local fallback (SAPI instead of Edge TTS; `ffmpeg-skill` export instead of a failing
   encoder; another pipeline) and tell the user what changed.
4. If an upstream repo is unmaintained/broken (e.g. `explainer-video` last commit 2026-05-27),
   pin the commit you tested in `notes.md`.
