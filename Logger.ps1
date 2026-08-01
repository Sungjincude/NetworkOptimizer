<#
.SYNOPSIS
    Provides logging functionality.
.DESCRIPTION
    Creates timestamped log files and writes structured log entries.
#>

$script:logFilePath = $null

function Initialize-Logger {
    param(
        [string]$LogPath = "$env:ProgramData\NetworkOptimizer\Logs"
    )

    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = Join-Path $LogPath "NetworkOptimizer_$timestamp.log"
    $script:logFilePath = $logFile

    if (-not (Test-Path $logFile)) {
        $header = "=== Network Optimizer Log ===`r`nStarted at $(Get-Date)`r`n"
        $header | Out-File -FilePath $logFile -Encoding utf8
    }

    Write-Host "Log file: $logFile" -ForegroundColor Gray
    return $logFile
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )

    if (-not $script:logFilePath) {
        Initialize-Logger -LogPath "$env:TEMP\NetworkOptimizer\Logs"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = "[$timestamp] [$Level] $Message"

    # Console output with color
    switch ($Level) {
        'Info'    { Write-Host $entry -ForegroundColor White }
        'Warning' { Write-Host $entry -ForegroundColor Yellow }
        'Error'   { Write-Host $entry -ForegroundColor Red }
    }

    # Retry writing to log file if locked
    $maxRetries = 5
    $retryDelay = 100  # milliseconds
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Add-Content -Path $script:logFilePath -Value $entry -ErrorAction Stop
            return
        } catch {
            if ($i -eq $maxRetries - 1) {
                Write-Warning "Failed to write to log file after $maxRetries attempts: $_"
            } else {
                Start-Sleep -Milliseconds $retryDelay
            }
        }
    }
}
