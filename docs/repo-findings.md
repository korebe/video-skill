# Local video production skill pack — repo findings

Research date: **2026-10-31**. Method: GitHub REST API (metadata) + raw `README.md` fetches. No clones, no installs.
All 7 clue owner/repo pairs resolved on the first try — **0 `UNVERIFIED`, 0 canonical-URL mismatches**.

## Summary table

| # | project | URL | verified | stack | offline? | Windows risk |
|---|---------|-----|----------|-------|----------|--------------|
| 1 | claude-motion-design | https://github.com/howseen-ai/claude-motion-design | ✅ | Python + Playwright/Chromium + ffmpeg + numpy (HTML/Canvas `seek(t)`) | ✅ after asset fetch | Medium — bash-isms in README, no Windows section |
| 2 | code-video-showcase | https://github.com/Moessif/code-video-showcase | ✅ | Node ≥20 + Playwright + FFmpeg + Python 3.10 numpy/scipy (Canvas/SVG/Three.js) | ✅ after deps + fonts | Low–Medium — Edge fallback documented, but helper scripts are bash |
| 3 | explainer-video | https://github.com/Mng-dev-ai/explainer-video | ✅ | Node + Playwright + `msedge-tts` + ffmpeg (GSAP from CDN) | ❌ needs network for TTS | Low — choco ffmpeg documented |
| 4 | paper-reel | https://github.com/haiderfarooq3/paper-reel | ✅ | Node ≥18 + Playwright + ffmpeg + whisper.cpp + Kokoro ONNX (Python) | ✅ after models | **High** — macOS-only per README (`brew`, bash CLI) |
| 5 | khan-explainer | https://github.com/haiderfarooq3/khan-explainer | ✅ | Node ≥20 + Playwright + ffmpeg + macOS `say` (Kokoro/ElevenLabs optional) | ✅ with `say` | **High** — `say` is macOS-only |
| 6 | paper-motion-video | https://github.com/DjoFE2021/paper-motion-video | ✅ | Python 3.10–3.12 + Kokoro TTS + Playwright/Chrome + ffmpeg (imageio) | ✅ after first run | Low — ships `pmv.cmd`, "Windows" in requirements |
| 7 | ffmpeg-skill | https://github.com/kajisho5/ffmpeg-skill | ✅ | Python 3.9+ stdlib + FFmpeg/ffprobe + optional MCP server (Node 16+ only for installer) | ✅ fully | Low — `winget`, Windows CI job |

---

## 1. claude-motion-design

- **Canonical / clone:** https://github.com/howseen-ai/claude-motion-design · `https://github.com/howseen-ai/claude-motion-design.git`
- **What it is:** A Claude Code *skill* for making motion-design films in pure code: every frame is computed from time in an HTML/Canvas `seek(t)` page, screenshotted by Playwright, blended for subframe motion blur, and cut to a beat map.
- **Stack/type:** Python render + audio scripts (`render.py`, `audio.py`), HTML/JS animation pages, Playwright (Chromium), ffmpeg, `imageio-ffmpeg`, numpy, Pillow. Skill folder `skill/motion-design/`.
- **Install (from README):**
  ```bash
  mkdir -p ~/.claude/skills && cp -r skill/motion-design ~/.claude/skills/
  pip install playwright imageio-ffmpeg numpy pillow && python -m playwright install chromium
  ```
- **Run:** `/motion-design` in Claude Code, or drive the shipped example:
  ```bash
  cd examples/howseen-launch
  python fetch_assets.py              # downloads music/SFX/logos/font
  python -m http.server 8000 &
  python render.py probe 1 8 15 20    # stills -> probe/sheet.png
  python render.py full               # 24 s, 60 fps -> out/video.mp4
  python audio.py                     # -> out/audio.wav (-14 LUFS)
  ffmpeg -i out/video.mp4 -i out/audio.wav -map 0:v -map 1:a -c:v libx264 -crf 16 -c:a aac -shortest out/final.mp4
  ```
- **Inputs/outputs:** inputs = a brief/brand folder + `facts.md`; output = `out/video.mp4` + `out/audio.wav` → muxed `out/final.mp4`. Also `render.py draft` (540p) and a `remake` mode.
- **Demo:** `examples/howseen-launch` (24 s Howseen launch video, source included); `examples/howseen-launch/preview.gif`.
- **External API:** none. No TTS at all — it is a b-roll/motion-graphics skill with music + SFX only. Network is needed at **setup** only (`fetch_assets.py` pulls Mixkit/Pexels/Unsplash/svgl assets; pip + `playwright install chromium`).
- **Offline:** ✅ after `fetch_assets.py` has run once and Chromium/deps are cached. Nothing calls out during render.
- **Windows notes:** README assumes a POSIX shell — `mkdir -p`, `cp -r`, `python -m http.server 8000 &` (Unix background). No Windows/`say`/bash-script dependency in the pipeline itself, so the Python entry points should run on Windows (inferred), but paths in `~/.claude/skills` and the `&` backgrounding need translation. `ffmpeg` must be resolvable (imageio-ffmpeg ships a binary, exact resolution path unverified).
- **Metadata:** ⭐ 738 · forks 98 · MIT · created 2026-09-27 · last commit 2026-10-02 · branch `main` · not archived.

## 2. code-video-showcase

- **Canonical / clone:** https://github.com/Moessif/code-video-showcase · `https://github.com/Moessif/code-video-showcase.git`
- **What it is:** An Agent Skill that packages a *production recipe* for 30–90 s beat-synced "style showcase" films — an 8 s opening, N × 4 s rounds (1 s big card + 3 s style segment), an eight-flash montage, a 6 s ending — with the visuals drawn per frame in HTML/Canvas/SVG/Three.js and the score synthesized in numpy/scipy.
- **Stack/type:** Node ≥20 + `playwright` (or `playwright-core`), FFmpeg/ffprobe (libx264, AAC, `image2pipe`, `tile`, `showspectrumpic`), Python ≥3.10 + numpy + scipy. Bilingual README; `SKILL.md` is in Chinese and is authoritative.
- **Install:** `git clone … ~/.dsh/skills/code-video-showcase` (or `~/.claude/skills/`, `.agents/skills/`), then per project:
  ```bash
  mkdir -p my-showcase/{segments,shared,fonts,audio,out}
  cp templates/* my-showcase/ && cp scripts/* my-showcase/
  (cd my-showcase && npm i playwright)
  ```
  Fonts are **not bundled** — you must download OFL fonts yourself into `shared/fonts.css`.
- **Run:**
  ```bash
  node render-segment.mjs --page /segments/01.html?theme=aqua-morandi --still 0.2,0.8,1.4,2.0,2.6 --outdir out/stills
  node render-segment.mjs --page /segments/01.html?theme=aqua-morandi --out out/01.mp4 --duration 3
  ./qa-check.sh out 30
  python3 synth_audio.py --out audio/demo.wav
  ./concat-and-encode.sh segments.txt audio/mix.wav out/final.mp4
  ```
- **Inputs/outputs:** `segments.txt` concat list + `audio/mix.wav` → 1920×1080 / 30 fps / H.264 yuv420p + 48 kHz AAC 192 k, default 61.0 s = **1830 frames**, ~26 MB. Env vars: `CHROME_EXE`, `FFMPEG_EXE`, `FFMPEG`, `FFPROBE`, `VIDEO_BITRATE`, `AUDIO_BITRATE`, `PYTHON`.
- **Demo:** explicitly **no finished demo video**. `assets/` holds a 1 fps contact sheet, style/card tiles and a spectrogram of the 61 s reference film; `synth_audio.py` runs an 8 s audio demo out of the box.
- **External API:** none — no generative models, no CDN at render time (fonts/KaTeX/Three.js must be same-origin). Setup network: npm + Playwright Chromium + your own font downloads.
- **Offline:** ✅ after `npm i playwright`, a Chromium, FFmpeg and local fonts are in place.
- **Windows notes:** best-documented of the set — "**Windows**: the renderer tries `CHROME_EXE` if set, then Playwright's bundled Chromium, then Edge (`channel: 'msedge'`)". Blockers: `qa-check.sh` / `concat-and-encode.sh` / `analyze-reference.sh` are bash (Git Bash or WSL), `cp`/`mkdir -p` in the quick start, and `python3` naming.
- **Metadata:** ⭐ 241 · forks 17 · MIT · created 2026-10-24 · last commit 2026-10-28 · `main` · not archived.

## 3. explainer-video

- **Canonical / clone:** https://github.com/Mng-dev-ai/explainer-video · `https://github.com/Mng-dev-ai/explainer-video.git`
- **What it is:** A SKILL.md-spec skill where the agent writes a fresh HTML/CSS/GSAP animation page per topic, the pipeline generates a free Edge-TTS voiceover per script segment, records the page in headless Chromium, and muxes audio with ffmpeg into one MP4.
- **Stack/type:** Node (CommonJS, `lib/pipeline.js` orchestrator) + **Playwright** + **`msedge-tts`** (see `lib/package.json`: `{"msedge-tts": "^2.0.5", "playwright": "^1.40.0"}`) + ffmpeg on PATH. GSAP loaded from **jsdelivr** inside the page.
- **Install:**
  ```bash
  git clone https://github.com/Mng-dev-ai/explainer-video.git ~/.claude/skills/explainer-video
  cd ~/.claude/skills/explainer-video/lib && npm install --silent
  ```
  (Codex → `~/.codex/skills/`, Cursor → `.cursor/skills/`, universal → `~/.agents/skills/` + symlinks.) ffmpeg: `brew` / `apt` / **`choco install ffmpeg`** on Windows.
- **Run:**
  ```bash
  node lib/pipeline.js --config config.json --out video.mp4
  # or: node lib/pipeline.js --html page.html --script script.txt --voice brian --out video.mp4
  ```
  Config JSON fields: `title`, `voice`, `html`, `scriptSegments[]`. Page contract: 1280×720 viewport, read `window.__AUDIO_DURATION` / `window.__SEGMENT_DURATIONS`, set `window.__done = true`.
- **Inputs/outputs:** one narration script + one animation HTML → MP4 (1280×720). Cached voice MP3s at `~/.cache/explainer-video/voice/<sha256(voice+text)>.mp3`.
- **Demo:** `demo.mp4` in repo, self-generated; reference page `examples/quantum.html`. Voices: `brian` (default), `adam`, `rachel`, `sarah`, `antoni`, `emma`, `ryan`, `sonia`, or any Azure neural voice id.
- **External API:** **yes — network service required.** Edge TTS hits Microsoft's endpoint per segment (no key, no account, but internet). Also GSAP is fetched from jsdelivr at render time. Escape hatch: `--audio my-voice.mp3` bypasses TTS entirely, and cached MP3s make re-renders offline for the same script.
- **Offline:** ❌ for narration (that is the only hard blocker); ✅ in practice with `--audio` or a warm `~/.cache` + a locally vendored GSAP.
- **Windows notes:** least hostile of the "skill" repos: `choco install ffmpeg` is documented and Cursor instructions say `Cmd/Ctrl+Shift+P`. The symlink commands in the "universal install" section are Unix-only (`ln -s`); `ffmpeg` must be on PATH. No `say`/bash-script dependency in the pipeline.
- **Metadata:** ⭐ 21 · forks 5 · MIT · created 2026-05-27 · **last commit 2026-05-27 (stale, ~5 months)** · `main` · not archived.

## 4. paper-reel

- **Canonical / clone:** https://github.com/haiderfarooq3/paper-reel · `https://github.com/haiderfarooq3/paper-reel.git`
- **What it is:** A Claude Code skill for faceless 9:16 explainer reels in a cut-paper style (textured paper shapes, a box mascot with a new hat each scene, a screwed-on headline sign, stamps, counters, one paper scrap per caption word). Voice-timed: each spoken line is one scene with a hard cut.
- **Stack/type:** Node ≥18 + Playwright/Chromium + ffmpeg + **whisper.cpp** (word timings) + **Kokoro ONNX** through a Python (`kokoro-onnx`) + HTML canvas. Bash CLI wrapper at `bin/reel`; renderer/frame tools vendored from `cth9191/animate` (MIT, see `NOTICE.md`).
- **Install (from README):**
  ```sh
  git clone https://github.com/haiderfarooq3/paper-reel ~/.claude/skills/paper-reel
  cd ~/.claude/skills/paper-reel && npm install && npx playwright install chromium
  brew install ffmpeg whisper-cpp
  ~/.claude/skills/paper-reel/bin/reel doctor
  ```
  `reel doctor` checks every piece and prints the exact command for what is missing (whisper model, a Python with `kokoro-onnx`, Kokoro model files).
- **Run:** ask Claude Code, or:
  ```sh
  REEL=~/.claude/skills/paper-reel/bin/reel
  $REEL new ~/reels/my-reel            # or --from khan-skill
  # edit voice/script.json + src/scenes.js
  $REEL voice ~/reels/my-reel          # Kokoro takes + word times
  $REEL still ~/reels/my-reel 2,6,10 look.png
  $REEL check ~/reels/my-reel          # text overlap + determinism
  $REEL export ~/reels/my-reel ~/Desktop/my-reel.mp4
  ```
- **Inputs/outputs:** `voice/script.json` + `src/scenes.js` → 1080×1920 / 30 fps MP4 with a ducked lo-fi bed at ≈ −14 LUFS (~30 s render on an M-series Mac).
- **Demo:** `docs/demo.mp4` (23 s, made with the skill), `docs/strip.jpg`; starter template also available via `--from khan-skill`.
- **External API:** none, no keys. First-run network: npm, Playwright Chromium, **whisper.cpp model download**, **Kokoro ONNX model files** (Hugging Face).
- **Offline:** ✅ once models + Chromium + node_modules are cached; all inference (TTS + ASR) is local.
- **Windows notes:** **blocker.** README states "You need macOS, Node 18 or newer, ffmpeg and whisper.cpp" and installs via `brew install ffmpeg whisper-cpp`; the CLI is `bin/reel` (bash, `~` paths). On Windows you would need a whisper.cpp build, a Kokoro-capable Python, and a rewritten entry point (inferred: no Windows path documented anywhere).
- **Metadata:** ⭐ 65 · forks 10 · MIT · created 2026-10-23 · last commit 2026-10-27 · `main` · not archived.

## 5. khan-explainer

- **Canonical / clone:** https://github.com/haiderfarooq3/khan-explainer · `https://github.com/haiderfarooq3/khan-explainer.git`
- **What it is:** A Claude Code skill that renders Khan-Academy-style explainers — a pen draws on a blackboard/whiteboard while a voice explains. The voice drives the clock: each beat is one spoken clause plus the drawing that happens while it is said, so nothing is timestamped by hand.
- **Stack/type:** Node ≥20 + Playwright/Chromium + ffmpeg + the **macOS `say`** built-in voice (default). Optional: Kokoro (`pip install kokoro soundfile`), ElevenLabs, `uv` + faster-whisper for real-audio clips, macOS Vision/`swiftc` for talking-head cutout. Scene DSL is JS (`scene({beats:[{say, draw}]})`).
- **Install (from README):**
  ```sh
  git clone https://github.com/haiderfarooq3/khan-explainer ~/.claude/skills/khan-explainer
  cd ~/.claude/skills/khan-explainer/scripts && npm install && npx playwright install chromium
  brew install ffmpeg
  ```
- **Run:**
  ```sh
  cd ~/.claude/skills/khan-explainer
  node scripts/render.js examples/ai-agents.js agents.mp4                 # blackboard
  KHAN_THEME=light node scripts/render.js examples/ai-agents.js light.mp4 # whiteboard
  node scripts/render.js examples/ui-tutorial.js tutorial.mp4             # over screenshots
  node scripts/render.js examples/arabic.js arabic.mp4                    # RTL
  node tests/run.js
  ```
  Each render also prints a contact sheet (board at the end of every beat) used for self-QA. `SKILL.md` is the full scene-API reference.
- **Inputs/outputs:** a scene `.js` file (+ optional screenshots) → MP4 (landscape or vertical; one flag flips board/theme). Env: `KHAN_THEME`, `KHAN_TTS=kokoro`, `ELEVENLABS_API_KEY` + `eleven: '<voice id>'`.
- **Demo:** `examples/ai-agents.js`, `ui-tutorial.js`, `arabic.js`, `languages.js`; `docs/board.jpg`.
- **External API:** none by default (`say` is local). Optional ElevenLabs is a keyed cloud service; optional Kokoro is local but pip-downloads + fetches model weights on first use.
- **Offline:** ✅ with the default `say` voice; ✅ with Kokoro after its model is cached.
- **Windows notes:** **blocker.** `say` is macOS-only and the README requires macOS + `brew`; clip mode needs `uv`/faster-whisper, and the talking-head cutout compiles against macOS Vision. `KHAN_TTS=kokoro` is the only plausible cross-platform escape (inferred — untested on Windows, and no Windows instructions exist).
- **Metadata:** ⭐ 149 · forks 31 · MIT · created 2026-10-09 · last commit 2026-10-11 · `main` · not archived.

## 6. paper-motion-video

- **Canonical / clone:** https://github.com/DjoFE2021/paper-motion-video · `https://github.com/DjoFE2021/paper-motion-video.git`
- **What it is:** An Agent Skill (also a Claude Code plugin) that turns a research paper — LaTeX source, PDF, poster or slides — into a ~2-minute narrated explainer with charts rebuilt from the paper's own numbers, word-synced subtitles, a synthesized score, and two cuts (16:9 + 4:5 phone).
- **Stack/type:** Python 3.10–3.12 (private venv, or `uv` that fetches one) + **Kokoro-82M** TTS + Playwright/headless Chrome + ffmpeg via **imageio-ffmpeg**; JS scene files over a component library (34 components) + a layout auditor.
- **Install:**
  - Claude Code plugin: `/plugin marketplace add DjoFE2021/paper-motion-video` then `/plugin install paper-motion-video@paper-motion-video` (shell equivalent: `claude plugin …`).
  - Manual: `git clone https://github.com/DjoFE2021/paper-motion-video && cp -r paper-motion-video/skills/paper-motion-video ~/.claude/skills/` — **Windows PowerShell line is given**: `Copy-Item -Recurse paper-motion-video\skills\paper-motion-video $HOME\.claude\skills\`.
- **First run:** installs a private Python env, the Kokoro voice model and font caches into `~/.cache/paper-motion-video` — 5–10 min, once, needs internet.
- **Run:**
  ```bash
  SKILL=skills/paper-motion-video
  $SKILL/tools/pmv new ~/Desktop/my-video --length 90   # or --example pit-llm
  # edit config.json, script.txt, scenes.js
  $SKILL/tools/pmv narrate ~/Desktop/my-video
  $SKILL/tools/pmv review  ~/Desktop/my-video
  $SKILL/tools/pmv all     ~/Desktop/my-video --skip-narrate
  $SKILL/tools/pmv check   ~/Desktop/my-video
  ```
  Windows: `skills\paper-motion-video\tools\pmv.cmd`. Flags for `pmv new`: `--length` (90 / 2m / 1:30), `--formats` (landscape, portrait, vertical, square), `--voice bf_emma`, `--music hopeful|reflective|driving|off`. Defaults persist in `~/.config/paper-motion-video/defaults.json`.
- **Inputs/outputs:** `script.txt` + `scenes.js` + `config.json` → `out/<name>.mp4` (1920×1080, 60 fps, burned-in subs, −16 LUFS), `out/<name>_portrait.mp4` (1080×1350), `out/<name>_share.mp4` (30 fps light copy), `out/<name>.srt`.
- **Demo:** complete 2-minute worked example at `skills/paper-motion-video/examples/pit-llm`; `docs/demo.mp4` (50 s extract, 4 MB) + `docs/demo.gif`.
- **External API:** no keys. First run needs internet (pip env, Kokoro weights, fonts). "Rendering fetches fonts once from Google Fonts and cdnjs, then works offline."
- **Offline:** ✅ after the first run; English narration only.
- **Windows notes:** best-supported of the seven — requirements list "macOS, Linux or Windows", `pmv.cmd` ships for cmd/PowerShell, PowerShell copy line given, and ffmpeg comes from `imageio-ffmpeg` (no system ffmpeg needed). Remaining risk: long paths under `~/.cache`, and the plugin path is Claude-Code-specific.
- **Metadata:** ⭐ 1 · forks 1 · MIT · created 2026-10-21 · last commit 2026-10-21 · `main` · not archived. (Very new/low-traction — treat as unproven.)

## 7. ffmpeg-skill

- **Canonical / clone:** https://github.com/kajisho5/ffmpeg-skill · `https://github.com/kajisho5/ffmpeg-skill.git` · npm package `ffmpeg-skill`
- **What it is:** A local video *editor* for coding agents: 42 structured FFmpeg tools with a machine-readable contract, a probe → edit → verify workflow, and an MCP server — for Claude Code, Cursor, Codex and any MCP client. The agent never hand-writes an ffmpeg command; every tool is a Python script with typed `argparse` flags.
- **Stack/type:** Python 3.9+ **standard library only** + `ffmpeg`/`ffprobe` on PATH; optional MCP server `mcp/server.py` (stdio JSON-RPC, `FFMPEG_SKILL_MCP_FULL=1` to advertise all 42 tools); Node 16+ only for the `npx` installer.
- **Install:**
  ```bash
  sudo apt install ffmpeg        # macOS: brew install ffmpeg-full ; Windows: winget install Gyan.FFmpeg
  npx ffmpeg-skill               # --cursor | --codex | --all | --project | --dir ./my-skills | --uninstall
  npx ffmpeg-skill doctor
  npx ffmpeg-skill contract --json
  ```
  Or as a Claude Code plugin: `/plugin install ffmpeg-skill --marketplace kajisho5/ffmpeg-skill`. Without Node: clone and copy `SKILL.md`, `package.json`, `scripts/`, `templates/`, `references/`, `docs/`, `mcp/` into the agent's skills dir.
- **Run:**
  ```bash
  S=~/.claude/skills/ffmpeg-skill/scripts
  python3 $S/probe.py input.mp4 --compact
  python3 $S/fit.py input.mp4 --duration 60 --aspect 9:16 --dry-run
  python3 $S/export.py input.mp4 --preset reels --json
  python3 $S/render.py talk.mp4 --template tiktok --cues cues.txt
  python3 $S/check.py --platform reels; python3 $S/look.py out.mp4
  ```
  Every tool supports `--help`, `--dry-run`, `--json`/`--json-brief`, `--plan FILE` (executed later by `render.py`), `--fast`, `--progress`, `--timeout` (default 1800 s), `--overwrite`. Templates ship for `tiktok, reels, shorts, youtube-shorts, youtube, x, linkedin, facebook, podcast, audiogram`.
- **Inputs/outputs:** existing footage → **new** files named `<input>_<operation>.<ext>`; no tool overwrites its input (`mutates_input: false`). Reports use one label (`Done:` / `Failed:`), with a `Look:` line naming the contact sheet inspected.
- **Demo:** `examples/README.md`, `docs/demos.md` (before/after GIFs rebuilt from synthetic footage by `python3 demos/build.py`), `npm run demo`.
- **External API:** none, "no cloud, no API keys". Only install-time network (npm registry). Optional local ASR (`caption.py --transcribe`, `silence.py --filler --transcribe`) needs `faster-whisper` / `parakeet-mlx` / `openai-whisper` installed separately, and those **download model weights on first run**.
- **Offline:** ✅ fully — the strongest offline story here; `ffmpeg` + `python3` on PATH and it works on footage you would rather not upload.
- **Windows notes:** good. `winget install Gyan.FFmpeg`; the CI matrix includes a Windows job on gyan.dev FFmpeg 9.x. Gotchas the README calls out: in Git Bash `python3` only exists if Python came from the Microsoft Store (python.org installs expose `python`/`py`); a few fixture-driven tests are `skipIf`'d on Windows. Requires FFmpeg 5.0+ (3.0 will require 6.1) with `libx264`, `aac`, `drawtext`, `subtitles`/libass, `loudnorm`, `xfade`, `scdet`, `vidstab*` … — a lean Homebrew `ffmpeg` lacks some, which `doctor` reports.
- **Metadata:** ⭐ 4148 · forks 332 · MIT · created 2026-09-03 · last commit 2026-10-31 (very active) · `main` · not archived.

---

## Verification log

| Project | Clue checked | Result |
|---|---|---|
| claude-motion-design | `howseen-ai claude-motion-design` | ✅ exact match, README fetched |
| code-video-showcase | `Moessif code-video-showcase` | ✅ exact match |
| explainer-video | `Mng-dev-ai explainer-video` | ✅ exact match; `lib/package.json` fetched to confirm deps |
| paper-reel | `haiderfarooq3 paper-reel` | ✅ exact match |
| khan-explainer | `haiderfarooq3 khan-explainer` | ✅ exact match |
| paper-motion-video | `DjoFE2021 paper-motion-video` | ✅ exact match |
| ffmpeg-skill | `kajisho5 ffmpeg-skill` | ✅ exact match |

Fetch notes: `raw.githubusercontent.com/.../HEAD/README.md` timed out or failed transiently for `khan-explainer`, `paper-reel`, `paper-motion-video` and `explainer-video`; every one succeeded on retry via the `/main/README.md` path (all seven repos default to `main`). No 404s were encountered, so no GitHub-name search fallback was needed. Metadata came from `api.github.com/repos/<owner>/<repo>` and `/commits?per_page=1`.

## Integration notes

- **One FFmpeg, several expectations.** `ffmpeg-skill` is the strictest: it needs 5.0+ with `libass`/`subtitles`, `drawtext`, `zscale`, `loudnorm`, `xfade`, `scdet`, `vidstab*`. `paper-reel`/`khan-explainer` install ffmpeg via `brew`, `claude-motion-design` can lean on `imageio-ffmpeg`, `paper-motion-video` bundles its own via `imageio-ffmpeg`. Pin **one** ffmpeg build on PATH (gyan.dev full build on Windows) and let every tool inherit it, then run `npx ffmpeg-skill doctor` as the pack's smoke test.
- **Two mutually exclusive Python stories.** `paper-motion-video` wants a *private* Python 3.10–3.12 venv in `~/.cache/paper-motion-video` (Kokoro); `paper-reel` wants a Kokoro-capable Python on PATH (`kokoro-onnx`); `code-video-showcase` wants 3.10+ with numpy/scipy; `ffmpeg-skill` wants stdlib-only 3.9+. Do **not** try to unify them into one interpreter — keep per-skill venvs and expose `PMV`/`REEL`/`PYTHON` env vars per skill.
- **TTS matrix drives your OS choice.** macOS `say` (khan-explainer, zero network) · Kokoro local (paper-reel, paper-motion-video, khan-explainer `KHAN_TTS=kokoro`) · **Edge TTS over the network** (explainer-video — the only one that cannot render a voice offline) · ElevenLabs optional (khan-explainer). On Windows, `say` is gone, so khan-explainer needs `KHAN_TTS=kokoro` or must be dropped/run on a Mac.
- **Playwright Chromium is duplicated 4×** (claude-motion-design, code-video-showcase, explainer-video, khan-explainer/paper-reel). Point them all at one browser via `PLAYWRIGHT_BROWSERS_PATH` (or `CHROME_EXE` for code-video-showcase) to save ~1 GB and avoid four `npx playwright install chromium` runs.
- **Fonts are the silent offline breaker.** `code-video-showcase` ships no fonts and needs local OFL files; `paper-motion-video` fetches Google Fonts/cdnjs once; `explainer-video` pulls GSAP from jsdelivr every render. Pre-fetch and vendor these, or the "offline" claim fails at first render.
- **Skill install locations disagree** — `~/.claude/skills/` (most), `.cursor/skills/`, `.codex/skills/` vs `~/.agents/skills/` (ffmpeg-skill `--codex`), `~/.dsh/skills/` (code-video-showcase). Decide one canonical directory and symlink/copy per agent instead of installing five ways.
- **Output contract collisions.** Defaults are 1920×1080@30 (code-video-showcase), 1920×1080@60 (paper-motion-video), 1080×1920@30 (paper-reel), 1280×720 (explainer-video), 24 s@60 (claude-motion-design). Normalize at the pack boundary (one `export.py --preset`) rather than inside each skill, and expect `-14` vs `-16` LUFS disagreement between ffmpeg-skill/paper-reel and paper-motion-video.
- **Windows shell tax.** Seven repos, three dialects: bash (`qa-check.sh`, `concat-and-encode.sh`, `bin/reel`), PowerShell (`pmv.cmd`, given copy line), and plain Python/Node. Budget a `*.cmd`/`*.ps1` shim per bash entry point, or run the whole pack under WSL (but then keep node_modules/browser caches off `/mnt/*` — the README measures ~100× slower small-file writes there).
