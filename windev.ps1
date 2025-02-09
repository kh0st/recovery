<#
.SYNOPSIS
    This Script fetches the latest WinUtil (ChrisTitusTech) release
    and invokes it, appending a custom JSON config file (WinUtilPreset.json).
.DESCRIPTION
    This is a modified version of ChrisTitusTech's "windev.ps1" bootstrap script.
    It checks for a local 'WinUtilPreset.json' and, if found, passes it to the main script.
    NOTE: Adjust the parameter name (-CustomPreset) to match your WinUtil version's requirement.
.EXAMPLE
    irm https://Your-Repo-URL/windev.ps1 | iex
    OR
    Run in Admin Powershell >  ./windev.ps1
#>

# -- 1. Function: Get-LatestRelease
function Get-LatestRelease {
    try {
        $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/ChrisTitusTech/winutil/releases'
        # We prefer the latest Pre-Release if present
        $latestRelease = $releases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        return $latestRelease.tag_name
    }
    catch {
        Write-Host "Error fetching release data: $_" -ForegroundColor Red
        return $null
    }
}

# -- 2. Function: RedirectToLatestPreRelease
function RedirectToLatestPreRelease {
    $latestRelease = Get-LatestRelease

    if ($latestRelease) {
        $url = "https://github.com/ChrisTitusTech/winutil/releases/download/$latestRelease/winutil.ps1"
        Write-Host "Using latest pre-release: $latestRelease"
    }
    else {
        Write-Host 'No pre-release version found. Using latest Full Release...' -ForegroundColor Yellow
        $url = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"
    }

    # -- 2a. Download the actual WinUtil script into a variable --
    try {
        $script = Invoke-RestMethod $url
    }
    catch {
        Write-Host "Error downloading WinUtil script from $url : $_" -ForegroundColor Red
        return
    }

    # -- 2b. Check if we have a local WinUtilPreset.json to pass --
    #    We'll assume it's in the same directory as this script.
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $jsonPath  = Join-Path $scriptDir "WinUtilPreset.json"

    if (Test-Path $jsonPath) {
        Write-Host "Found WinUtilPreset.json. Passing -CustomPreset parameter..."
        # Here we append the parameter to the script text
        $script += " -CustomPreset `"$jsonPath`""
        # ^ If the parameter name is different in your WinUtil version, adjust it here!
    }
    else {
        Write-Host "No WinUtilPreset.json found. Proceeding without custom presets." -ForegroundColor Yellow
    }

    # -- 2c. Elevate if needed --
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {

        Write-Host "WinUtil needs to run as Administrator. Attempting to relaunch..."

        $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        $processCmd    = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { $powershellCmd }

        # Start an elevated process and pass the script as a command string
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command $($script)" -Verb RunAs
    }
    else {
        # Already elevated, just run the script
        Invoke-Expression $script
    }
}

# -- 3. Run the function --
RedirectToLatestPreRelease
