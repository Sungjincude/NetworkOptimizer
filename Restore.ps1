<#
.SYNOPSIS
    Restores settings from a backup file.
.DESCRIPTION
    Reads a JSON backup and applies the RegistryKeyword/RegistryValue pairs.
#>

function Restore-AdapterSettings {
    <#
    .SYNOPSIS
        Restores the adapter settings from the latest backup.
    .PARAMETER AdapterName
        The name of the adapter.
    .PARAMETER BackupFile
        Optional path to a specific backup file. If not provided, uses the latest.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AdapterName,
        [string]$BackupFile = $null
    )

    if (-not $BackupFile) {
        $BackupFile = Get-LatestBackup -AdapterName $AdapterName
        if (-not $BackupFile) {
            Write-Error "No backup found for adapter '$AdapterName'."
            return
        }
    }

    if (-not (Test-Path $BackupFile)) {
        Write-Error "Backup file not found: $BackupFile"
        return
    }

    try {
        $json = Get-Content -Path $BackupFile -Raw | ConvertFrom-Json
    } catch {
        Write-Log "Failed to parse backup file: $_" -Level Error
        return
    }

    Write-Log "Restoring settings for adapter '$AdapterName' from $BackupFile" -Level Info

    $restoredCount = 0
    foreach ($item in $json) {
        $keyword = $item.RegistryKeyword
        $value = $item.RegistryValue
        try {
            Set-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $keyword -RegistryValue $value -ErrorAction Stop
            Write-Log "Restored $keyword = $value" -Level Info
            $restoredCount++
        } catch {
            Write-Log "Failed to restore $keyword : $_" -Level Error
        }
    }

    Write-Log "Restored $restoredCount settings." -Level Info
    Write-Host "Restored $restoredCount settings." -ForegroundColor Green
}
