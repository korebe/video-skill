# ffmpeg-skill

- Repo: https://github.com/kajisho5/ffmpeg-skill · MIT · ⭐4148 · last commit 2026-10-31（最活跃）
- Verified: 2026-10-31 · default branch `main` · npm 包 `ffmpeg-skill`
- Stack: Python 3.9+ **仅标准库** + PATH 上的 `ffmpeg`/`ffprobe`；可选 MCP server；`npx` 安装器需 Node 16+
- Offline: ✅ 完全离线（运行期无网络、无模型下载）· 无需 Key

## 这是什么

给编码 Agent 用的**本地视频剪辑器**：42 个结构化 FFmpeg 工具，机器可读契约（JSON），
probe → edit → verify 工作流，另有 MCP server。Agent 不手写 ffmpeg 命令，每个工具都是带类型化
`argparse` 参数的 Python 脚本。这是本整合包处理「已有素材」的默认入口，也是全包的 FFmpeg 能力
体检工具。

## 安装

```powershell
# 1) 完整版 FFmpeg（必需；本机当前缺失）
winget install --id Gyan.FFmpeg -e --source winget
# 重开终端后：
ffmpeg -version; ffprobe -version

# 2) 取仓库（本整合包方式）
.\scripts\install-pipelines.ps1 -Only ffmpeg-skill

# 3) 全包 FFmpeg 能力体检（最重要的一步）
npx -y ffmpeg-skill doctor
npx -y ffmpeg-skill contract --json
```

也可以 `npx ffmpeg-skill`（`--cursor` / `--codex` / `--all` / `--project` / `--dir ./my-skills` /
`--uninstall`）把它装进某个 agent 的 skills 目录。本整合包不依赖这一步：直接用仓库里的
`scripts/*.py`。

## 工具与用法（仓库内路径）

```powershell
$S = "$HOME\video-skills\ffmpeg-skill\scripts"

py -3.12 $S\probe.py input.mp4 --compact
py -3.12 $S\fit.py input.mp4 --duration 60 --aspect 9:16 --dry-run
py -3.12 $S\export.py input.mp4 --preset reels --json
py -3.12 $S\render.py talk.mp4 --template tiktok --cues cues.txt
py -3.12 $S\check.py --platform reels
py -3.12 $S\look.py out.mp4
```

- 每个工具都支持 `--help`、`--dry-run`、`--json` / `--json-brief`、`--plan FILE`（之后由 `render.py`
  执行）、`--fast`、`--progress`、`--timeout`（默认 1800s）、`--overwrite`。
- 内置模板：`tiktok, reels, shorts, youtube-shorts, youtube, x, linkedin, facebook, podcast, audiogram`。
- 输出：新文件 `<input>_<operation>.<ext>`，**永不覆盖输入**（`mutates_input: false`）。报告统一用
  `Done:` / `Failed:`，并用 `Look:` 指向它检查过的联系表。

## 输入 / 输出

- 输入：任意本地视频/音频素材（建议先用 `probe.py` 看规格）。
- 输出：按操作生成新文件；成片导出用 `export.py --preset <platform>`（内部 H.264/AAC/yuv420p/
  faststart + 平台分辨率/时长）。
- 可选 ASR（`caption.py --transcribe`、`silence.py --filler --transcribe`）需要自行安装
  faster-whisper / openai-whisper，并会首次下载模型权重——严格离线场景请跳过或预下载。

## Windows 注意事项

- Windows CI 覆盖；`winget install Gyan.FFmpeg` 是官方推荐路径。
- 需要完整 FFmpeg 5.0+ 构建：`libx264`、`aac`、`drawtext`、`subtitles`/libass、`loudnorm`、`xfade`、
  `scdet`、`vidstab*`、`zscale`。缺哪个 `doctor` 会报哪个。
- Git Bash 里 `python3` 可能不存在（python.org 安装只有 `python`/`py`）——用 `py -3.12` 显式调用。
- 少数 fixture 驱动测试在 Windows 上 `skipIf`，属预期。

## 质量自检

```powershell
npx -y ffmpeg-skill doctor
py -3.12 $S\check.py --platform reels
py -3.12 $S\look.py out.mp4          # 生成联系表供人看
.\scripts\verify-output.ps1 -Path out.mp4 -ExpectAspect 9:16 -CheckLoudness -ContactSheet out\contact.png
```

## 常见坑

| 现象 | 处理 |
|---|---|
| 工具报缺少 filter/encoder | 换 gyan.dev full 构建；`doctor` 输出的清单就是验收标准 |
| `python3` 找不到 | 用 `py -3.12` 或 python.org 的 `python` |
| 想撤销 | 所有工具都不改输入，直接忽略新文件即可 |
| 长任务超时 | `--timeout` 调大（默认 1800s），或 `--plan` 先出计划再执行 |
