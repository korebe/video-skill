---
name: local-video-studio
description: Produce or edit videos end-to-end with local, offline-first pipelines and no external APIs, API keys, or cloud services. Routes a video brief to seven bundled open-source pipelines - deterministic motion design (HTML + Playwright + FFmpeg), style-driven code-drawn shorts, explainer/教学 animation with local TTS, papercut 9:16 faceless shorts, whiteboard explainers, paper-to-video chart animation, and local FFmpeg editing/analysis - with Windows environment checks, vendored-repo bootstrap, per-pipeline runbooks, and output verification. Use for promos, motion graphics, explainer videos, vertical shorts, paper summaries, or editing existing footage locally.
metadata:
  version: "1.0.0"
  pipelines: 7
---

# Local Video Studio

One entry point for seven local video-production pipelines. Everything runs on the user's
machine: no external API, no API key, no cloud render, no paid stock. The user supplies (or
the agent generates) HTML/SVG/Canvas, code, TTS audio, and FFmpeg — nothing else.

Start with `references/selection-matrix.md` when the right pipeline is not obvious.

## Hard constraints

- **No external API.** Never add a key, never fall back to a cloud TTS/LLM/render service when a
  local step fails. `khan-explainer`'s optional ElevenLabs path is such a service: do not use it.
  Fix the local toolchain or switch to another local pipeline.
- **Strict offline first.** `claude-motion-design`, `code-video-showcase`, `paper-reel`,
  `khan-explainer`, `paper-motion-video`, `ffmpeg-skill` work offline after setup.
  `explainer-video` is the only pipeline whose voice needs the network (Edge TTS); use its
  `--audio file.mp3` escape hatch with Windows SAPI or Kokoro audio for a strict-offline render.
- **Vendored repos are read-only.** Clone upstream projects under the vendor root
  (`%USERPROFILE%\video-skills` by default). Keep user customizations in the project folder, not
  inside vendored code, so `-Update` never destroys work.
- **Respect the brief.** Language (中文/英文), aspect ratio, duration, brand colors/fonts, voice
  and pacing, and delivery deadline. If a detail is missing, ask one compact question (goal,
  aspect, duration, must-be-offline?) instead of a questionnaire.
- **Fonts and assets must be redistributable.** Bundle free fonts (Noto Sans SC/思源黑体,
  Inter, etc.) with the project; do not assume system fonts exist in headless rendering.

## Route the brief

| Main need | Pipeline | Reference |
|---|---|---|
| 有设计感的宣传片 / 品牌动效 / 产品发布 | `claude-motion-design` | `references/pipelines/claude-motion-design.md` |
| 30–90s 风格化展示片、卡点短片、扁平/赛博/水墨 | `code-video-showcase` | `references/pipelines/code-video-showcase.md` |
| 通用主题解说、概念动画、教学视频（最快上手） | `explainer-video` | `references/pipelines/explainer-video.md` |
| 9:16 竖屏剪纸风无脸短片、逐词字幕卡点 | `paper-reel` | `references/pipelines/paper-reel.md` |
| 可汗学院式白板/黑板讲解（一支笔 + 语音） | `khan-explainer` | `references/pipelines/khan-explainer.md` |
| 把论文/报告转成 2 分钟解说，图表随讲解生长 | `paper-motion-video` | `references/pipelines/paper-motion-video.md` |
| 已有素材：剪辑、转场、改画幅、烧字幕、去静音、响度统一 | `ffmpeg-skill` | `references/pipelines/ffmpeg-skill.md` |

Tie-breakers: precision and determinism → `claude-motion-design`; fastest generic explainer →
`explainer-video`; no-voice short → `paper-reel`; editing existing footage → `ffmpeg-skill`.

Windows feasibility (verified 2026-10-31, for the reference Windows machine):

- **Native, low risk:** `ffmpeg-skill`（Windows CI 覆盖）、`paper-motion-video`（自带 `pmv.cmd`）、
  `code-video-showcase`（渲染器可回退 Edge，`.sh` 助手走 Git Bash）。
- **Native, medium:** `claude-motion-design`（Python 入口可移植，但 README 只有 POSIX 示例；无配音）、
  `explainer-video`（流程不是 bash，只有 TTS 需网络）。
- **WSL recommended:** `paper-reel`（macOS-only 文档 + bash CLI + whisper.cpp 构建）。
- **macOS or skip:** `khan-explainer`（默认 `say` 仅 macOS；`KHAN_TTS=kokoro` 未在 Windows 验证）。

Do not silently pick a high-risk pipeline on Windows: state the risk and the fallback plan.

## Workflow

0. **Brief & plan.** Create a project folder and write `brief.md` + `storyboard.md` from
   `assets/` templates:
   `.\scripts\new-project.ps1 -Name my-video -Pipeline <pipeline>`.
   Storyboard first: every shot gets duration, visual, text, voice line, and asset source.
1. **Environment check.** `.\scripts\env-check.ps1` (add `-Strict` to fail hard).
   Read `references/environment.md` when a required tool is missing. Do this before cloning or
   rendering — missing FFmpeg is the most common failure.
2. **Bootstrap the pipeline.** `.\scripts\install-pipelines.ps1 -Only <pipeline>` (first run uses
   defaults; `-DryRun` prints the plan; `-Bootstrap` runs the dependency commands from
   `scripts/pipelines.json`). When GitHub is unreachable, follow the mirror/ZIP fallback in
   `references/environment.md`. Then run `npx -y ffmpeg-skill doctor` once to prove the FFmpeg
   build is complete.
3. **Build.** Follow `references/pipelines/<pipeline>.md` exactly, running from the vendored repo
   directory and writing outputs into the project's `renders/` folder. Use the pipeline's own
   example as the first end-to-end smoke test before customizing. Keep one Python venv per
   pipeline; never unify them.
4. **Verify the file.** `.\scripts\verify-output.ps1 -Path renders/out.mp4
   -ExpectDuration 30 -ExpectAspect 16:9 -CheckLoudness` and then inspect 3–5 sampled frames
   (contact sheet). Reject: wrong aspect/duration, silent audio, black frames, tofu CJK glyphs,
   clipped captions, or burnt-in watermarks.
5. **Deliver.** Final MP4 (H.264/AAC, `yuv420p`, `faststart`) + optional cover, SRT, and the
   project source folder. Report devices/tested playback, exact ffprobe facts, and anything the
   user still must supply.

## Environment quick facts (reference Windows machine, sampled 2026-10-31)

All seven upstream repos were verified (GitHub API + README): all MIT, all branch `main`, no API
keys. Pipeline languages differ from the naive "all Node" assumption:

- Installed: Node 24.22, npm 11.19, git 2.54, Chrome + Edge, Playwright browser cache
  (`chromium-1234`), Windows SAPI TTS, long paths enabled.
- Missing: **FFmpeg/ffprobe not on PATH** (install full gyan.dev build via
  `winget install Gyan.FFmpeg`; needs `libass`/`drawtext`/`zscale`/`loudnorm`/`vidstab`),
  **Python 3.10–3.12 missing** (only 3.14 plus a legacy 2.7 interpreter; install 3.12 and use per-skill venvs —
  `claude-motion-design`, `code-video-showcase`, `paper-reel`, `paper-motion-video`,
  `ffmpeg-skill` all involve Python), and the Playwright npm package is not globally resolvable.
- GitHub `git clone` is blocked (connection reset). `install-pipelines.ps1` tries
  ghproxy.net → gitclone.com → kkgithub.com → ZIP archive; a manual browser-ZIP fallback is in
  `references/environment.md`.
- After FFmpeg is installed, `npx -y ffmpeg-skill doctor` is the pack-wide toolchain smoke test.
- Share one Chromium across pipelines with `PLAYWRIGHT_BROWSERS_PATH=%LOCALAPPDATA%\ms-playwright`;
  `code-video-showcase` also accepts `CHROME_EXE`.
- Fonts are the silent offline breaker: vendor OFL CJK fonts per project; `code-video-showcase`
  ships none, `explainer-video` loads GSAP from jsdelivr, `paper-motion-video` fetches fonts only
  on its first run.

## Project layout convention

```
projects/<slug>/
  brief.md        # audience, goal, duration, aspect, language, style, constraints
  storyboard.md   # shot list with timing, copy, voice-over, assets
  assets/         # images, fonts, logos, music, SFX
  audio/          # TTS lines, music, mixdown
  shots/          # per-shot render work (HTML, scripts, intermediate clips)
  renders/        # intermediate MP4s and final out.mp4
  notes.md        # decisions, failed attempts, timings
```

## Quality gates

- Container: MP4, H.264 High, `yuv420p`, AAC 48 kHz stereo, `+faststart`.
- Duration matches the brief ±1 frame; aspect/resolution exactly as asked (9:16 → 1080×1920 etc.).
- Audio: speech present, no clipping, voice ≈ −16 LUFS integrated (±2), music ducked under voice.
- Visual spot checks at 0%, 25%, 50%, 75%, 100%: no black/blank frames, no text overflow, no
  missing-glyph boxes, no off-brand colors.
- Captions/subtitles: readable at 1×, safe margins ≥5%, synchronized (verify on 3 spots).
- Licensing: fonts, images, music, and TTS voices are free for the user's intended use.
- Normalize at the pack boundary, not inside a pipeline: pipeline defaults disagree
  (1920x1080@30 / 1920x1080@60 / 1280x720 / 1080x1920; -14 vs -16 LUFS). Finish with one
  `ffmpeg-skill export.py --preset <platform>` pass so every deliverable shares one spec.

## References

| File | Contents |
|---|---|
| `references/selection-matrix.md` | All 7 projects compared: stack, deps, output traits, offline status |
| `references/environment.md` | Windows toolchain install, mirrors, TTS options, verification commands |
| `references/troubleshooting.md` | Symptom → cause → fix for common local-render failures |
| `references/pipelines/<name>.md` | Per-pipeline setup, entry commands, inputs/outputs, gotchas |

## Scripts

| Script | Purpose |
|---|---|
| `scripts/env-check.ps1` | Check git/node/npm/python/ffmpeg/playwright/Edge/TTS; `-JsonOut` report |
| `scripts/install-pipelines.ps1` | Clone upstream repos into vendor root; `-Only`, `-DryRun`, `-Update`, mirror fallback |
| `scripts/new-project.ps1` | Scaffold a project folder with brief/storyboard templates |
| `scripts/verify-output.ps1` | ffprobe checks: duration, resolution/aspect, audio, loudness; contact sheet |

Skill root after install: `$HOME/.agents/skills/local-video-studio`
(`%USERPROFILE%\.agents\skills\local-video-studio` on Windows).








