# Local Video Studio — 本地视频制作 Skill 整合包

把上传的《纯本地 / 不集成外部 API 的 Claude 视频制作 Skill 选型表单》里的 **7 个开源项目**，
整合成 **1 个可直接安装的 DSH/Claude Skill 包**：统一入口、统一环境体检、统一安装脚本、
每个流水线一份实操作手册、统一成片校验。

**核心承诺：不接任何外部 API、不需要任何 Key、不调用云端渲染或云端 TTS。**
（唯一例外：`explainer-video` 的 Edge TTS 需要联网；包内给了 `--audio` 离线替代方案。）

> 本包基于 **2026-10-31 对 7 个仓库的 README + GitHub 元数据实查**编写（7/7 已验证，全部 MIT，
> 全部 `main` 分支，无一个 URL 猜错）。修正了原表单里的 4 处事实错误，见 `references/selection-matrix.md`。

## 安装

### 方式 A：一键安装到用户级 skills（推荐）

```powershell
# 解压后进入本目录，运行：
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-skill.ps1
```

它会把 `local-video-studio\` 复制到 `C:\Users\ASUS\.agents\skills\local-video-studio\`。
**装完重启会话/应用**，新会话的技能目录里就会出现 `local-video-studio`。

### 方式 B：手动复制

```powershell
Copy-Item -Recurse -Force .\local-video-studio "$HOME\.agents\skills\"
Get-ChildItem -Recurse "$HOME\.agents\skills\local-video-studio" | Unblock-File
```

### 方式 C：项目级（只在某个工作区生效）

```powershell
Copy-Item -Recurse -Force .\local-video-studio ".\.agents\skills\"
```

DSH 会扫描的 skills 目录：`<项目>/.dsh/skills`、`<项目>/.agents/skills`、`~/.dsh/skills`、
`~/.agents/skills`（本包用最后一个，便于全局可用）。

## 快速开始（装好后）

```powershell
$skill = "$HOME\.agents\skills\local-video-studio"

# 1) 环境体检（本机当前会报 ffmpeg 缺失、Python 3.14 过新——按提示修）
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\env-check.ps1"

# 2) 拉取流水线仓库（GitHub 被墙时自动走镜像/ZIP 回退）
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-pipelines.ps1" -List
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-pipelines.ps1" -Only ffmpeg-skill

# 3) 建一个视频工程（自动生成 brief / storyboard / 目录结构）
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\new-project.ps1" `
  -Name "my-video" -Pipeline claude-motion-design -Aspect 16:9 -DurationSec 30

# 4) 按 $skill\references\pipelines\<流水线>.md 操作，成片后用 verify-output.ps1 验收
```

或者装好后直接对新会话说：**「用 local-video-studio 做一个 30 秒产品发布片」**，技能会自己选流水线。

## 目录结构

```
local-video-studio/
├── SKILL.md                     # 技能入口：约束、选型路由、工作流、质量门禁
├── README.md                    # 本文件
├── references/
│   ├── selection-matrix.md      # 7 个流水线对比 + 选型 + Windows 风险分层 + 原表单纠错
│   ├── environment.md           # Windows 环境安装、镜像、字体、TTS 矩阵、验收
│   ├── troubleshooting.md       # 现象 → 原因 → 修复
│   └── pipelines/               # 7 份逐个流水线手册（安装/运行/输入输出/坑）
├── scripts/
│   ├── env-check.ps1            # 环境体检（可 -JsonOut/-Strict/-CheckNetwork）
│   ├── install-pipelines.ps1    # 拉取/更新上游仓库（-Only/-DryRun/-Update/-Bootstrap/镜像回退）
│   ├── new-project.ps1          # 视频工程脚手架
│   ├── verify-output.ps1        # ffprobe 验收：时长/画幅/音轨/响度/联系表
│   └── pipelines.json           # 流水线清单（仓库、依赖、bootstrap 命令，已核验）
└── assets/
    ├── brief-template.md        # 需求单模板
    └── storyboard-template.md   # 分镜脚本模板
```

## 流水线速查（全部实测核验）

| 流水线 | 用途 | 技术栈 | 离线 | Windows 风险 |
|---|---|---|---|---|
| `claude-motion-design` | 宣传片 / 品牌动效 / 产品发布 | Python + HTML/Canvas + Playwright + ffmpeg | ✅ 素材抓取后 | 中（文档只有 POSIX；且无配音） |
| `code-video-showcase` | 30–90s 风格化卡点展示片 | Node≥20 + Playwright + FFmpeg + Python | ✅ 依赖+字体后 | 低-中（.sh 助手走 Git Bash） |
| `explainer-video` | 通用解说 / 教学动画（最快） | Node + Playwright + Edge TTS + ffmpeg | ❌ 配音联网（可 `--audio`） | 低 |
| `paper-reel` | 9:16 剪纸风无脸短片 | Node + Playwright + whisper.cpp + Kokoro | ✅ 模型后 | **高（建议 WSL）** |
| `khan-explainer` | 白板/黑板讲解（笔迹跟随语音） | Node + Playwright + macOS `say` | ✅（macOS） | **高（默认语音仅 macOS）** |
| `paper-motion-video` | 论文 → 2 分钟解说 + 图表生长 | Python + Kokoro + Playwright + imageio-ffmpeg | ✅ 首次下载后 | **低（有 pmv.cmd）** |
| `ffmpeg-skill` | 已有素材剪辑/转码/字幕/响度 | Python 标准库 + FFmpeg/ffprobe | ✅ 完全离线 | **低（有 Windows CI）** |

## 本机环境缺口（体检结论，2026-10-31）

| 缺口 | 影响 | 修复 |
|---|---|---|
| **FFmpeg/ffprobe 不在 PATH** | 所有流水线 | `winget install --id Gyan.FFmpeg -e`，重开终端 |
| **只有 Python 3.14（+ArcGIS 2.7）** | 5 个流水线 | `winget install Python.Python.3.12`，并始终用 `py -3.12` |
| GitHub `git clone` 被重置 | 拉仓库 | 用 `install-pipelines.ps1` 的镜像/ZIP 回退，或浏览器下载 ZIP |
| Playwright npm 包未全局安装 | 4 个流水线 | `npm i -g playwright && npx playwright install chromium`（浏览器缓存已在） |

修复后跑 `npx -y ffmpeg-skill doctor`，全部通过再开工。

## 脚本速查

| 脚本 | 常用命令 |
|---|---|
| 环境体检 | `.\scripts\env-check.ps1 -Strict -JsonOut env.json` |
| 拉流水线 | `.\scripts\install-pipelines.ps1 -Only paper-reel -Bootstrap` |
| 看清单/状态 | `.\scripts\install-pipelines.ps1 -List` |
| 新建工程 | `.\scripts\new-project.ps1 -Name x -Pipeline ffmpeg-skill -Aspect 9:16` |
| 成片验收 | `.\scripts\verify-output.ps1 -Path out.mp4 -ExpectDuration 30 -ExpectAspect 16:9 -CheckLoudness -ContactSheet contact.png` |

## 常见问题

**Q：装完为什么新会话里没有这个 skill？**
技能目录在会话启动时扫描，需要重启应用/新开会话。确认目录存在：
`C:\Users\ASUS\.agents\skills\local-video-studio\SKILL.md`。

**Q：GitHub 完全连不上怎么办？**
在浏览器打开仓库 → Code → Download ZIP，解压到 `%USERPROFILE%\video-skills\<流水线名>`，
再跑 `install-pipelines.ps1 -List` 确认状态为 `folder (zip)`。上游仓库都是 MIT，可自由使用。

**Q：`paper-reel` / `khan-explainer` 在 Windows 上能跑吗？**
上游只写了 macOS 流程。`paper-reel` 建议 WSL2；`khan-explainer` 默认语音 `say` 是 macOS 专有，
Windows 上可试 `KHAN_TTS=kokoro`（未经验证）或换平台。整合包不会为了"跑通"去接云端 API。

**Q：为什么每个流水线一个 Python 环境？**
Kokoro/whisper/audio 栈的版本互相冲突，且 3.14 没有 wheel。遵循 `environment.md` 的 per-skill venv
策略，不要合并成一个解释器。

**Q：上游仓库更新了怎么办？**
`install-pipelines.ps1 -Update` 只对 git checkout 做 `--ff-only` 拉取；ZIP 安装的用 `-Force` 重下。
生产项目建议在 `notes.md` 记录测试过的 commit。

## 来源与许可

- 7 个上游项目均为 **MIT License**，版权归各自作者；本整合包只提供编排、文档、脚本，不复制其源码。
- 上游默认版本会更新，关键 commit 建议自行 pin。
- 本包按"尽力而为"提供，不保证上游项目的质量或稳定性（尤其 `paper-motion-video` 仓库很新、
  `explainer-video` 已数月未更新）；交付前务必跑各流水线自带的自检（`pmv check`、`reel check`、
  `ffmpeg-skill doctor`、`qa-check.sh`）。
