# paper-reel

- Repo: https://github.com/haiderfarooq3/paper-reel · MIT · ⭐65 · last commit 2026-10-27
- Verified: 2026-10-31 · default branch `main`
- Stack: Node ≥18 + Playwright/Chromium + FFmpeg + **whisper.cpp**（逐词时间）+ **Kokoro ONNX**
  （Python `kokoro-onnx`）+ HTML canvas
- Offline: ✅ 模型/浏览器 node_modules 缓存后 · 无需 Key
- **Windows 风险：高** — README 明确要求 macOS，安装用 `brew`，CLI 是 bash 脚本

## 这是什么

9:16 竖屏剪纸风无脸解说短片：纹理纸张图形、每场换帽子的纸盒吉祥物、拧上去的标题牌、印章、计数器、
每个字幕词一张纸片。**语音驱动时间轴**：每句配音就是一个场景，硬切；Kokoro 生成语音，whisper.cpp
给出逐词时间，字幕纸片严格卡在词上。

## 安装

```powershell
.\scripts\install-pipelines.ps1 -Only paper-reel
cd "$HOME\video-skills\paper-reel"
npm install
npx playwright install chromium
```

上游（macOS）写法是 `brew install ffmpeg whisper-cpp` 然后 `bin/reel doctor`。Windows 上需要自己
准备（这是本整合包唯一需要 WSL 的流水线，推荐直接在 WSL 里装）：

```bash
# WSL / Linux
sudo apt install ffmpeg
# whisper.cpp：按上游 README 构建或使用发行版包，确保 whisper-cli 在 PATH
py -3.12 -m pip install kokoro-onnx soundfile
bin/reel doctor          # 逐项检查 whisper 模型 / Python kokoro / Kokoro 模型文件 / ffmpeg
```

`bin/reel doctor` 会打印每个缺失项的确切安装命令——优先信它。

## 运行（macOS/Linux/WSL）

```bash
REEL=~/.video-skills/paper-reel/bin/reel
$REEL new ~/reels/my-reel                 # 或 --from khan-skill 用模板
# 编辑 voice/script.json 与 src/scenes.js
$REEL voice  ~/reels/my-reel              # Kokoro 逐句语音 + 逐词时间
$REEL still  ~/reels/my-reel 2,6,10 look.png
$REEL check  ~/reels/my-reel              # 文本重叠 + 确定性检查
$REEL export ~/reels/my-reel ~/Desktop/my-reel.mp4
```

输出：1080×1920 @30fps，约 −14 LUFS 的 lo-fi 床垫音乐；M 系列 Mac 上约 30 秒渲染。参考成品
`docs/demo.mp4`（23 秒）。

## Windows 结论

- 上游没有任何 Windows 路径：bash CLI `bin/reel`、`~` 路径、`brew` 安装、whisper.cpp 构建。
- 选择顺序：① WSL2 里跑（项目文件放 WSL 文件系统，别放 `/mnt/c`，小文件慢约 100×）；
  ② 找 macOS 机器；③ 自己写 `reel.ps1` shim 重写 `doctor/new/voice/still/check/export` 六个子命令
  （工作量大，不推荐）。
- 如果只是要竖屏解说，优先换 `paper-motion-video` 的 portrait 输出或 `explainer-video` + 后期裁切。

## 验收

```powershell
.\scripts\verify-output.ps1 -Path my-reel.mp4 -ExpectAspect 9:16 -CheckLoudness -ContactSheet out\contact.png
```

## 常见坑

| 现象 | 处理 |
|---|---|
| `reel doctor` 报 whisper 模型缺失 | 按其输出下载模型到指定路径；whisper.cpp 模型首次需联网 |
| Kokoro 装不上 | 用 `py -3.12` 建独立 venv 装 `kokoro-onnx`，别用系统 3.14 |
| 字幕与语音错位 | 不要手工改时间；重新跑 `voice` 生成逐词时间 |
| 渲染黑屏/缺字 | 确认 Chromium 与本地字体；先 `still` 抽帧 |
