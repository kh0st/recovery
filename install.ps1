<#
.SYNOPSIS
    Fully automated Windows setup script:
    1. Fetches the latest Chris Titus Tech WinUtil release.
    2. Downloads `WinUtilPreset.json` if missing and applies it.
    3. Downloads `WinRecovery.json` and ensures it is stored properly.
    4. Installs Git (if missing) and clones `kh0st/wallpapers.git` to `Pictures\wallpapers`.
    5. Runs all Windows optimizations automatically.

.DESCRIPTION
    - This script should be run as Administrator from a fresh install.
    - Automatically fetches and applies recovery + optimization settings.

.EXAMPLE
    iwr -useb "https://raw.githubusercontent.com/kh0st/scripts/main/windev.ps1" | iex
#>

# --- 1. Function: Get Latest WinUtil Release ---
function Get-LatestRelease {
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/ChrisTitusTech/winutil/releases"
        # Attempt to get the latest pre-release
        $latestPre = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        if ($latestPre) {
            return $latestPre.tag_name
        } else {
            # Fallback to the first stable release
            return $releases[0].tag_name
        }
    }
    catch {
        Write-Host "Error fetching WinUtil release: $_" -ForegroundColor Red
        return "latest/download"
    }
}

# --- 2. Function: Download a File if It’s Missing ---
function Ensure-FileExists {
    param (
        [string]$Url,
        [string]$Destination
    )

    if (-not (Test-Path $Destination)) {
        Write-Host "Downloading $Destination..."
        Invoke-WebRequest -Uri $Url -OutFile $Destination
    } else {
        Write-Host "$Destination already exists. Skipping download."
    }
}

# --- 3. Download `WinUtilPreset.json` & `WinRecovery.json` (if missing) ---

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$presetPath = Join-Path $scriptDir "WinUtilPreset.json"

# URLs (replace with correct ones if necessary)
$presetURL = "https://raw.githubusercontent.com/kh0st/winrecovery/main/WinUtilPreset.json"

Ensure-FileExists -Url $presetURL -Destination $presetPath

# --- 4. Download & Run WinUtil Script ---
function Run-WinUtilWithPreset {
    $release = Get-LatestRelease
    $url = "https://github.com/ChrisTitusTech/winutil/releases/download/$release/winutil.ps1"

    Write-Host "Downloading and running WinUtil..."
    try {
        $script = Invoke-RestMethod -Uri $url
    }
    catch {
        Write-Host "Error downloading winutil.ps1: $_" -ForegroundColor Red
        return
    }

    if (Test-Path $presetPath) {
        Write-Host "Passing WinUtilPreset.json to WinUtil..."
        $script += " -CustomPreset `"$presetPath`""
    }

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Re-launching script with Admin privileges..."
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command $($script)" -Verb RunAs
    }
    else {
        Invoke-Expression $script
    }
}

# --- 5. Ensure Git is Installed & Clone Wallpapers Repo ---
function Install-GitIfNeeded {
    Write-Host "Checking if 'git' is installed..."
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "'git' not found. Installing via Winget..."
        winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
    }
}

function Clone-WallpapersRepo {
    $picturesPath = Join-Path $env:USERPROFILE "Pictures"
    $wallpapersPath = Join-Path $picturesPath "wallpapers"

    if (-not (Test-Path $picturesPath)) {
        Write-Host "Creating Pictures folder..."
        New-Item -Path $picturesPath -ItemType Directory | Out-Null
    }

    if (Test-Path $wallpapersPath) {
        Write-Host "Wallpapers repo already exists. Skipping clone."
        return
    }

    Write-Host "Cloning kh0st/wallpapers.git into Pictures\wallpapers..."
    git clone "https://github.com/kh0st/wallpapers.git" "$wallpapersPath"
}

# --- 6. Execute Everything ---
Run-WinUtilWithPreset
Install-GitIfNeeded
Clone-WallpapersRepo

Write-Host "`nSetup complete! WinUtil ran, Git installed, Wallpapers cloned." -ForegroundColor Green
