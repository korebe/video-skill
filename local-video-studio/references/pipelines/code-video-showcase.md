# code-video-showcase

- Repo: https://github.com/Moessif/code-video-showcase · MIT · ⭐241 · last commit 2026-10-28
- Verified: 2026-10-31 · default branch `main`
- Stack: Node ≥20 + Playwright（或 playwright-core）+ FFmpeg/ffprobe + Python ≥3.10（numpy/scipy）
- Offline: ✅ 依赖就绪 + 本地字体后 · 无需 Key

## 这是什么

一套 30–90 秒「风格展示片」制作配方：8 秒片头 + N × 4 秒轮次（1 秒大标题卡 + 3 秒风格片段）+
8 闪快切 + 6 秒片尾；画面用 HTML/Canvas/SVG/Three.js 逐帧绘制，配乐用 numpy/scipy 合成。
仓库 `SKILL.md` 是中文权威说明。共 11 种风格配方（扁平科学、赛博故障、水墨等）。

## 安装

```powershell
.\scripts\install-pipelines.ps1 -Only code-video-showcase
cd "$HOME\video-skills\code-video-showcase"
py -3.12 -m pip install numpy scipy
# 每个新工程单独装 playwright（仓库根没有统一 npm install 流程）
```

模板结构（按 README 的 quick start，Windows 等价）：

```powershell
$proj = "$HOME\video-projects\my-showcase"
New-Item -ItemType Directory -Force "$proj\segments","$proj\shared","$proj\fonts","$proj\audio","$proj\out" | Out-Null
Copy-Item templates\* $proj -Recurse
Copy-Item scripts\* $proj -Recurse
cd $proj; npm i playwright
```

**字体不随仓库提供**：把 OFL 字体（Noto Sans SC / Inter 等）放进工程并在 `shared/fonts.css` 用
本地 `@font-face` 引用，否则离线渲染会退回默认字体（中文变豆腐块）。

## 渲染

```powershell
# 抽帧自检（先看再渲）
node render-segment.mjs --page /segments/01.html?theme=aqua-morandi --still 0.2,0.8,1.4,2.0,2.6 --outdir out/stills

# 单段渲染
node render-segment.mjs --page /segments/01.html?theme=aqua-morandi --out out/01.mp4 --duration 3

# bash 辅助脚本（Git Bash 中运行）
./qa-check.sh out 30
py -3.12 synth_audio.py --out audio/demo.wav
./concat-and-encode.sh segments.txt audio/mix.wav out/final.mp4
```

- 默认成片：1920×1080 @30fps，H.264 yuv420p + 48kHz AAC 192k，61.0 秒 = 1830 帧，约 26 MB。
- 可调环境变量：`CHROME_EXE`、`FFMPEG_EXE`、`FFMPEG`、`FFPROBE`、`VIDEO_BITRATE`、
  `AUDIO_BITRATE`、`PYTHON`。
- 仓库**没有成品 demo 视频**；`assets/` 里是 1fps 联系表、风格卡和频谱图。`synth_audio.py` 开箱
  能出 8 秒音频 demo，先用它验证 Python 音频链。

## Windows 注意事项

- 本仓库是七个里 Windows 文档最好的：渲染器按 `CHROME_EXE` → Playwright 自带 Chromium →
  Edge（`channel: 'msedge'`）顺序回退。Windows 上通常 Edge/Chrome 都在，可显式设 `CHROME_EXE`。
- `qa-check.sh`、`concat-and-encode.sh`、`analyze-reference.sh` 是 bash：用 Git Bash 跑；或把其中的
  ffprobe/ffmpeg 命令复制到 PowerShell。
- Git Bash 里 `python3` 可能不存在（python.org 安装只有 `python`/`py`）——把 `PYTHON` 指到
  `py -3.12` 对应的 python.exe，或直接 alias。
- README 的 `mkdir -p` / `cp` 用上面 PowerShell 等价命令替换。

## 质量自检

```powershell
.\scripts\verify-output.ps1 -Path out\final.mp4 -ExpectDuration 61 -ExpectAspect 16:9 -CheckLoudness -ContactSheet out\contact.png
```

## 常见坑

| 现象 | 处理 |
|---|---|
| 中文显示为方块 | 字体未 vendor；补 `shared/fonts.css` 本地字体 |
| 逐帧截图空白 | 页面资源未加载完；先 `--still` 抽帧确认 |
| `.sh` 脚本报错 | 用 Git Bash，或手工执行里面的 ffmpeg/ffprobe 命令 |
| 成片偏暗/偏亮 | 风格配方参数在模板/`segments` 页面里，按 `SKILL.md` 调，不要后期硬拉 |

