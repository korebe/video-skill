<#
.SYNOPSIS
  Local Video Studio - verify a rendered video with ffprobe/ffmpeg.

.DESCRIPTION
  Checks container, duration, resolution/aspect, pixel format, audio streams and
  (optionally) EBU R128 loudness; can render a contact sheet for visual review.
  Exit code: 0 = all checks passed, 1 = at least one check failed.

.PARAMETER Path
  Video file to verify.

.PARAMETER ExpectDuration
  Expected duration in seconds (0 = skip). Default tolerance ±0.5 s.

.PARAMETER ExpectAspect
  Expected aspect ratio such as 16:9, 9:16, 1:1, 4:5, 21:9 (empty = skip).

.PARAMETER CheckLoudness
  Measure integrated loudness and true peak; warn outside -18..-14 LUFS / peak > -1 dBTP.

.PARAMETER ContactSheet
  Optional output PNG path; renders N frames tiled into one image for review.

.PARAMETER SheetFrames
  Number of frames in the contact sheet (default 8).

.EXAMPLE
  .\scripts\verify-output.ps1 -Path renders\out.mp4 -ExpectDuration 30 -ExpectAspect 16:9 -CheckLoudness -ContactSheet renders\contact.png
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [double]$ExpectDuration = 0,

    [string]$ExpectAspect = '',

    [switch]$CheckLoudness,

    [string]$ContactSheet = '',

    [ValidateRange(4, 30)]
    [int]$SheetFrames = 8
)

$ErrorActionPreference = 'Continue'

$results = New-Object System.Collections.Generic.List[object]
$failed = 0

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('pass', 'fail', 'warn', 'skip')]
        [string]$Status,
        [string]$Detail
    )
    if ($Status -eq 'fail') { $script:failed++ }
    $script:results.Add([pscustomobject]@{ Check = $Name; Status = $Status; Detail = $Detail })
}

function Resolve-Tool([string]$Exe) {
    $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$ffprobe = Resolve-Tool 'ffprobe'
$ffmpeg = Resolve-Tool 'ffmpeg'
if (-not $ffprobe -or -not $ffmpeg) {
    Write-Host '[X] ffmpeg/ffprobe not found on PATH. Install them first (references/environment.md).' -ForegroundColor Red
    exit 1
}

if (-not $Path -or -not (Test-Path $Path -PathType Leaf)) {
    Write-Host ('[X] File not found: ' + $Path) -ForegroundColor Red
    exit 1
}
$full = (Resolve-Path $Path).Path
$sizeMb = [math]::Round((Get-Item $full).Length / 1MB, 2)
Add-Check -Name 'file exists' -Status $(if ($sizeMb -gt 0) { 'pass' } else { 'fail' }) -Detail ("$full ($sizeMb MB)")

# --- ffprobe ---------------------------------------------------------------
$probeRaw = & $ffprobe -v error -print_format json -show_format -show_streams $full 2>&1 | Out-String
$probe = $null
try { $probe = $probeRaw | ConvertFrom-Json } catch { }
if (-not $probe -or -not $probe.streams) {
    Add-Check -Name 'ffprobe parse' -Status 'fail' -Detail 'Could not read media info (file may be corrupt).'
} else {
    $video = @($probe.streams | Where-Object { $_.codec_type -eq 'video' })[0]
    $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })[0]

    if (-not $video) {
        Add-Check -Name 'video stream' -Status 'fail' -Detail 'No video stream.'
    } else {
        Add-Check -Name 'video stream' -Status 'pass' -Detail ("$($video.codec_name) $($video.width)x$($video.height) $($video.pix_fmt) fps=$($video.avg_frame_rate)")
        if ($video.pix_fmt -and $video.pix_fmt -ne 'yuv420p') {
            Add-Check -Name 'pixel format' -Status 'warn' -Detail ("$($video.pix_fmt) (yuv420p is the compatibility default)")
        }
        if ($ExpectAspect -and $ExpectAspect -match '^\s*(\d+)\s*:\s*(\d+)\s*$') {
            $want = [double]$Matches[1] / [double]$Matches[2]
            $got = [double]$video.width / [double]$video.height
            $diff = [math]::Abs($want - $got) / $want
            Add-Check -Name 'aspect ratio' -Status $(if ($diff -le 0.02) { 'pass' } else { 'fail' }) `
                -Detail ("expected $ExpectAspect, got $($video.width)x$($video.height) (ratio $([math]::Round($got, 3)))")
        }
        $rate = $video.avg_frame_rate
        if ($rate -match '^(\d+)/(\d+)$' -and [double]$Matches[2] -gt 0) {
            $fps = [double]$Matches[1] / [double]$Matches[2]
            if ($fps -lt 23 -or $fps -gt 61) {
                Add-Check -Name 'frame rate' -Status 'warn' -Detail ("$([math]::Round($fps, 2)) fps is outside 24-60")
            }
        }
    }

    if (-not $audio) {
        Add-Check -Name 'audio stream' -Status 'fail' -Detail 'No audio stream (add voice/music or confirm intentional silence).'
    } else {
        $ch = $audio.channels
        Add-Check -Name 'audio stream' -Status 'pass' -Detail ("$($audio.codec_name) $($audio.sample_rate)Hz ${ch}ch")
        if ([int]$audio.sample_rate -lt 44100) {
            Add-Check -Name 'audio quality' -Status 'warn' -Detail ("$($audio.sample_rate) Hz < 44.1 kHz")
        }
    }

    $durText = $probe.format.duration
    $dur = 0.0
    if ($durText -and [double]::TryParse($durText, [ref]$dur)) {
        if ($ExpectDuration -gt 0) {
            $tol = [math]::Max(0.5, 0.05 * $ExpectDuration)
            $delta = [math]::Abs($dur - $ExpectDuration)
            Add-Check -Name 'duration' -Status $(if ($delta -le $tol) { 'pass' } else { 'fail' }) `
                -Detail ("expected $ExpectDuration s, got $([math]::Round($dur, 3)) s (Δ $([math]::Round($delta, 3)) s)")
        } else {
            Add-Check -Name 'duration' -Status 'pass' -Detail ("$([math]::Round($dur, 3)) s")
        }
    } else {
        Add-Check -Name 'duration' -Status 'warn' -Detail 'Duration unknown.'
    }
}

# --- loudness --------------------------------------------------------------
if ($CheckLoudness) {
    $loudRaw = & $ffmpeg -hide_banner -nostats -i $full -af 'ebur128=peak=true' -f null - 2>&1 | Out-String
    $integrated = $null
    $peak = $null
    $luMatches = [regex]::Matches($loudRaw, 'I:\s+(-?\d+(?:\.\d+)?)\s+LUFS')
    if ($luMatches.Count -gt 0) { $integrated = [double]$luMatches[$luMatches.Count - 1].Groups[1].Value }
    $peakMatches = [regex]::Matches($loudRaw, 'Peak:\s+(-?\d+(?:\.\d+)?)\s+dBFS')
    if ($peakMatches.Count -gt 0) { $peak = [double]$peakMatches[$peakMatches.Count - 1].Groups[1].Value }

    if ($null -eq $integrated) {
        Add-Check -Name 'loudness' -Status 'warn' -Detail 'Could not measure integrated loudness.'
    } else {
        $ok = ($integrated -ge -18) -and ($integrated -le -14)
        Add-Check -Name 'loudness' -Status $(if ($ok) { 'pass' } else { 'warn' }) `
            -Detail ("integrated $integrated LUFS (target -16 ±2), true peak $(if ($null -ne $peak) { "$peak dBTP" } else { 'n/a' })")
    }
}

# --- contact sheet ---------------------------------------------------------
if ($ContactSheet) {
    if (-not $probe -or -not $probe.format.duration) {
        Add-Check -Name 'contact sheet' -Status 'skip' -Detail 'No duration for frame sampling.'
    } else {
        $d = [double]$probe.format.duration
        $fps = [math]::Max(0.05, $SheetFrames / [math]::Max(1.0, $d))
        $cols = [math]::Min(4, $SheetFrames)
        $rows = [int][math]::Ceiling($SheetFrames / $cols)
        $sheetDir = Split-Path -Parent $ContactSheet
        if ($sheetDir -and -not (Test-Path $sheetDir)) { New-Item -ItemType Directory -Force -Path $sheetDir | Out-Null }
        $vf = ('fps=' + [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.######}', $fps) + ',scale=480:-1,tile=4x' + $rows)
        & $ffmpeg -hide_banner -loglevel error -y -i $full -vf $vf -frames:v 1 $ContactSheet 2>&1 | Out-Null
        if (Test-Path $ContactSheet) {
            Add-Check -Name 'contact sheet' -Status 'pass' -Detail ((Resolve-Path $ContactSheet).Path)
        } else {
            Add-Check -Name 'contact sheet' -Status 'warn' -Detail 'ffmpeg did not produce the sheet (tile filter unsupported?).'
        }
    }
}

# --- report ----------------------------------------------------------------
$icon = @{ pass = '[ok]'; fail = '[X] '; warn = '[!] '; skip = '[-] ' }
$color = @{ pass = 'Green'; fail = 'Red'; warn = 'Yellow'; skip = 'DarkGray' }
Write-Host ''
Write-Host ('  Verify: ' + $full) -ForegroundColor Cyan
foreach ($r in $results) {
    Write-Host ('{0} {1,-14} {2}' -f $icon[$r.Status], $r.Check, $r.Detail) -ForegroundColor $color[$r.Status]
}

if ($failed -gt 0) {
    Write-Host ''
    Write-Host ('  RESULT: FAIL (' + $failed + ' check(s) failed)') -ForegroundColor Red
    exit 1
}
Write-Host ''
Write-Host '  RESULT: PASS' -ForegroundColor Green
exit 0

