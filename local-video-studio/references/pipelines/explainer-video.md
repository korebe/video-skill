# explainer-video

- Repo: https://github.com/Mng-dev-ai/explainer-video · MIT · ⭐21 · **last commit 2026-05-27（偏旧）**
- Verified: 2026-10-31 · default branch `main`
- Stack: Node（CommonJS，`lib/pipeline.js`）+ Playwright + `msedge-tts` + PATH 上的 ffmpeg
- Offline: ❌ 配音必须联网（Edge TTS）；用 `--audio` 可完全离线 · 无需 Key

## 这是什么

最省事的通用解说流水线：Agent 针对主题写一张 HTML/CSS/GSAP 动画页，pipeline 对每段脚本自动生成
微软 Edge 神经 TTS 配音，headless Chromium 录制页面，ffmpeg 合成为 MP4。注意它**不是**纯本地配音：
Edge TTS 打的是微软在线端点（无 key、无账号，但要联网）。GSAP 也是从 jsdelivr 加载的。

## 安装

```powershell
.\scripts\install-pipelines.ps1 -Only explainer-video
cd "$HOME\video-skills\explainer-video\lib"
npm install --silent
# FFmpeg：winget install --id Gyan.FFmpeg -e   （README 的 Windows 方案是 choco install ffmpeg）
```

## 运行

```powershell
cd "$HOME\video-skills\explainer-video"
node lib/pipeline.js --config config.json --out video.mp4
# 或显式指定
node lib/pipeline.js --html page.html --script script.txt --voice brian --out video.mp4
```

`config.json` 字段：`title`、`voice`、`html`、`scriptSegments[]`。页面契约：

- 视口 1280×720；
- 页面读 `window.__AUDIO_DURATION` / `window.__SEGMENT_DURATIONS` 对齐动画；
- 结束时设 `window.__done = true`。

可用声音：`brian`（默认）、`adam`、`rachel`、`sarah`、`antoni`、`emma`、`ryan`、`sonia`，或任意
Azure neural voice id。输出 1280×720 MP4；配音缓存于
`~/.cache/explainer-video/voice/<sha256(voice+text)>.mp3`。

## 离线化改造（本整合包的强制要求）

1. **配音**：用 `--audio my-voice.mp3` 传入现成音频（SAPI 生成、Kokoro 生成或真人录音），即可完全
   断网渲染。同一脚本二次渲染可直接复用缓存 MP3。
2. **GSAP**：把 `gsap.min.js` 下载一次放到页面同目录，把 `<script src="https://cdn.jsdelivr.net/...">`
   改成相对路径。
3. **字体**：CSS 里显式 `@font-face` 本地字体，避免系统字体差异和豆腐块。

## 验收

```powershell
.\scripts\verify-output.ps1 -Path video.mp4 -ExpectAspect 16:9 -CheckLoudness -ContactSheet out\contact.png
```

## Windows 注意事项

- 七个仓库里对 Windows 最友好：没有 `say`/bash 依赖，`choco install ffmpeg` 有文档，pipeline 是纯 Node。
- 只在 `lib` 目录里 `npm install`（`lib/package.json` 才是依赖清单）。
- 仓库自 2026-05 未更新；遇到 API 变动按 README + 页面契约自行适配，并把锁定 commit 记到 `notes.md`。
