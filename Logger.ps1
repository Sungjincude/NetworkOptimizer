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
        Initializes the logging system and returns the log file path.
    .PARAMETER LogPath
        The directory where log files will be stored.
    .OUTPUTS
        The full path to the new log file.
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

    # Write the header (only on first initialization)
    if (-not (Test-Path $logFile)) {
        $header = "=== Network Optimizer Log ===`r`nStarted at $(Get-Date)`r`n"
        $header | Out-File -FilePath $logFile -Encoding utf8
    }

    # Use Write-Host for user feedback (does not pollute output stream)
    Write-Host "Log file: $logFile" -ForegroundColor Gray
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
        # Call Initialize-Logger without capturing its output
        Initialize-Logger -LogPath "$env:TEMP\NetworkOptimizer\Logs"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = "[$timestamp] [$Level] $Message"

    # Console output
    switch ($Level) {
        'Info'    { Write-Host $entry -ForegroundColor White }
        'Warning' { Write-Host $entry -ForegroundColor Yellow }
        'Error'   { Write-Host $entry -ForegroundColor Red }
    }

    # Append to log file
    try {
        Add-Content -Path $script:logFilePath -Value $entry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file: $_"
        # Fallback: write to console only
    }
}
