# Video Skill · Local Video Studio

把 7 个「纯本地、不集成外部 API」的开源视频制作项目，整合成 **1 个可直接安装的 Agent Skill 包**：
统一选型入口、统一环境体检、统一仓库拉取（含 GitHub 镜像回退）、统一成片验收。

**不接任何外部 API、不需要任何 Key、不调用云端渲染或云端 TTS。**
（唯一例外：`explainer-video` 的 Edge TTS 需要联网；包内提供 `--audio` 离线替代方案。）

> 上游 7 个仓库已于 **2026-10-31** 逐一核验（GitHub API + README），全部 MIT、全部 `main` 分支；
> 核验记录见 [`docs/repo-findings.md`](docs/repo-findings.md)。

## 包含的 7 条流水线

| 流水线 | 用途 | 技术栈 | 离线 | Windows 风险 |
|---|---|---|---|---|
| [`claude-motion-design`](https://github.com/howseen-ai/claude-motion-design) | 宣传片 / 品牌动效 / 产品发布 | Python + HTML/Canvas + Playwright + ffmpeg | ✅ 素材抓取后 | 中（文档只有 POSIX；无配音） |
| [`code-video-showcase`](https://github.com/Moessif/code-video-showcase) | 30–90s 风格化卡点展示片 | Node≥20 + Playwright + FFmpeg + Python | ✅ 依赖+字体后 | 低-中（`.sh` 助手走 Git Bash） |
| [`explainer-video`](https://github.com/Mng-dev-ai/explainer-video) | 通用解说 / 教学动画（最快） | Node + Playwright + Edge TTS + ffmpeg | ❌ 配音联网（可 `--audio`） | 低 |
| [`paper-reel`](https://github.com/haiderfarooq3/paper-reel) | 9:16 剪纸风无脸短片 | Node + Playwright + whisper.cpp + Kokoro | ✅ 模型后 | **高（建议 WSL）** |
| [`khan-explainer`](https://github.com/haiderfarooq3/khan-explainer) | 白板/黑板讲解（笔迹跟随语音） | Node + Playwright + macOS `say` | ✅（macOS） | **高（默认语音仅 macOS）** |
| [`paper-motion-video`](https://github.com/DjoFE2021/paper-motion-video) | 论文 → 2 分钟解说 + 图表生长 | Python + Kokoro + Playwright + imageio-ffmpeg | ✅ 首次下载后 | **低（有 pmv.cmd）** |
| [`ffmpeg-skill`](https://github.com/kajisho5/ffmpeg-skill) | 已有素材剪辑/转码/字幕/响度 | Python 标准库 + FFmpeg/ffprobe | ✅ 完全离线 | **低（有 Windows CI）** |

## 安装

### 一键安装（推荐）

```powershell
git clone https://github.com/korebe/video-skill.git
cd video-skill
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-skill.ps1
```

安装到 `C:\Users\<你>\.agents\skills\local-video-studio\` 后，**重启应用/新开会话**，技能目录即可用。

### 手动安装

```powershell
Copy-Item -Recurse -Force .\local-video-studio "$HOME\.agents\skills\"
Get-ChildItem -Recurse "$HOME\.agents\skills\local-video-studio" | Unblock-File
```

## 快速开始（装好后）

```powershell
$skill = "$HOME\.agents\skills\local-video-studio"

# 1) 环境体检（缺 FFmpeg / Python 3.12 会给出修复命令）
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\env-check.ps1"

# 2) 拉取某条流水线仓库（GitHub 被墙时自动镜像/ZIP 回退）
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-pipelines.ps1" -List
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-pipelines.ps1" -Only ffmpeg-skill

# 3) 建工程 → 按 references/pipelines/<流水线>.md 制作 → 验收
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\new-project.ps1" -Name "my-video" -Pipeline ffmpeg-skill
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\verify-output.ps1" -Path renders\out.mp4 -ExpectAspect 16:9 -CheckLoudness
```

## 目录结构

```
.
├── local-video-studio/            # 技能本体（SKILL.md + references + scripts + assets）
│   ├── SKILL.md                   # 技能入口：约束、选型路由、工作流、质量门禁
│   ├── README.md                  # 详细中文使用说明
│   ├── references/
│   │   ├── selection-matrix.md    # 7 条流水线对比 + 选型 + Windows 风险分层
│   │   ├── environment.md         # Windows 工具链、国内镜像、字体、TTS 矩阵
│   │   ├── troubleshooting.md     # 现象 → 原因 → 修复
│   │   └── pipelines/             # 7 份逐流水线实操手册
│   ├── scripts/                   # env-check / install-pipelines / new-project / verify-output
│   └── assets/                    # brief 模板 + 分镜模板
├── install-skill.ps1              # 一键安装脚本
├── docs/repo-findings.md          # 上游 7 个仓库的核验记录
└── LICENSE
```

## 环境要求

- Node ≥ 20、Git、**Python 3.10–3.12**（不要用 3.13/3.14）、**完整版 FFmpeg 5.0+**
  （`libass`/`drawtext`/`zscale`/`loudnorm`/`xfade`/`scdet`/`vidstab`）；Windows 上 bash 辅助脚本需 Git Bash。
- 一次环境体检：`npx -y ffmpeg-skill doctor`（全包 FFmpeg 能力冒烟测试）。

## 许可

- 本仓库（编排、文档、脚本）MIT，见 [`LICENSE`](LICENSE)。
- 7 个上游项目均为 MIT License，版权归各自作者；本仓库不复制其源码，只在运行时按需拉取。
