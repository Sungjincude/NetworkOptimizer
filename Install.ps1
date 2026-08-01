<#
.SYNOPSIS
    Installer for Network Optimizer – downloads all modules from a remote host.
.DESCRIPTION
    Accepts a -BaseUrl parameter, or uses $env:NETOPT_BASEURL, or prompts interactively.
    Designed for use with GitHub raw content or any web server.
.PARAMETER BaseUrl
    The base URL where the script files are hosted (e.g., "https://raw.githubusercontent.com/user/repo/main").
.PARAMETER Destination
    Installation folder (default: "$env:ProgramFiles\NetworkOptimizer").
.PARAMETER Silent
    Suppresses prompts; uses defaults or fails if BaseUrl not found.
.EXAMPLE
    .\Install.ps1 -BaseUrl "https://my.server/NetworkOptimizer"
.EXAMPLE
    $env:NETOPT_BASEURL = "https://raw.githubusercontent.com/Sungjincude/NetworkOptimizer/main"
    .\Install.ps1
.NOTES
    Requires PowerShell 5.1 or later.
#>

[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$Destination = "$env:ProgramFiles\NetworkOptimizer",
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# Determine BaseUrl if not provided
if (-not $BaseUrl) {
    # Check environment variable
    $BaseUrl = $env:NETOPT_BASEURL
}

if (-not $BaseUrl -and -not $Silent) {
    Write-Host "Please enter the base URL where the NetworkOptimizer files are hosted:" -ForegroundColor Cyan
    Write-Host "Example: https://raw.githubusercontent.com/username/repo/main" -ForegroundColor Gray
    $BaseUrl = Read-Host "Base URL"
}

if (-not $BaseUrl) {
    Write-Error "BaseUrl not provided and could not be determined. Set -BaseUrl or define `$env:NETOPT_BASEURL."
    exit 1
}

# Ensure BaseUrl ends without trailing slash
$BaseUrl = $BaseUrl.TrimEnd('/')

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

# Create destination if not exists
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

# Run the main script
Push-Location $Destination
try {
    & .\Core.ps1
} finally {
    Pop-Location
}
