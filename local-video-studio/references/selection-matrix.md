# Pipeline selection matrix

Verified **2026-10-31** against each repo's README and GitHub metadata. All seven are
MIT-licensed, use branch `main`, and need no API key. The "Windows risk" column is the
decision driver for the reference Windows machine.

## Main table

| # | Pipeline | Repo | Stack | Offline after setup | Windows risk | Output signature |
|---|---|---|---|---|---|---|
| 1 | `claude-motion-design` | [howseen-ai/claude-motion-design](https://github.com/howseen-ai/claude-motion-design) ⭐738 | Python + HTML/Canvas + Playwright + ffmpeg(imageio) + numpy | ✅ (after `fetch_assets.py`) | Medium — POSIX-only docs; pipeline is portable (inferred) | Deterministic motion design, 24s@60 demo, subframe motion blur, beat-synced music+SFX, **no voice** |
| 2 | `code-video-showcase` | [Moessif/code-video-showcase](https://github.com/Moessif/code-video-showcase) ⭐241 | Node≥20 + Playwright + FFmpeg + Python 3.10 numpy/scipy | ✅ (after deps + vendored fonts) | Low–Medium — Edge fallback documented; bash helpers | 30–90s beat-synced style showcase, 1920×1080@30, 11 style recipes, flat/cyber/ink-wash |
| 3 | `explainer-video` | [Mng-dev-ai/explainer-video](https://github.com/Mng-dev-ai/explainer-video) ⭐21 | Node + Playwright + `msedge-tts` + ffmpeg | ❌ voice needs network (use `--audio` for offline) | Low — `choco install ffmpeg` documented | 1280×720 HTML/GSAP explainer with free Edge neural TTS |
| 4 | `paper-reel` | [haiderfarooq3/paper-reel](https://github.com/haiderfarooq3/paper-reel) ⭐65 | Node≥18 + Playwright + ffmpeg + whisper.cpp + Kokoro ONNX | ✅ (after models) | **High** — macOS-only per README; bash `bin/reel` CLI | 1080×1920@30 papercut faceless reel, word-timed captions, lo-fi bed ≈ −14 LUFS |
| 5 | `khan-explainer` | [haiderfarooq3/khan-explainer](https://github.com/haiderfarooq3/khan-explainer) ⭐149 | Node≥20 + Playwright + ffmpeg + macOS `say` | ✅ with `say` (macOS) | **High** — `say` is macOS-only; `KHAN_TTS=kokoro` is the only escape | Khan-style pen-drawing explainer, voice-driven beat clock |
| 6 | `paper-motion-video` | [DjoFE2021/paper-motion-video](https://github.com/DjoFE2021/paper-motion-video) ⭐1 | Python 3.10–3.12 + Kokoro + Playwright/Chrome + imageio-ffmpeg | ✅ (after first-run downloads) | **Low** — ships `pmv.cmd`, Windows in requirements | Paper → ~2 min explainer, 1920×1080@60 + 1080×1350 portrait, burned subs, −16 LUFS, `.srt` |
| 7 | `ffmpeg-skill` | [kajisho5/ffmpeg-skill](https://github.com/kajisho5/ffmpeg-skill) ⭐4148 | Python 3.9+ stdlib + FFmpeg/ffprobe | ✅ fully | **Low** — Windows CI job, `winget` documented | 42-tool editor: probe/fit/export/render/check/look, `--json`, `--dry-run`, templates |

## Choose by need

| Need | First choice | Fallback | Why |
|---|---|---|---|
| 宣传片 / 品牌动效 | `claude-motion-design` | `code-video-showcase` | 前者精确可控；后者风格配方多、卡点展示 |
| 快速通用解说/教学 | `explainer-video` | `code-video-showcase` + 后期配音 | 前者最快；后者可做无语音展示片 |
| 竖屏剪纸风无脸短片 | `paper-reel` | `paper-motion-video` (portrait) | 剪纸风格专属；后者偏论文 |
| 论文/报告 → 解说视频 | `paper-motion-video` | `explainer-video` 手写脚本 | 图表重绘 + 逐词字幕是专属能力 |
| 已有素材剪辑 | `ffmpeg-skill` | 手写 ffmpeg | 42 个工具、契约化、可验证 |
| 严格离线 + 中文配音 | `ffmpeg-skill` + 本地 TTS 素材 | `paper-motion-video`（仅英文 Kokoro） | 两者都不联网渲染；注意后者的 Kokoro 模型为英文 |

## Windows feasibility tiers (reference Windows machine)

1. **Native, low risk:** `ffmpeg-skill`, `paper-motion-video`, `code-video-showcase`（bash 辅助脚本走 Git Bash）。
2. **Native, medium risk:** `claude-motion-design`（Python 入口可移植，但 README 只有 POSIX 示例）、`explainer-video`（流程不是 bash，只有 TTS 需网络；用 `--audio` 可离线）。
3. **WSL recommended:** `paper-reel`（`brew` + bash CLI + whisper.cpp 构建）。
4. **macOS or skip:** `khan-explainer`（默认 `say` 仅 macOS；Windows 上只能用未经验证的 `KHAN_TTS=kokoro`）。

## Corrections to the original selection form

The uploaded form (`deepseek_markdown_20261031_b81238.md`) is directionally right but has four
material inaccuracies that change setup and feasibility:

1. `claude-motion-design` is **Python + Playwright**, not Node. Install is `pip install
   playwright imageio-ffmpeg numpy pillow` + `python -m playwright install chromium`.
2. `claude-motion-design` has **no TTS at all** — it is music/SFX only. If the video needs a
   voice, pair it with a TTS step from `paper-motion-video`/Kokoro or use `explainer-video`.
3. `paper-reel` and `khan-explainer` are **macOS-first**, not general local pipelines; Windows
   needs WSL/a shim, and `khan-explainer`'s default voice (`say`) does not exist on Windows.
4. `explainer-video` caches Edge TTS MP3s, so only the **first** narration render needs the
   network for a given script; `--audio my.mp3` makes the whole pipeline offline.

Also note `paper-motion-video` is brand new (1 star, created 2026-10-21) — treat as unproven
and always run its `pmv check` before delivery.


