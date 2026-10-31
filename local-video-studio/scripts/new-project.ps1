<#
.SYNOPSIS
  Local Video Studio - scaffold a new video project.

.DESCRIPTION
  Creates projects/<slug>/ with brief.md, storyboard.md, notes.md, project.json
  and the standard folder layout (assets, audio, shots, renders). Templates come
  from the skill's assets/ folder.

.PARAMETER Name
  Project name; becomes the folder name (spaces allowed, converted to dashes).

.PARAMETER Pipeline
  Pipeline this project targets (optional, can be decided later).

.PARAMETER OutRoot
  Where project folders are created. Default: $HOME\video-projects.

.PARAMETER Aspect
  Delivery aspect ratio: 16:9, 9:16, 1:1, 4:5 or 21:9.

.PARAMETER DurationSec
  Target duration in seconds.

.PARAMETER Force
  Keep going if the folder already exists (never deletes existing files).

.EXAMPLE
  .\scripts\new-project.ps1 -Name "brand-launch" -Pipeline claude-motion-design -Aspect 16:9 -DurationSec 30

.EXAMPLE
  .\scripts\new-project.ps1 -Name "paper-summary" -Pipeline paper-motion-video -Aspect 9:16 -DurationSec 120
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^<>:"/\\|?*\p{Cc}]{1,64}$')]
    [string]$Name,

    [ValidateSet('', 'claude-motion-design', 'code-video-showcase', 'explainer-video', 'paper-reel', 'khan-explainer', 'paper-motion-video', 'ffmpeg-skill')]
    [string]$Pipeline = '',

    [string]$OutRoot = (Join-Path $HOME 'video-projects'),

    [ValidateSet('16:9', '9:16', '1:1', '4:5', '21:9')]
    [string]$Aspect = '16:9',

    [ValidateRange(3, 7200)]
    [int]$DurationSec = 30,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host ('[X] ' + $Message) -ForegroundColor Red
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '[!] git not found - OK for scaffolding, needed only to clone pipelines.' -ForegroundColor Yellow
}

$slug = ($Name.ToLowerInvariant() -replace '[ _]+', '-') -replace '[^a-z0-9\-\p{IsCJKUnifiedIdeographs}]', ''
$slug = $slug.Trim('-')
if (-not $slug) { Fail 'Name produced an empty folder name; use letters/digits/Chinese characters.' }

$dest = Join-Path $OutRoot $slug
if (Test-Path $dest) {
    if (-not $Force) {
        Fail ('Folder already exists: ' + $dest + '  (use -Force to add missing files without deleting anything)')
    }
    Write-Host ('[i] Reusing existing folder: ' + $dest) -ForegroundColor DarkGray
}

$skillRoot = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $skillRoot 'assets'
$briefTpl = Join-Path $assets 'brief-template.md'
$storyTpl = Join-Path $assets 'storyboard-template.md'
if (-not (Test-Path $briefTpl) -or -not (Test-Path $storyTpl)) {
    Fail ('Templates missing under ' + $assets + ' - is this the local-video-studio skill folder?')
}

$subdirs = @('assets', 'audio', 'shots', 'renders')
foreach ($sub in $subdirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $dest $sub) | Out-Null
}

$pipelineLabel = if ($Pipeline) { $Pipeline } else { 'TBD (see references/selection-matrix.md)' }
$tokens = @{
    '{{PROJECT}}'  = $Name
    '{{SLUG}}'     = $slug
    '{{PIPELINE}}' = $pipelineLabel
    '{{ASPECT}}'   = $Aspect
    '{{DURATION}}' = [string]$DurationSec
    '{{DATE}}'     = (Get-Date).ToString('yyyy-MM-dd')
}

function Expand-Template {
    param([string]$Path, [string]$Target)
    $text = Get-Content -Raw -Path $Path
    foreach ($k in $tokens.Keys) { $text = $text.Replace($k, $tokens[$k]) }
    Set-Content -Path $Target -Value $text -Encoding UTF8
}

Expand-Template -Path $briefTpl -Target (Join-Path $dest 'brief.md')
Expand-Template -Path $storyTpl -Target (Join-Path $dest 'storyboard.md')

$notes = @"
# $Name - working notes

- Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- Pipeline: $pipelineLabel
- Target: $Aspect, $DurationSec s

## Decisions

## Attempts / failures

## Timing
"@
Set-Content -Path (Join-Path $dest 'notes.md') -Value $notes -Encoding UTF8

$project = [pscustomobject]@{
    name        = $Name
    slug        = $slug
    pipeline    = $Pipeline
    aspect      = $Aspect
    durationSec = $DurationSec
    createdAt   = (Get-Date).ToString('o')
}
$project | ConvertTo-Json | Set-Content -Path (Join-Path $dest 'project.json') -Encoding UTF8

Write-Host ''
Write-Host ('  Project ready: ' + $dest) -ForegroundColor Green
Write-Host '  Next: fill brief.md + storyboard.md, then follow the pipeline reference.' -ForegroundColor DarkGray
Get-ChildItem $dest -Force | Select-Object Mode, Name | Format-Table -AutoSize

