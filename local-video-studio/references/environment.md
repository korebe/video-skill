# Environment setup (Windows)

Target: one coherent toolchain that all seven pipelines can use without fighting each other.
Run `scripts/env-check.ps1` before and after setup; it reports exact versions and install hints.

## 1. Install the four core tools

```powershell
winget install --id Git.Git -e --source winget
winget install OpenJS.NodeJS.LTS
winget install Python.Python.3.12
winget install --id Gyan.FFmpeg -e --source winget
```

After installing, **open a new terminal** so PATH updates. Verify:

```powershell
git --version
node --version     # needs >= 20
python --version   # must show 3.12, not 3.13/3.14
ffmpeg -version | Select-Object -First 1
ffprobe -version | Select-Object -First 1
```

> Never upgrade a legacy Python 2.7 interpreter that another app depends on, and never make
> Python 3.14 the interpreter for these pipelines. Python 3.13/3.14 has no wheels for Kokoro/whisper/audio stacks yet.

## 2. FFmpeg must be a *full* build

`ffmpeg-skill` is the strictest consumer: FFmpeg **5.0+** with `libx264`, `aac`, `drawtext`,
`subtitles`/libass, `zscale`, `loudnorm`, `xfade`, `scdet`, `vidstab*`. Lean builds (some Homebrew
or winget defaults) lack several. The gyan.dev "full" build satisfies it.

Smoke test right after install (this is the pack-wide FFmpeg check):

```powershell
npx -y ffmpeg-skill doctor
```

Or check filters directly:

```powershell
ffmpeg -hide_banner -filters | Select-String 'drawtext|subtitles|loudnorm|xfade|scdet|vidstab|zscale'
ffmpeg -hide_banner -encoders | Select-String 'libx264|aac'
```

## 3. Python policy: one venv per pipeline, never one shared interpreter

| Pipeline | Python need | How |
|---|---|---|
| `claude-motion-design` | 3.10–3.12 + playwright, imageio-ffmpeg, numpy, pillow | `py -3.12 -m pip install playwright imageio-ffmpeg numpy pillow` |
| `code-video-showcase` | 3.10+ + numpy, scipy | `py -3.12 -m pip install numpy scipy` |
| `paper-reel` | Kokoro ONNX capable (`kokoro-onnx`) | own venv: `py -3.12 -m venv %USERPROFILE%\video-skills\.venv\paper-reel` |
| `paper-motion-video` | 3.10–3.12 private venv (auto-created) | `pmv.cmd` manages it in `~/.cache/paper-motion-video` |
| `ffmpeg-skill` | 3.9+ **stdlib only** | nothing to install |

Principles:

- Use `py -3.12` explicitly in every command; `python` may resolve to 3.14 (or a legacy 2.7 from another app).
- Expose per-skill variables instead of polluting PATH:
  `$env:PYTHON='C:\...\python.exe'`, `$env:PMV='...\tools\pmv.cmd'`, `$env:REEL='...\bin\reel'`.
- If a repo's `requirements.txt` fails on 3.14, create its venv with 3.12 rather than fixing code.
- `ffmpeg-skill` needs no pip packages — if it asks for one, you are in the wrong docs.

## 4. Playwright: install Chromium once, share it

Four pipelines bundle Playwright (`claude-motion-design`, `code-video-showcase`, `explainer-video`,
`paper-reel`/`khan-explainer`). Stop each one from downloading its own Chromium:

```powershell
$env:PLAYWRIGHT_BROWSERS_PATH = "$env:LOCALAPPDATA\ms-playwright"   # already the default here
npm i -g playwright
npx playwright install chromium
```

- Keep that env var in the user environment for future shells:
  `[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', "$env:LOCALAPPDATA\ms-playwright", 'User')`
- Per-repo `npm install` still installs the *library*; it is the browser binary that is shared.
- `code-video-showcase` also honours `CHROME_EXE` (point it at
  `C:\Program Files\Google\Chrome\Application\chrome.exe` or Edge
  `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`).
- A Playwright cache typically already contains `chromium-1234` and `chromium_headless_shell-1234`.

## 5. Fonts: vendor them, do not trust the network at render time

Headless Chromium only has system fonts, and CJK glyphs are the usual "tofu" failure.

- Download OFL fonts once into the project (not the system): Noto Sans SC (思源黑体), Noto Serif SC
  (思源宋体), Inter, and one handwriting face if a papercut/whiteboard style needs it.
- `code-video-showcase`: fonts are **not bundled** — put files in the project and reference them in
  `shared/fonts.css` via `@font-face` with local paths.
- `explainer-video`: GSAP comes from jsdelivr on every render — download `gsap.min.js` once,
  put it next to the HTML, and change the `<script src>` to the local file.
- `paper-motion-video`: fetches Google Fonts/cdnjs on first run only; afterwards it is offline.
- Verify: render one still with Chinese text and inspect it before rendering the full video.

## 6. GitHub is blocked on this network — mirror strategy

`git clone https://github.com/...` currently fails with `Recv failure: Connection was reset`.
`install-pipelines.ps1` handles it: direct → `ghproxy.net` → `gitclone.com` → `kkgithub.com` →
ZIP archive download. Manual equivalents:

```powershell
# Option A: mirror prefix (works for many networks in China)
git clone https://ghproxy.net/https://github.com/howseen-ai/claude-motion-design.git

# Option B: alternate host
git clone https://gitclone.com/github.com/howseen-ai/claude-motion-design.git

# Option C: browser ZIP (most reliable when git is blocked)
#   open the repo page in a browser -> Code -> Download ZIP -> extract into %USERPROFILE%\video-skills\<name>
```

Package managers usually still work through domestic mirrors:

```powershell
npm config set registry https://registry.npmmirror.com
py -3.12 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
$env:HF_ENDPOINT = 'https://hf-mirror.com'     # Kokoro/whisper model downloads (Hugging Face)
```

- `git` proxy: `git config --global http.proxy http://127.0.0.1:7890` if a local proxy exists.
- `install-pipelines.ps1 -Mirror https://ghproxy.net/` forces a prefix; `-NoMirrors` disables the
  built-in list; `-NoZipFallback` disables archive fallback.
- First-run downloads that need the network: Kokoro models, whisper.cpp model, paper-motion-video
  venv+fonts, Playwright Chromium, npm/pip packages. Pre-fetch them while the network is good.

## 7. Shell policy (Windows quirks)

- Seven repos, three script dialects: bash (`.sh`, `bin/reel`), cmd/PowerShell (`pmv.cmd`, copy
  lines), and plain Node/Python. Git for Windows provides `bash.exe`; run bash helpers from
  "Git Bash" or `bash script.sh` rather than cmd.
- `python3` in Git Bash often does not exist for python.org installs — use `python` or `py -3.12`.
- Execution policy: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (once). ZIP-downloaded
  scripts get the Mark-of-the-Web; unblock before running: `Get-ChildItem -Recurse | Unblock-File`.
- Enable long paths on Windows and keep project paths under ~180 chars anyway
  (paper-motion-video caches deep under `~/.cache`).
- `pwsh` is not installed here; Windows PowerShell 5.1 runs these scripts fine. Prefer
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\<name>.ps1`.

## 8. TTS / voice matrix (decide before rendering)

| Engine | Runs offline | Chinese | Where used | Notes |
|---|---|---|---|---|
| Windows SAPI (`SAPI.SpVoice`) | ✅ | ✅ (installed voices) | fallback for any pipeline; live demo of a script | robotic but zero dependencies |
| Kokoro ONNX / Kokoro-82M | ✅ after model download | mostly English | `paper-reel`, `paper-motion-video`, `khan-explainer` (`KHAN_TTS=kokoro`) | best quality/offline ratio; English-first |
| Edge TTS (`msedge-tts`) | ❌ needs Microsoft endpoint | ✅ excellent | `explainer-video` | no key, but network; cache MP3s in `~/.cache/explainer-video/voice` |
| macOS `say` | ✅ | ✅ | `khan-explainer` default | not available on Windows |
| ElevenLabs | ❌ | ✅ | optional in `khan-explainer` | external API key — **do not use in this pack** |
| User-recorded voice | ✅ | ✅ | any pipeline with `--audio` | best quality; use `verify-output -CheckLoudness` after mix |

## 9. Acceptance checklist for the environment

- `scripts/env-check.ps1 -Strict` → no BLOCKER lines.
- `npx ffmpeg-skill doctor` → all required capabilities present.
- Playwright: one `chromium-*` folder under `%LOCALAPPDATA%\ms-playwright`, usable by every skill.
- Python: `py -3.12 --version` works; `py -3.14 -c "import kokoro_onnx"` is not required.
- Fonts: a test HTML with 中文 + English renders without tofu.
- A 3-second local test render with voice succeeds before the real project starts.




