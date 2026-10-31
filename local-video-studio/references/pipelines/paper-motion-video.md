# paper-motion-video

- Repo: https://github.com/DjoFE2021/paper-motion-video · MIT · ⭐1 · created & last commit 2026-10-21
- Verified: 2026-10-31 · default branch `main`
- Stack: Python 3.10–3.12（私有 venv）+ **Kokoro-82M** TTS + Playwright/Chrome + FFmpeg（imageio-ffmpeg）
- Offline: ✅ 首次运行完成后 · 无需 Key · **仅英文旁白**
- Windows 支持：**七个里最好**（仓库带 `pmv.cmd`，requirements 写明 Windows）

## 这是什么

把论文（LaTeX 源、PDF、poster、slides）转成约 2 分钟解说视频：用论文里的数字重绘图表、生成逐词同步
字幕、合成配乐，并输出两个版本（16:9 + 4:5 手机竖版）。JS 场景文件 + 34 个组件库 + 布局审计器。
注意仓库非常新（1 star），视为「未验证」能力，交付前必须跑 `pmv check`。

## 安装

```powershell
.\scripts\install-pipelines.ps1 -Only paper-motion-video
cd "$HOME\video-skills\paper-motion-video"
```

首次运行会自建私有 Python 环境、下载 Kokoro 语音模型与字体缓存到 `~/.cache/paper-motion-video`，
约 5–10 分钟，只需一次（需联网；可先 `$env:HF_ENDPOINT='https://hf-mirror.com'`）。

不需要手动装 ffmpeg：它用 `imageio-ffmpeg` 自带的二进制。但建议 PATH 里仍有一份完整 FFmpeg
供 `verify-output.ps1` 使用。

## 运行（Windows 用 `pmv.cmd`）

```powershell
$PMV = "$HOME\video-skills\paper-motion-video\skills\paper-motion-video\tools\pmv.cmd"
& $PMV new "$HOME\Desktop\my-video" --length 90 --formats landscape,portrait --voice bf_emma
# 编辑 $HOME\Desktop\my-video\config.json、script.txt、scenes.js
& $PMV narrate "$HOME\Desktop\my-video"
& $PMV review  "$HOME\Desktop\my-video"
& $PMV all     "$HOME\Desktop\my-video" --skip-narrate
& $PMV check   "$HOME\Desktop\my-video"      # 交付前必须通过
```

- `pmv new` 选项：`--length`（90 / 2m / 1:30）、`--formats`（landscape / portrait / vertical / square）、
  `--voice bf_emma`、`--music hopeful|reflective|driving|off`；默认值持久化在
  `~/.config/paper-motion-video/defaults.json`。
- 仓库自带 2 分钟完整示例：`skills/paper-motion-video/examples/pit-llm`；`docs/demo.mp4`（50 秒节选）。

## 输入 / 输出

- 输入：`script.txt`（旁白逐字稿）+ `scenes.js`（场景）+ `config.json`。
- 输出：`out/<name>.mp4`（1920×1080 @60fps、烧录字幕、−16 LUFS）、`out/<name>_portrait.mp4`
  （1080×1350）、`out/<name>_share.mp4`（30fps 轻量版）、`out/<name>.srt`。
- 中文用户注意：Kokoro 旁白为英文；中文讲解需外部配音 + 自行替换音频（见 `environment.md` TTS 矩阵）。

## Windows 注意事项

- 上游给了 PowerShell 复制 skill 的命令；本整合包不需要复制到 `~/.claude/skills`，直接用仓库内
  `skills\paper-motion-video\tools\pmv.cmd`。
- 缓存路径较深，保持工程路径短（`C:\v\<name>`），避免长路径问题（建议启用 LongPaths）。
- 首次运行失败多半是网络（venv/模型/字体下载）——先联网跑通一次，之后可离线。

## 验收

```powershell
.\scripts\verify-output.ps1 -Path out\my-video.mp4 -ExpectDuration 120 -ExpectAspect 16:9 -CheckLoudness -ContactSheet out\contact.png
```

## 常见坑

| 现象 | 处理 |
|---|---|
| `pmv` 报缺模型/无网络 | 首次运行需联网；设 `HF_ENDPOINT` 镜像后重跑 |
| `pmv check` 不通过 | 按报告改 `scenes.js` 布局/文本；不要带病交付 |
| 中文旁白不存在 | Kokoro 仅英文；用 SAPI/真人音频替换 `audio/` 后重跑 `pmv all --skip-narrate` |
| 图表数字与论文不符 | 在 `config.json`/`scenes.js` 中手动核对数据点，不要信任自动提取 |

