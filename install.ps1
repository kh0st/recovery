<#
.SYNOPSIS
    Modified ChrisTitusTech windev-style script to:
    1. Download + run the latest WinUtil (pre-release preferred).
    2. Append '-CustomPreset WinUtilPreset.json' if found.
    3. Install Git via Winget if needed.
    4. Clone kh0st/wallpapers.git into User's Pictures folder.
.DESCRIPTION
    This script is designed for a one-click Windows setup automation:
      - If WinUtilPreset.json is in the same folder, pass it to WinUtil.
      - If Git isn't installed, install it silently with Winget.
      - Clone the wallpapers repo to %USERPROFILE%\Pictures\wallpapers.
.EXAMPLE
    1) Right-click > "Run with PowerShell" (as Admin)
    2) Or from elevated PowerShell: ./windev.ps1
#>

# --- 1. Fetch the latest release info from GitHub ---

function Get-LatestRelease {
    try {
        # Get all releases from the GitHub API
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/ChrisTitusTech/winutil/releases"
        
        # Attempt to get the latest pre-release if available
        $latestPre = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        if ($latestPre) { return $latestPre.tag_name }

        # If no pre-release found, fallback to the first stable release
        $latestStable = $releases | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
        return $latestStable.tag_name
    }
    catch {
        Write-Host "Error fetching release data: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# --- 2. Download + run WinUtil script, optionally appending custom preset ---

function Run-WinUtilWithPreset {
    $release = Get-LatestRelease
    if (-not $release) {
        Write-Host "Couldn't determine latest release. Using fallback (latest stable)." -ForegroundColor Yellow
        $release = "latest/download"
        $url = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"
    } else {
        Write-Host "Found WinUtil release tag: $release"
        $url = "https://github.com/ChrisTitusTech/winutil/releases/download/$release/winutil.ps1"
    }

    try {
        # Download the WinUtil script content into a variable
        $script = Invoke-RestMethod -Uri $url
    }
    catch {
        Write-Host "Error downloading winutil.ps1 from $url : $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # Check if the local JSON config file exists in the same dir as this script
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $presetPath = Join-Path $scriptDir "WinUtilPreset.json"

    if (Test-Path $presetPath) {
        Write-Host "Found WinUtilPreset.json. Using -CustomPreset $presetPath..."
        # Append the argument for the config file
        $script += " -CustomPreset `"$presetPath`""
        # ^ Adjust parameter name if your WinUtil version differs
    } else {
        Write-Host "No WinUtilPreset.json found. Running WinUtil without a custom preset." -ForegroundColor Yellow
    }

    # Check if we are running as Admin
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {

        Write-Host "Re-launching script in an elevated PowerShell..."
        $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { $powershellCmd }

        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command $($script)" -Verb RunAs
    }
    else {
        Write-Host "Running WinUtil in the current (already elevated) session..."
        Invoke-Expression $script
    }
}

# --- 3. Ensure Git is installed, then clone the wallpapers repo ---

function Install-GitIfNeeded {
    Write-Host "Checking if 'git' is available..."
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "'git' not found. Installing via Winget..."
        # If needed, ensure winget is available (Windows 10+ with App Installer).
        winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements -h
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "Failed to install Git via Winget." -ForegroundColor Red
            return
        }
    }
    else {
        Write-Host "Git is already installed."
    }
}

function Clone-WallpapersRepo {
    # We'll clone to %USERPROFILE%\Pictures\wallpapers
    $picturesPath = Join-Path $env:USERPROFILE "Pictures"
    $wallpapersPath = Join-Path $picturesPath "wallpapers"

    # Create the pictures folder if it doesn't exist
    if (-not (Test-Path $picturesPath)) {
        Write-Host "Creating user Pictures folder at $picturesPath..."
        New-Item -Path $picturesPath -ItemType Directory | Out-Null
    }

    # If the 'wallpapers' folder already exists, we can skip or remove it
    if (Test-Path $wallpapersPath) {
        Write-Host "wallpapers folder already exists at $wallpapersPath; skipping clone." -ForegroundColor Yellow
        return
    }

    Write-Host "Cloning kh0st/wallpapers.git into $wallpapersPath..."
    git clone "https://github.com/kh0st/wallpapers.git" "$wallpapersPath"
}

# --- 4. Main Execution ---

# Step A: Run WinUtil with optional JSON preset
Run-WinUtilWithPreset

# Step B: Install Git if needed and clone your wallpapers repo
Install-GitIfNeeded
Clone-WallpapersRepo

Write-Host "`nDone! WinUtil script executed and wallpapers cloned (if possible)." -ForegroundColor Green
