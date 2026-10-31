<#
.SYNOPSIS
  Install the local-video-studio skill into the DSH/Claude skills directory.

.DESCRIPTION
  Copies the local-video-studio folder (next to this script) into
  %USERPROFILE%\.agents\skills\local-video-studio, or the project skills directory
  with -Project. Unblocks the copied files (ZIP downloads carry Mark-of-the-Web).
  Restart the app / start a new session afterwards so the skill catalog refreshes.

.PARAMETER Project
  Install into <current directory>\.agents\skills instead of the user-level directory.

.PARAMETER Force
  Overwrite an existing installation. Without it, an existing install is updated in
  place (missing files copied, changed files overwritten) after a confirmation-free notice.

.PARAMETER SkillRoot
  Override the user skills root (default: $HOME\.agents\skills).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-skill.ps1

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-skill.ps1 -Project
#>
[CmdletBinding()]
param(
    [switch]$Project,
    [switch]$Force,
    [string]$SkillRoot = (Join-Path $HOME '.agents\skills')
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host ('[X] ' + $Message) -ForegroundColor Red
    exit 1
}

$source = Join-Path $PSScriptRoot 'local-video-studio'
if (-not (Test-Path $source)) { $source = $PSScriptRoot }
if (-not (Test-Path (Join-Path $source 'SKILL.md'))) {
    Fail ('SKILL.md not found in ' + $source + '. Run this script from the extracted pack root.')
}

$targetRoot = if ($Project) { Join-Path (Get-Location).Path '.agents\skills' } else { $SkillRoot }
$target = Join-Path $targetRoot 'local-video-studio'

Write-Host ''
Write-Host '  Local Video Studio - skill installer' -ForegroundColor Cyan
Write-Host ('  Source: ' + $source) -ForegroundColor DarkGray
Write-Host ('  Target: ' + $target) -ForegroundColor DarkGray
Write-Host ''

if (Test-Path $target) {
    if ($Force) {
        Write-Host '  Removing existing installation (-Force)' -ForegroundColor Yellow
        Remove-Item -Recurse -Force $target
    } else {
        Write-Host '  Existing installation found: updating files in place (no deletion)' -ForegroundColor Yellow
    }
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
New-Item -ItemType Directory -Force -Path $target | Out-Null

# Copy the whole skill folder, then refresh package files so stale scripts are replaced.
Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force

# Remove Mark-of-the-Web so PowerShell allows the downloaded .ps1 files.
try {
    Get-ChildItem -Path $target -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
} catch {
    Write-Host '  [!] Unblock-File skipped (some files may still need manual unblocking)' -ForegroundColor Yellow
}

$verify = Join-Path $target 'SKILL.md'
if (-not (Test-Path $verify)) { Fail ('Install verification failed: ' + $verify + ' missing.') }

$fileCount = (Get-ChildItem -Path $target -Recurse -File).Count
Write-Host ('  Installed: ' + $fileCount + ' files') -ForegroundColor Green
Write-Host ''
Write-Host '  Next steps:' -ForegroundColor Cyan
Write-Host '   1. Restart the app or start a new session so the skill catalog refreshes.' -ForegroundColor DarkGray
Write-Host '   2. Run the environment check:' -ForegroundColor DarkGray
Write-Host ('      powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $target 'scripts\env-check.ps1') + '"') -ForegroundColor DarkGray
Write-Host '   3. Read the usage guide:' -ForegroundColor DarkGray
Write-Host ('      ' + (Join-Path $target 'README.md')) -ForegroundColor DarkGray
