<#
.SYNOPSIS
    Backup and restore functions for network adapter advanced properties.
.DESCRIPTION
    Exports properties to JSON and restores them.
#>

function Backup-AdapterSettings {
    <#
    .SYNOPSIS
        Backs up the current advanced properties of a network adapter to a JSON file.
    .PARAMETER AdapterName
        The name of the adapter.
    .PARAMETER Properties
        The advanced properties (from Get-NetAdapterAdvancedProperty).
    .OUTPUTS
        The path to the backup file, or $null on failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AdapterName,
        [Parameter(Mandatory)]
        [array]$Properties
    )

    $backupDir = "$env:ProgramData\NetworkOptimizer\Backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupFile = Join-Path $backupDir "Backup_${AdapterName}_$timestamp.json"

    try {
        # Select only the properties we need to restore
        $data = $Properties | Select-Object RegistryKeyword, RegistryValue, DisplayName, DisplayValue
        $json = $data | ConvertTo-Json -Depth 2
        $json | Out-File -FilePath $backupFile -Encoding utf8
        Write-Log "Backup saved to $backupFile" -Level Info
        return $backupFile
    } catch {
        Write-Log "Failed to backup settings: $_" -Level Error
        return $null
    }
}

function Get-LatestBackup {
    <#
    .SYNOPSIS
        Gets the most recent backup file for a given adapter.
    #>
    param(
        [string]$AdapterName
    )
    $backupDir = "$env:ProgramData\NetworkOptimizer\Backups"
    if (-not (Test-Path $backupDir)) {
        return $null
    }
    $files = Get-ChildItem -Path $backupDir -Filter "Backup_${AdapterName}_*.json" | Sort-Object LastWriteTime -Descending
    if ($files) {
        return $files[0].FullName
    }
    return $null
}
