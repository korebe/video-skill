# claude-motion-design

- Repo: https://github.com/howseen-ai/claude-motion-design · MIT · ⭐738 · last commit 2026-10-02
- Verified: 2026-10-31 · default branch `main`
- Stack: **Python** + HTML/Canvas `seek(t)` + Playwright Chromium + FFmpeg (`imageio-ffmpeg`) + numpy/Pillow
- Offline: ✅ after `fetch_assets.py` has run once · TTS: **none** (music + SFX only)

## 这是什么

把每一帧都当作时间的函数：HTML/Canvas 页面实现 `seek(t)`，Playwright 逐帧截图，再做亚帧运动模糊
混合（subframe motion blur），最后按 beat map 卡点合成。输出确定性极高，适合产品发布片、品牌动效、
动态设计。仓库内的 `skill/motion-design/` 是给 Claude Code 的 skill 说明，实际渲染靠
`render.py` / `audio.py` 和示例工程。

## 安装（Windows）

```powershell
# 仓库（本整合包默认 vendor 根：%USERPROFILE%\video-skills）
.\scripts\install-pipelines.ps1 -Only claude-motion-design
cd "$HOME\video-skills\claude-motion-design"

# Python 依赖（务必用 3.12，不要用 3.14）
py -3.12 -m pip install playwright imageio-ffmpeg numpy pillow
py -3.12 -m playwright install chromium
```

README 里 `cp -r skill/motion-design ~/.claude/skills/` 与 `mkdir -p` 是 POSIX 写法；在此环境中直接用
`Copy-Item` 或跳过——本整合包不依赖 Claude Code 的 skill 安装位置，直接驱动示例工程即可。

## 跑通示例（examples/howseen-launch，24 秒 Howseen 发布片）

```powershell
cd examples\howseen-launch
py -3.12 fetch_assets.py            # 首次联网：Mixkit/Pexels/Unsplash/svgl 素材 + 字体
Start-Job { py -3.12 -m http.server 8000 }   # 代替 README 里的 `python -m http.server 8000 &`

py -3.12 render.py probe 1 8 15 20   # 抽 4 帧 -> probe/sheet.png，先看构图/字幕
py -3.12 render.py full              # 24s @60fps -> out/video.mp4
py -3.12 audio.py                    # -> out/audio.wav（-14 LUFS）
ffmpeg -i out\video.mp4 -i out\audio.wav -map 0:v -map 1:a -c:v libx264 -crf 16 -c:a aac -shortest out\final.mp4
```

- `render.py draft` 出 540p 预览；`render.py remake <...>` 用于改版重渲染。
- 有自己的 brief/brand 素材时，按示例目录结构放好素材和 `facts.md`，不要改动 skill 代码。

## 输入 / 输出

- 输入：brief / 品牌素材文件夹 + `facts.md`（事实点，避免字幕胡说）；音乐/SFX/logo/字体。
- 输出：`out/video.mp4`（无声画面）+ `out/audio.wav` → 复用成 `out/final.mp4`。
- 默认规格：1920×1080 @60fps，24 秒；`-crf 16`。

## Windows 注意事项

- README 全是 POSIX 示例：`mkdir -p`、`cp -r`、`python -m http.server 8000 &`。用 PowerShell 等价命令
  （`New-Item -ItemType Directory`、`Copy-Item`、`Start-Job`），或用 Git Bash。
- 渲染本身没有 `say`/bash 依赖，Python 入口可移植（推断）；实际以首次 `render.py probe` 能否出图为准。
- `imageio-ffmpeg` 自带 ffmpeg 二进制；但建议仍把完整 FFmpeg 放 PATH，供 mux 与后续校验使用。
- 没有配音：需要人声时另接 TTS（如 paper-motion-video 的 Kokoro）或改用 `explainer-video`。

## 常见坑

| 现象 | 处理 |
|---|---|
| `fetch_assets.py` 失败 | 素材站需要联网一次；重试或用自己的素材按同名替换 |
| 抽帧是黑屏 | 页面还没 ready 就截图；等 `document.fonts.ready` / 页面 ready 标志；先用 `probe` 验证 |
| 背景 `http.server` 起不来 | 用第二个终端或 `Start-Job`，不要用 `&` |
| 帧率/模糊异常 | 保持 60fps 渲染与亚帧混合的原始设置，不要后期补帧 |

