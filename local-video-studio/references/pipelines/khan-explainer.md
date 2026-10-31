# khan-explainer

- Repo: https://github.com/haiderfarooq3/khan-explainer · MIT · ⭐149 · last commit 2026-10-11
- Verified: 2026-10-31 · default branch `main`
- Stack: Node ≥20 + Playwright/Chromium + FFmpeg + **macOS `say`**（默认配音）；可选 Kokoro
- Offline: ✅（用 `say` 时）· 无需 Key
- **Windows 风险：高** — 默认语音 `say` 仅 macOS，README 要求 macOS + `brew`

## 这是什么

可汗学院风格讲解：一支笔在黑板上边画边讲，**语音驱动时钟**——每个 beat 是一句口语 + 说这句话期间
发生的绘制，不用手打时间戳。场景 DSL 是 JS：`scene({beats:[{say, draw}]})`。可切换黑板/白板、
横竖屏，支持阿拉伯语 RTL、截图教程、真人头像抠像（macOS Vision）。

## 安装

```powershell
.\scripts\install-pipelines.ps1 -Only khan-explainer
cd "$HOME\video-skills\khan-explainer\scripts"
npm install
npx playwright install chromium
```

上游：`brew install ffmpeg`。Windows：`winget install --id Gyan.FFmpeg -e`。

## 运行

```powershell
cd "$HOME\video-skills\khan-explainer"
node scripts/render.js examples/ai-agents.js agents.mp4                  # 黑板
# 白板：$env:KHAN_THEME='light'; node scripts/render.js examples/ai-agents.js light.mp4
node scripts/render.js examples/ui-tutorial.js tutorial.mp4              # 截图教程
node scripts/render.js examples/arabic.js arabic.mp4                     # RTL
node tests/run.js
```

每次渲染会打印一张联系表（每个 beat 结束时的黑板状态）用于自检。场景 API 全文见仓库 `SKILL.md`。

- 环境变量：`KHAN_THEME`（`dark`/`light`）、`KHAN_TTS=kokoro`、`ELEVENLABS_API_KEY`（**本整合包禁止使用**）。
- 可选：Kokoro `py -3.12 -m pip install kokoro soundfile`；真实音频片段需要 `uv` + faster-whisper；
  真人抠像需要 macOS Vision/swiftc。

## Windows 结论

- 默认 `say` 不存在于 Windows；README 只支持 macOS。唯一可能的跨平台出口是 `KHAN_TTS=kokoro`
  （上游未测试，需自行验证：先用 10 秒脚本试渲染，确认配音轨道非空）。
- 现实选择：① 在 macOS 上跑；② WSL（Kokoro 仍需网络下载模型）；③ 用 `explainer-video` 的
  GSAP 动画 + 白板风格 CSS 自己实现近似效果。
- 绝不为了出声接 ElevenLabs 等外部 API。

## 验收

```powershell
.\scripts\verify-output.ps1 -Path agents.mp4 -ExpectAspect 16:9 -CheckLoudness -ContactSheet out\contact.png
```

## 常见坑

| 现象 | 处理 |
|---|---|
| `say: command not found` / 无音轨 | 默认语音仅 macOS；Windows 试 `KHAN_TTS=kokoro`，否则换平台 |
| 笔迹与语音不同步 | 不要手改时间；语音时长即时间轴，重新生成语音后再渲染 |
| 联系表里文字重叠 | 调场景 `draw` 布局或减少每 beat 文本量 |
| 渲染很慢 | 逐帧截图 + 笔迹采样，属正常；先跑 `tests/run.js` 与 10 秒短场景 |
