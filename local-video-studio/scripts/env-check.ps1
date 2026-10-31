<#
.SYNOPSIS
  Local Video Studio - environment health check.

.DESCRIPTION
  Verifies the toolchain the seven local video pipelines need: git, Node/npm,
  Python (3.10-3.12), FFmpeg/ffprobe, Playwright browsers, Edge/Chrome,
  Windows SAPI TTS, PowerShell policy, long-path support and disk space.
  Prints a human-readable report and can emit a JSON report for automation.

.PARAMETER JsonOut
  Optional path to write the report as JSON (e.g. .\env-report.json).

.PARAMETER Strict
  Exit 1 when a CORE tool is missing (git, node, npm, ffmpeg, ffprobe).
  Warnings never fail the run.

.PARAMETER CheckNetwork
  Add a 3-second TCP reachability probe to github.com and its mirrors.

.EXAMPLE
  pwsh -File .\scripts\env-check.ps1

.EXAMPLE
  pwsh -File .\scripts\env-check.ps1 -Strict -JsonOut .\env-report.json
#>
[CmdletBinding()]
param(
    [string]$JsonOut = '',
    [switch]$Strict,
    [switch]$CheckNetwork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$script:rows = New-Object System.Collections.Generic.List[object]

function Add-Row {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Status,       # ok | warn | missing | info
        [string]$Found,
        [string]$Hint = '',
        [bool]$Required = $false
    )
    $script:rows.Add([pscustomobject]@{
        Category = $Category
        Name     = $Name
        Status   = $Status
        Required = $Required
        Found    = $Found
        Hint     = $Hint
    })
}

function Get-ToolVersion {
    param([string]$Exe, [string]$ArgList = '--version', [int]$FirstLines = 1)
    $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    try {
        $out = & $Exe $ArgList.Split(' ') 2>&1 | Select-Object -First $FirstLines
        $text = ($out | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }) -join ' | '
        return [pscustomobject]@{ Path = $cmd.Source; Version = $text }
    } catch {
        return [pscustomobject]@{ Path = $cmd.Source; Version = 'unknown' }
    }
}

function Test-PythonCandidate {
    param([string]$Prefix, [string[]]$ArgList)
    try {
        $out = & $Prefix @ArgList 2>&1 | Select-Object -First 1
        $text = ($out | Out-String).Trim()
        if ($text -match 'Python (\d+)\.(\d+)\.(\d+)') {
            return [pscustomobject]@{
                Text = $text
                Major = [int]$Matches[1]
                Minor = [int]$Matches[2]
                Path  = (Get-Command $Prefix -ErrorAction SilentlyContinue).Source
            }
        }
    } catch { }
    return $null
}

# ---------------------------------------------------------------- categories
Write-Host ''
Write-Host '  Local Video Studio - environment check' -ForegroundColor Cyan
Write-Host ('  ' + ('-' * 58)) -ForegroundColor DarkGray

# git -----------------------------------------------------------------------
$git = Get-ToolVersion -Exe 'git' -ArgList '--version'
if ($git) {
    Add-Row -Category 'core' -Name 'git' -Status 'ok' -Found $git.Version -Required $true
} else {
    Add-Row -Category 'core' -Name 'git' -Status 'missing' -Found '' -Required $true `
        -Hint 'winget install --id Git.Git -e --source winget  (or: https://git-scm.com/download/win)'
}

# node / npm ----------------------------------------------------------------
$node = Get-ToolVersion -Exe 'node' -ArgList '--version'
if ($node -and $node.Version -match 'v(\d+)') {
    $major = [int]$Matches[1]
    $status = if ($major -ge 20) { 'ok' } else { 'warn' }
    $hint = if ($major -ge 20) { '' } else { 'Pipelines expect Node 20+; install from https://nodejs.org (LTS).' }
    Add-Row -Category 'core' -Name 'node' -Status $status -Found $node.Version -Hint $hint -Required $true
} else {
    Add-Row -Category 'core' -Name 'node' -Status 'missing' -Found '' -Required $true `
        -Hint 'winget install OpenJS.NodeJS.LTS  (or https://nodejs.org)'
}

$npm = Get-ToolVersion -Exe 'npm' -ArgList '--version'
if ($npm) {
    Add-Row -Category 'core' -Name 'npm' -Status 'ok' -Found ('v' + $npm.Version) -Required $true
} else {
    Add-Row -Category 'core' -Name 'npm' -Status 'missing' -Found '' -Required $true -Hint 'Ships with Node.js.'
}

# ffmpeg / ffprobe ----------------------------------------------------------
$ffmpeg = Get-ToolVersion -Exe 'ffmpeg' -ArgList '-version'
if ($ffmpeg -and $ffmpeg.Version -match 'ffmpeg version (\S+)') {
    Add-Row -Category 'core' -Name 'ffmpeg' -Status 'ok' -Found $Matches[1] -Required $true
} else {
    Add-Row -Category 'core' -Name 'ffmpeg' -Status 'missing' -Found '' -Required $true `
        -Hint 'winget install --id Gyan.FFmpeg -e --source winget  then reopen the terminal.'
}
$ffprobe = Get-ToolVersion -Exe 'ffprobe' -ArgList '-version'
if ($ffprobe -and $ffprobe.Version -match 'ffprobe version (\S+)') {
    Add-Row -Category 'core' -Name 'ffprobe' -Status 'ok' -Found $Matches[1] -Required $true
} else {
    Add-Row -Category 'core' -Name 'ffprobe' -Status 'missing' -Found '' -Required $true `
        -Hint 'Installed together with FFmpeg (winget Gyan.FFmpeg).'
}

# python --------------------------------------------------------------------
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
$py = $null
if ($pyCmd) { $py = Test-PythonCandidate -Prefix 'python' -ArgList @('--version') }

# discover py-launcher versions (3.10-3.12 preferred)
$pyCandidates = @()
if (Get-Command py -ErrorAction SilentlyContinue) {
    try {
        $pyList = & py -0p 2>&1 | Out-String
        foreach ($line in ($pyList -split "`r?`n")) {
            if ($line -match '^\s*-V:(3\.(?:1[0-2]))\s+\*?\s*(.+)$') {
                $pyCandidates += [pscustomobject]@{ Version = $Matches[1]; Path = $Matches[2].Trim() }
            }
        }
    } catch { }
}

if ($py) {
    $mm = '{0}.{1}' -f $py.Major, $py.Minor
    if ($py.Major -eq 3 -and $py.Minor -ge 10 -and $py.Minor -le 12) {
        Add-Row -Category 'python' -Name 'python (default)' -Status 'ok' -Found $mm
    } elseif ($py.Major -eq 3 -and $py.Minor -ge 13) {
        Add-Row -Category 'python' -Name 'python (default)' -Status 'warn' -Found $mm `
            -Hint ('Python ' + $mm + ' is too new for several pipelines (Kokoro / whisper.cpp / audio libs). Install 3.12: winget install Python.Python.3.12')
    } else {
        Add-Row -Category 'python' -Name 'python (default)' -Status 'warn' -Found $mm `
            -Hint 'Install Python 3.11 or 3.12: winget install Python.Python.3.12'
    }
} else {
    Add-Row -Category 'python' -Name 'python (default)' -Status 'missing' -Found '' `
        -Hint 'Only needed for paper-reel / ffmpeg-skill / paper-motion-video. winget install Python.Python.3.12'
}

if ($pyCandidates.Count -gt 0) {
    $found = ($pyCandidates | ForEach-Object { $_.Version }) -join ', '
    Add-Row -Category 'python' -Name 'py -3.10..3.12' -Status 'ok' -Found $found `
        -Hint 'Prefer: py -3.12 -m pip install ...'
} else {
    Add-Row -Category 'python' -Name 'py -3.10..3.12' -Status 'info' -Found 'none' `
        -Hint 'Recommended for Python pipelines: winget install Python.Python.3.12'
}

# playwright ----------------------------------------------------------------
$pwCache = Join-Path $env:LOCALAPPDATA 'ms-playwright'
$pwBrowsers = @()
if (Test-Path $pwCache) {
    $pwBrowsers = @(Get-ChildItem $pwCache -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(chromium|firefox|webkit|ffmpeg)' } |
        Select-Object -ExpandProperty Name)
}
$pwPkg = $null
try {
    $pwOut = & npx.cmd --no-install playwright --version 2>&1 | Select-Object -First 1
    if ($LASTEXITCODE -eq 0 -and "$pwOut" -match 'Version') { $pwPkg = "$pwOut".Trim() }
} catch { }
if ($pwPkg) {
    Add-Row -Category 'browser' -Name 'playwright (node pkg)' -Status 'ok' -Found $pwPkg
} else {
    Add-Row -Category 'browser' -Name 'playwright (node pkg)' -Status 'warn' -Found 'not resolvable via npx' `
        -Hint 'Needed by claude-motion-design / explainer-video: npm i -g playwright (or per-repo npm install).'
}
if ($pwBrowsers.Count -gt 0) {
    $hasChromium = ($pwBrowsers -match '^chromium').Count -gt 0
    Add-Row -Category 'browser' -Name 'playwright browsers' -Status $(if ($hasChromium) { 'ok' } else { 'warn' }) `
        -Found (($pwBrowsers -join ', ')) -Hint 'Missing chromium: npx playwright install chromium'
} else {
    Add-Row -Category 'browser' -Name 'playwright browsers' -Status 'warn' -Found 'no cache' `
        -Hint 'npx playwright install chromium'
}

# Edge / Chrome -------------------------------------------------------------
$edgePath = $null
$chromePath = $null
foreach ($regRoot in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths')) {
    if (-not $edgePath) {
        $v = (Get-ItemProperty "$regRoot\msedge.exe" -ErrorAction SilentlyContinue).'(default)'
        if ($v -and (Test-Path $v)) { $edgePath = $v }
    }
    if (-not $chromePath) {
        $v = (Get-ItemProperty "$regRoot\chrome.exe" -ErrorAction SilentlyContinue).'(default)'
        if ($v -and (Test-Path $v)) { $chromePath = $v }
    }
}
if ($edgePath) {
    Add-Row -Category 'browser' -Name 'Microsoft Edge' -Status 'ok' -Found $edgePath `
        -Hint 'Used for Edge neural TTS (may need network).'
} else {
    Add-Row -Category 'browser' -Name 'Microsoft Edge' -Status 'warn' -Found '' -Hint 'Standard on Windows 10/11.'
}
if ($chromePath) {
    Add-Row -Category 'browser' -Name 'Google Chrome' -Status 'ok' -Found $chromePath
} else {
    Add-Row -Category 'browser' -Name 'Google Chrome' -Status 'info' -Found 'not installed'
}

# TTS -----------------------------------------------------------------------
$sapi = $null
try {
    $voice = New-Object -ComObject SAPI.SpVoice
    $sapi = 'SAPI.SpVoice available'
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($voice)
} catch { }
if ($sapi) {
    Add-Row -Category 'audio' -Name 'Windows SAPI TTS' -Status 'ok' -Found $sapi `
        -Hint 'Offline voice fallback when Edge TTS needs network.'
} else {
    Add-Row -Category 'audio' -Name 'Windows SAPI TTS' -Status 'warn' -Found 'unavailable' `
        -Hint 'Offline fallback unavailable; Edge TTS / Kokoro only.'
}

# system --------------------------------------------------------------------
$psv = $PSVersionTable.PSVersion.ToString()
$policy = 'unknown'
try { $policy = (Get-ExecutionPolicy -Scope CurrentUser).ToString() } catch { }
$policyOk = $policy -notin @('Restricted', 'AllSigned')
Add-Row -Category 'system' -Name 'PowerShell' -Status 'ok' -Found $psv -Hint '5.1+ works; PowerShell 7 optional.'
if ($policyOk) {
    Add-Row -Category 'system' -Name 'execution policy' -Status 'ok' -Found $policy
} else {
    Add-Row -Category 'system' -Name 'execution policy' -Status 'warn' -Found $policy `
        -Hint 'Run: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

$longPaths = 0
try { $longPaths = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction SilentlyContinue).LongPathsEnabled } catch { }
Add-Row -Category 'system' -Name 'long paths' -Status $(if ($longPaths -eq 1) { 'ok' } else { 'warn' }) `
    -Found $(if ($longPaths -eq 1) { 'enabled' } else { 'disabled' }) `
    -Hint 'Enable: Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -Value 1'

try {
    $drive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
    $freeGb = [math]::Round($drive.Free / 1GB, 1)
    Add-Row -Category 'system' -Name 'free disk (C:)' -Status $(if ($freeGb -ge 10) { 'ok' } else { 'warn' }) -Found "$freeGb GB" `
        -Hint 'Rendering + model downloads want >10 GB free.'
} catch { }

if ($CheckNetwork) {
    foreach ($hostName in @('github.com', 'ghproxy.net', 'gitclone.com')) {
        $ok = $false
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $task = $client.ConnectAsync($hostName, 443)
            $ok = $task.Wait(3000) -and $client.Connected
            $client.Close()
        } catch { }
        Add-Row -Category 'network' -Name $hostName -Status $(if ($ok) { 'ok' } else { 'warn' }) -Found $(if ($ok) { 'reachable:443' } else { 'unreachable' })
    }
}

# ---------------------------------------------------------------- report
$ordered = $script:rows | Sort-Object @{ Expression = { @{ core = 0; python = 1; browser = 2; audio = 3; system = 4; network = 5 }[$_.Category] } }
$icon = @{ ok = '[ok]'; warn = '[!] '; missing = '[X] '; info = '[i] ' }
$color = @{ ok = 'Green'; warn = 'Yellow'; missing = 'Red'; info = 'Gray' }

foreach ($r in $ordered) {
    $line = '{0} {1,-24} {2}' -f $icon[$r.Status], $r.Name, $r.Found
    Write-Host $line -ForegroundColor $color[$r.Status]
    if ($r.Hint -and $r.Status -ne 'ok') { Write-Host ('      -> ' + $r.Hint) -ForegroundColor DarkGray }
}

$missingRequired = @($script:rows | Where-Object { $_.Required -and $_.Status -eq 'missing' })
$warns = @($script:rows | Where-Object { $_.Status -eq 'warn' })
Write-Host ''
if ($missingRequired.Count -gt 0) {
    Write-Host ('  BLOCKER: ' + $missingRequired.Count + ' required tool(s) missing: ' + (($missingRequired | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Red
    Write-Host '  Fix these before cloning or rendering. See references/environment.md.' -ForegroundColor Red
} else {
    Write-Host '  Core toolchain OK.' -ForegroundColor Green
}
if ($warns.Count -gt 0) {
    Write-Host ('  Warnings: ' + $warns.Count + ' (see hints above)') -ForegroundColor Yellow
}

if ($JsonOut) {
    $report = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        computer    = $env:COMPUTERNAME
        coreOk      = ($missingRequired.Count -eq 0)
        rows        = $script:rows
    }
    $dir = Split-Path -Parent $JsonOut
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $report | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonOut -Encoding UTF8
    Write-Host ('  JSON report: ' + (Resolve-Path $JsonOut)) -ForegroundColor DarkGray
}

if ($Strict -and $missingRequired.Count -gt 0) { exit 1 }
exit 0


