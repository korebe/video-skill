<#
.SYNOPSIS
  Local Video Studio - clone / update the seven upstream video pipelines.

.DESCRIPTION
  Clones the upstream repositories listed in scripts/pipelines.json into a vendor
  root (default: %USERPROFILE%\video-skills). Falls back through GitHub mirrors and
  finally a ZIP download when git clone fails (common on restricted networks).
  Vendored repos are dependencies: keep your work in the project folder, not here.

.PARAMETER Root
  Vendor root for the cloned repos. Default: %USERPROFILE%\video-skills.

.PARAMETER Only
  One or more pipeline names (comma-separated or repeated). Default: all.

.PARAMETER DryRun
  Show what would be done without cloning, downloading or writing.

.PARAMETER Update
  git pull --ff-only repos that are already cloned.

.PARAMETER Force
  Delete an existing target folder and re-download it (use only when reinstall is needed).

.PARAMETER Bootstrap
  After cloning, run the dependency-install commands from pipelines.json
  (npm install / pip install -r requirements.txt). Long-running; failures are logged.

.PARAMETER Mirror
  Custom mirror URL prefix applied to the canonical GitHub URL, e.g.
  https://ghproxy.net/  ->  https://ghproxy.net/https://github.com/<owner>/<repo>.git
  A template containing {owner} and {repo} is also accepted.

.PARAMETER NoMirrors
  Do not try the built-in mirrors (ghproxy.net, gitclone.com, kkgithub.com).

.PARAMETER NoZipFallback
  Do not fall back to downloading a ZIP archive when all git attempts fail.

.PARAMETER List
  List pipelines, canonical URLs and local clone status, then exit.

.EXAMPLE
  .\scripts\install-pipelines.ps1 -DryRun

.EXAMPLE
  .\scripts\install-pipelines.ps1 -Only claude-motion-design,explainer-video

.EXAMPLE
  .\scripts\install-pipelines.ps1 -Only paper-reel -Mirror https://ghproxy.net/ -Bootstrap
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $HOME 'video-skills'),

    [string[]]$Only = @(),

    [switch]$DryRun,

    [switch]$Update,

    [switch]$Force,

    [switch]$Bootstrap,

    [string]$Mirror = '',

    [switch]$NoMirrors,

    [switch]$NoZipFallback,

    [switch]$List
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------- helpers
function Write-Info([string]$Text) { Write-Host ('[i] ' + $Text) -ForegroundColor DarkGray }
function Write-Ok([string]$Text) { Write-Host ('[ok] ' + $Text) -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host ('[!] ' + $Text) -ForegroundColor Yellow }
function Write-Err([string]$Text) { Write-Host ('[X] ' + $Text) -ForegroundColor Red }

$manifestPath = Join-Path $PSScriptRoot 'pipelines.json'
if (-not (Test-Path $manifestPath)) {
    Write-Err ('Manifest not found: ' + $manifestPath)
    exit 1
}
$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
$all = @($manifest.pipelines)

# ---------------------------------------------------------------- selection
$selected = $all
if ($Only.Count -gt 0) {
    $wanted = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $invalid = @($wanted | Where-Object { $n = $_; -not ($all | Where-Object { $_.name -eq $n }) })
    if ($invalid.Count -gt 0) {
        Write-Err ('Unknown pipeline(s): ' + ($invalid -join ', '))
        Write-Host ('Valid names: ' + (($all | ForEach-Object { $_.name }) -join ', ')) -ForegroundColor Yellow
        exit 1
    }
    $selected = @($all | Where-Object { $wanted -contains $_.name })
}

$canonical = {
    param($p)
    'https://github.com/{0}/{1}.git' -f $p.owner, $p.repo
}

$resolvedRoot = $Root
if (-not [System.IO.Path]::IsPathRooted($resolvedRoot)) {
    $resolvedRoot = Join-Path (Get-Location).Path $resolvedRoot
}

# ---------------------------------------------------------------- list mode
if ($List) {
    Write-Host ''
    Write-Host '  Local Video Studio - pipeline manifest' -ForegroundColor Cyan
    Write-Host ''
    foreach ($p in $all) {
        $dest = Join-Path $resolvedRoot $p.name
        $state = 'not cloned'
        if (Test-Path (Join-Path $dest '.git')) { $state = 'git clone' }
        elseif (Test-Path $dest) { $state = 'folder (zip)' }
        $verified = if ($p.verified) { 'verified' } else { 'UNVERIFIED' }
        Write-Host ('  {0,-24} {1,-16} {2,-12} {3}' -f $p.name, $state, $verified, (& $canonical $p)) -ForegroundColor $(if ($state -eq 'not cloned') { 'Gray' } else { 'Green' })
    }
    Write-Host ''
    Write-Host ('  Vendor root: ' + $resolvedRoot) -ForegroundColor DarkGray
    Write-Host ('  Reference:   ' + (Split-Path -Parent $PSScriptRoot) + '\references\pipelines\') -ForegroundColor DarkGray
    exit 0
}

# ---------------------------------------------------------------- preflight
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git -and -not $DryRun) {
    Write-Err 'git not found. Install Git first (winget install --id Git.Git -e), or use -DryRun to inspect the plan.'
    exit 1
}

Write-Host ''
Write-Host '  Local Video Studio - pipeline installer' -ForegroundColor Cyan
Write-Host ('  Vendor root: ' + $resolvedRoot) -ForegroundColor DarkGray
if ($DryRun) { Write-Host '  DRY RUN: no files will be written.' -ForegroundColor Yellow }
Write-Host ''

if (-not $DryRun -and -not (Test-Path $resolvedRoot)) {
    New-Item -ItemType Directory -Force -Path $resolvedRoot | Out-Null
    Write-Info ('Created vendor root: ' + $resolvedRoot)
}

# ---------------------------------------------------------------- per-pipeline
$results = New-Object System.Collections.Generic.List[object]

function Invoke-GitClone {
    param([string]$Url, [string]$Destination, [int]$TimeoutSec)
    $lowSpeedTime = [math]::Max(10, $TimeoutSec)
    $gitArgs = @(
        '-c', 'http.lowSpeedLimit=1000',
        '-c', ('http.lowSpeedTime=' + $lowSpeedTime),
        'clone', '--depth', '1', '--quiet', $Url, $Destination
    )
    Write-Info ('    git clone ' + $Url)
    & git @gitArgs 2>&1 | ForEach-Object { Write-Host ('      ' + $_.ToString()) -ForegroundColor DarkGray }
    return ($LASTEXITCODE -eq 0)
}

function Invoke-ZipFallback {
    param($Pipeline, [string]$Destination, [string]$BranchHint)
    $branches = @($BranchHint, 'main', 'master') | Where-Object { $_ } | Select-Object -Unique
    $templates = @(
        'https://ghproxy.net/https://github.com/{0}/{1}/archive/refs/heads/{2}.zip',
        'https://codeload.github.com/{0}/{1}/zip/refs/heads/{2}',
        'https://github.com/{0}/{1}/archive/refs/heads/{2}.zip'
    )
    foreach ($branch in $branches) {
        foreach ($tpl in $templates) {
            $url = $tpl -f $Pipeline.owner, $Pipeline.repo, $branch
            $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ($Pipeline.name + '-' + [guid]::NewGuid().ToString('N') + '.zip')
            try {
                Write-Info ('    zip download ' + $url)
                Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
                if ((Get-Item $tmpZip).Length -lt 1000) { throw 'archive too small' }
                $extract = Join-Path ([System.IO.Path]::GetTempPath()) ($Pipeline.name + '-extract-' + [guid]::NewGuid().ToString('N'))
                Expand-Archive -Path $tmpZip -DestinationPath $extract -Force -ErrorAction Stop
                $inner = @(Get-ChildItem $extract -Directory)
                if ($inner.Count -eq 0) { throw 'archive has no top folder' }
                if (Test-Path $Destination) { Remove-Item -Recurse -Force $Destination }
                Move-Item -Path $inner[0].FullName -Destination $Destination
                Remove-Item -Recurse -Force $extract, $tmpZip -ErrorAction SilentlyContinue
                return $true
            } catch {
                Remove-Item -Force $tmpZip -ErrorAction SilentlyContinue
            }
        }
    }
    return $false
}

foreach ($p in $selected) {
    $dest = Join-Path $resolvedRoot $p.name
    Write-Host ('  ' + $p.name) -ForegroundColor White
    $record = [pscustomobject]@{ name = $p.name; status = ''; method = ''; path = $dest; detail = '' }

    if ($DryRun) {
        $url = & $canonical $p
        $state = if (Test-Path $dest) { 'exists -> ' + $(if ($Update) { 'update' } else { 'skip' }) } else { 'clone' }
        Write-Info ('    DRY: ' + $state + '  ' + $url)
        if (@($p.bootstrap).Count -gt 0) { Write-Info ('    DRY bootstrap: ' + (@($p.bootstrap) -join ' ; ')) }
        $record.status = 'planned'; $record.method = 'dry-run'
        $results.Add($record)
        continue
    }

    if (Test-Path $dest) {
        if ($Force) {
            Write-Warn ('    -Force: removing existing ' + $dest)
            Remove-Item -Recurse -Force $dest
        } elseif ($Update -and (Test-Path (Join-Path $dest '.git'))) {
            Write-Info '    updating (git pull --ff-only)'
            & git -C $dest pull --ff-only 2>&1 | ForEach-Object { Write-Host ('      ' + $_.ToString()) -ForegroundColor DarkGray }
            if ($LASTEXITCODE -eq 0) {
                Write-Ok '    updated'
                $record.status = 'updated'; $record.method = 'git-pull'
            } else {
                Write-Warn '    update failed; keeping existing checkout'
                $record.status = 'update-failed'; $record.method = 'git-pull'
            }
            $results.Add($record); continue
        } else {
            $kind = if (Test-Path (Join-Path $dest '.git')) { 'git checkout' } else { 'folder (not a git checkout)' }
            Write-Info ('    already present (' + $kind + '); use -Update or -Force to change it')
            $record.status = 'present'; $record.method = 'none'
            $results.Add($record); continue
        }
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $canonicalUrl = & $canonical $p
    if ($Mirror) {
        if ($Mirror -match '\{owner\}') {
            $mirrorUrl = $Mirror.Replace('{owner}', $p.owner).Replace('{repo}', $p.repo)
            $candidates.Add($mirrorUrl)
        } else {
            $candidates.Add([string]::Concat($Mirror.TrimEnd('/'), '/', $canonicalUrl))
        }
    }
    $candidates.Add($canonicalUrl)
    if (-not $NoMirrors) {
        $candidates.Add('https://ghproxy.net/' + $canonicalUrl)
        $candidates.Add(('https://gitclone.com/github.com/{0}/{1}.git' -f $p.owner, $p.repo))
        $candidates.Add(('https://kkgithub.com/{0}/{1}.git' -f $p.owner, $p.repo))
    }

    $cloned = $false
    foreach ($url in $candidates) {
        if (Invoke-GitClone -Url $url -Destination $dest -TimeoutSec 45) {
            $cloned = $true
            $record.method = if ($url -eq $canonicalUrl) { 'git' } else { 'git-mirror' }
            break
        }
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue }
        Write-Warn '    attempt failed, trying next source'
    }

    if (-not $cloned -and -not $NoZipFallback) {
        Write-Warn '    git sources failed; falling back to ZIP archive'
        if (Invoke-ZipFallback -Pipeline $p -Destination $dest -BranchHint $p.branch) {
            $cloned = $true
            $record.method = 'zip'
            Write-Ok '    downloaded and extracted'
        }
    }

    if ($cloned) {
        $record.status = 'cloned'
        Write-Ok ('    ready: ' + $dest)
    } else {
        $record.status = 'failed'
        Write-Err ('    could not fetch ' + $p.name + ' from any source')
        Write-Host ('      Manual fallback: download ' + $canonicalUrl + ' as ZIP in a browser, extract to: ' + $dest) -ForegroundColor Yellow
    }

    if ($cloned -and $Bootstrap -and @($p.bootstrap).Count -gt 0) {
        foreach ($cmd in $p.bootstrap) {
            Write-Info ('    bootstrap: ' + $cmd)
            Push-Location $dest
            try {
                & cmd /c $cmd 2>&1 | ForEach-Object { Write-Host ('      ' + $_.ToString()) -ForegroundColor DarkGray }
                if ($LASTEXITCODE -ne 0) { Write-Warn ('    bootstrap command exited ' + $LASTEXITCODE + ': ' + $cmd) }
            } catch {
                Write-Warn ('    bootstrap failed: ' + $cmd)
            } finally {
                Pop-Location
            }
        }
    }

    $results.Add($record)
}

# ---------------------------------------------------------------- summary
Write-Host ''
Write-Host '  Summary' -ForegroundColor Cyan
$failedCount = 0
foreach ($r in $results) {
    $okStatuses = @('cloned', 'updated', 'present', 'planned')
    $color = if ($okStatuses -contains $r.status) { 'Green' } elseif ($r.status -match 'failed') { 'Red' } else { 'Yellow' }
    if ($r.status -match 'failed') { $failedCount++ }
    Write-Host ('  {0,-24} {1,-14} {2,-10} {3}' -f $r.name, $r.status, $r.method, $r.path) -ForegroundColor $color
}

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    vendorRoot  = $resolvedRoot
    dryRun      = [bool]$DryRun
    results     = $results
}
$report | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path ([System.IO.Path]::GetTempPath()) 'lvs-install-report.json') -Encoding UTF8

if (-not $DryRun) {
    Write-Host ''
    Write-Host '  Next steps: open references/pipelines/<pipeline>.md for build commands.' -ForegroundColor DarkGray
    Write-Host '  Bootstrap dependencies with -Bootstrap, or run the commands shown in the reference.' -ForegroundColor DarkGray
}

if ($failedCount -gt 0) { exit 1 }
exit 0

