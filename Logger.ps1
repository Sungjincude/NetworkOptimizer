<#
.SYNOPSIS
    Provides logging functionality.
.DESCRIPTION
    Creates timestamped log files and writes structured log entries.
#>

$script:logFilePath = $null

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initializes the logging system.
    .PARAMETER LogPath
        The directory where log files will be stored.
    #>
    param(
        [string]$LogPath = "$env:ProgramData\NetworkOptimizer\Logs"
    )

    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = Join-Path $LogPath "NetworkOptimizer_$timestamp.log"
    $script:logFilePath = $logFile

    # Write header
    $header = "=== Network Optimizer Log ===`r`nStarted at $(Get-Date)`r`n"
    $header | Out-File -FilePath $logFile -Encoding utf8

    Write-Output "Log file: $logFile"
    return $logFile
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry.
    .PARAMETER Message
        The log message.
    .PARAMETER Level
        Log level: Info, Warning, Error.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('Info','Warning','Error')]
        [string]$Level = 'Info'
    )

    if (-not $script:logFilePath) {
        # Fallback: create log in temp
        $script:logFilePath = Initialize-Logger -LogPath "$env:TEMP\NetworkOptimizer\Logs"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = "[$timestamp] [$Level] $Message"
    # Write to console with color
    switch ($Level) {
        'Info'    { Write-Host $entry -ForegroundColor White }
        'Warning' { Write-Host $entry -ForegroundColor Yellow }
        'Error'   { Write-Host $entry -ForegroundColor Red }
    }
    # Append to log file
    Add-Content -Path $script:logFilePath -Value $entry
}
