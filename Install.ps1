<#
.SYNOPSIS
    Installer for the Network Optimizer utility.
.DESCRIPTION
    Downloads all required modules from a remote host and runs the main application.
    Designed to be invoked via: irm https://HOST/install.ps1 | iex
.PARAMETER BaseUrl
    The base URL where the scripts are hosted. Defaults to "https://HOST" (must be overridden).
.PARAMETER Destination
    The folder where the utility will be installed. Defaults to "$env:ProgramFiles\NetworkOptimizer".
.EXAMPLE
    irm https://my.server/install.ps1 | iex
.NOTES
    Requires PowerShell 5.1 or later.
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "https://raw.githubusercontent.com//Sungjincude/NetworkOptimizer/main/Install.ps1",
    [string]$Destination = "$env:ProgramFiles\NetworkOptimizer"
)

# Stop on errors, but we'll handle them gracefully
$ErrorActionPreference = "Stop"

# Files to download
$Files = @(
    "Core.ps1",
    "VendorMappings.ps1",
    "Presets.ps1",
    "Logger.ps1",
    "Backup.ps1",
    "Restore.ps1",
    "Detection.ps1",
    "Validation.ps1"
)

# Create destination if it doesn't exist
if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Download each file
foreach ($File in $Files) {
    $url = "$BaseUrl/$File"
    $destFile = Join-Path $Destination $File
    Write-Host "Downloading $url -> $destFile"
    try {
        Invoke-WebRequest -Uri $url -OutFile $destFile -ErrorAction Stop
    } catch {
        Write-Error "Failed to download $url : $_"
        exit 1
    }
}

# Change to the destination and run Core.ps1
Push-Location $Destination
try {
    & .\Core.ps1
} finally {
    Pop-Location
}
