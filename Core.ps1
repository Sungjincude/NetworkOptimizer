<#
.SYNOPSIS
    Network Optimizer – Enterprise‑grade network adapter tuning for Windows 10/11.
.DESCRIPTION
    Provides presets (Gaming, Balanced, Throughput) with automatic property detection,
    backup/restore, logging, and validation. This is the main entry point.
.PARAMETER Silent
    Suppresses confirmation prompts. Useful for unattended execution.
.PARAMETER LogPath
    Override the default log directory. Defaults to "$scriptRoot\Logs".
.PARAMETER Preset
    If provided, automatically applies the specified preset and exits.
    Valid values: Gaming, Balanced, Throughput.
.PARAMETER AdapterName
    If used with -Preset, specifies which adapter to target (name or part of name).
.PARAMETER Transcript
    Enables PowerShell transcript logging to the log directory.
.EXAMPLE
    .\Core.ps1 -Silent -Preset Gaming -AdapterName Ethernet
.EXAMPLE
    .\Core.ps1 -Transcript -Verbose
    Runs the interactive menu with transcript and verbose logging.
.NOTES
    Requires PowerShell 5.1 or later and Administrator privileges.
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$LogPath,
    [string]$Preset,
    [string]$AdapterName,
    [switch]$Transcript
)

#Requires -Version 5.1
#Requires -RunAsAdministrator

#region Imports
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptRoot\Logger.ps1"
. "$scriptRoot\Detection.ps1"
. "$scriptRoot\VendorMappings.ps1"
. "$scriptRoot\Presets.ps1"
. "$scriptRoot\Backup.ps1"
. "$scriptRoot\Restore.ps1"
. "$scriptRoot\Validation.ps1"
#endregion

#region Global Variables
$script:selectedAdapter = $null
$script:originalProperties = $null
$script:lastAppliedPreset = $null
$script:exitCode = 0
$script:logFilePath = $null

# Cached system info
$script:windowsVersion = $null
$script:psVersion = $null

# Cached adapter info
$script:cachedAdapterInfo = $null
$script:cachedVendor = $null
$script:cachedDriverVersion = $null
$script:cachedDriverDate = $null
$script:cachedLinkSpeed = $null
$script:cachedInterfaceDescription = $null

# Cached property lookup table
$script:propertyLookup = $null
#endregion

#region Logging & Initialization
function Initialize-LoggerEx {
    <#
    .SYNOPSIS
        Initializes logging – sets $script:logFilePath directly.
        Does NOT call the external Initialize-Logger to avoid duplication.
    #>
    param()

    $basePath = if ($LogPath) {
        $LogPath
    } else {
        Join-Path $scriptRoot "Logs"
    }

    # Create directory if missing
    if (-not (Test-Path $basePath)) {
        try {
            New-Item -ItemType Directory -Path $basePath -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Failed to create log directory '$basePath': $_"
            $basePath = Join-Path $env:TEMP "NetworkOptimizer\Logs"
            if (-not (Test-Path $basePath)) {
                New-Item -ItemType Directory -Path $basePath -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    # Test write permissions
    $testFile = Join-Path $basePath "write_test.tmp"
    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -Force
    } catch {
        Write-Warning "Log directory '$basePath' is not writable. Falling back to temp."
        $basePath = Join-Path $env:TEMP "NetworkOptimizer\Logs"
        if (-not (Test-Path $basePath)) {
            New-Item -ItemType Directory -Path $basePath -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile = Join-Path $basePath "NetworkOptimizer_$timestamp.log"
    $script:logFilePath = $logFile
    $header = "=== Network Optimizer Log ===`r`nStarted at $(Get-Date)`r`n"
    $header | Out-File -FilePath $logFile -Encoding utf8 -ErrorAction SilentlyContinue
    Write-Host "Log file: $logFile" -ForegroundColor Gray

    # Start transcript if requested
    if ($Transcript) {
        $transcriptFile = Join-Path $basePath "transcript_$timestamp.txt"
        try {
            Start-Transcript -Path $transcriptFile -ErrorAction Stop | Out-Null
            Write-Log "Transcript started: $transcriptFile" -Level Info
        } catch {
            Write-Warning "Failed to start transcript: $_"
        }
    }

    return $logFile
}

function Initialize-SystemInfo {
    $script:psVersion = $PSVersionTable.PSVersion.ToString()
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $script:windowsVersion = $os.Caption
    } catch {
        $script:windowsVersion = [Environment]::OSVersion.Version.ToString()
    }
    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Windows Version: $script:windowsVersion"
        Write-Verbose "PowerShell Version: $script:psVersion"
    }
}

function Update-CachedAdapterInfo {
    if (-not $script:selectedAdapter) {
        $script:cachedAdapterInfo = $null
        $script:cachedVendor = $null
        $script:cachedDriverVersion = $null
        $script:cachedDriverDate = $null
        $script:cachedLinkSpeed = $null
        $script:cachedInterfaceDescription = $null
        return
    }
    $info = Get-AdapterInfo -Adapter $script:selectedAdapter
    $script:cachedAdapterInfo = $info
    $script:cachedVendor = $info.Vendor
    $script:cachedDriverVersion = $info.DriverVersion
    $script:cachedDriverDate = $info.DriverDate
    $script:cachedLinkSpeed = $info.LinkSpeed
    $script:cachedInterfaceDescription = $info.InterfaceDescription
    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Cached adapter info: Vendor=$script:cachedVendor, Driver=$script:cachedDriverVersion"
    }
}

function Build-PropertyLookupTable {
    param(
        [array]$Properties
    )
    $lookup = @{}
    foreach ($prop in $Properties) {
        $keyword = $prop.RegistryKeyword
        if ($keyword) { $lookup[$keyword] = $prop }
        $display = $prop.DisplayName
        if ($display) { $lookup[$display] = $prop }
        $aliases = Get-PropertyAliases
        foreach ($key in $aliases.Keys) {
            foreach ($alias in $aliases[$key]) {
                if ($alias -eq $keyword) {
                    $lookup[$key] = $prop
                    if (-not $lookup.ContainsKey($alias)) {
                        $lookup[$alias] = $prop
                    }
                }
            }
        }
    }
    return $lookup
}
#endregion

#region Helper Functions
function Normalize-Value {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [array]) {
        $str = ($Value | ForEach-Object { $_.ToString().Trim() }) -join ','
        return $str
    }
    if ($Value -is [bool]) {
        return $Value.ToString().ToLower()
    }
    if ($Value -is [enum]) {
        try { return [int]$Value } catch { return $Value.ToString() }
    }
    $str = $Value.ToString().Trim()
    if ($str -eq '') { return $null }
    if ($str -match '^\d+$') { return [int]$str }
    $lower = $str.ToLower()
    if ($lower -in @('true','false','0','1')) {
        # PowerShell 5.1 compatible: if/else instead of ternary
        if ($lower -eq 'true' -or $lower -eq '1') {
            return 'true'
        } else {
            return 'false'
        }
    }
    return $str
}

function Confirm-PresetApplication {
    param(
        [string]$AdapterName,
        [string]$PresetName,
        [int]$Count
    )
    if ($Silent) { return $true }
    Write-Host ""
    Write-Host "About to apply '$PresetName' preset to adapter '$AdapterName'." -ForegroundColor Cyan
    Write-Host "Number of properties to attempt: $Count" -ForegroundColor Cyan
    Write-Host "Continue? (Y/N): " -NoNewline
    $response = Read-Host
    return ($response -eq 'Y' -or $response -eq 'y')
}

function Wait-AdapterUp {
    param(
        [string]$AdapterName,
        [int]$TimeoutSeconds = 60
    )
    Write-Log "Waiting for adapter '$AdapterName' to become 'Up'..." -Level Info
    Write-Host "Waiting for adapter..." -NoNewline
    $start = Get-Date
    $lastDot = $start
    do {
        $adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        if ($adapter -and $adapter.Status -eq 'Up' -and $adapter.OperationalStatus -eq 'Up' -and $adapter.NetEnabled -eq $true) {
            Write-Host " Done." -ForegroundColor Green
            Write-Log "Adapter is up after $([math]::Round(((Get-Date)-$start).TotalSeconds,1)) seconds." -Level Info
            if ($VerbosePreference -eq 'Continue') { Write-Verbose "Adapter $AdapterName is up and operational." }
            return $true
        }
        # Show progress dot every 2 seconds
        if ((Get-Date) - $lastDot -gt [TimeSpan]::FromSeconds(2)) {
            Write-Host "." -NoNewline
            $lastDot = Get-Date
        }
        Start-Sleep -Milliseconds 500
    } while (((Get-Date)-$start).TotalSeconds -lt $TimeoutSeconds)
    Write-Host " Timeout." -ForegroundColor Red
    Write-Log "Timeout waiting for adapter to become 'Up'." -Level Error
    if ($VerbosePreference -eq 'Continue') { Write-Verbose "Adapter $AdapterName did not become up within $TimeoutSeconds seconds." }
    return $false
}

function Log-Exception {
    param(
        [System.Exception]$Exception,
        [string]$Property = $null,
        [string]$RegistryKeyword = $null,
        [string]$AdapterName = $null,
        $RequestedValue = $null
    )
    $msg = "Exception while processing"
    if ($Property) { $msg += " property '$Property'" }
    if ($RegistryKeyword) { $msg += " (keyword '$RegistryKeyword')" }
    if ($AdapterName) { $msg += " on adapter '$AdapterName'" }
    if ($RequestedValue -ne $null) { $msg += " with value '$RequestedValue'" }
    $msg += ": Type=$($Exception.GetType().FullName), Message=$($Exception.Message)"
    if ($Exception.InnerException) { $msg += ", Inner=$($Exception.InnerException.Message)" }
    Write-Log $msg -Level Error
    if ($VerbosePreference -eq 'Continue') {
        Write-Verbose "Stack trace: $($Exception.StackTrace)"
    }
}
#endregion

#region Menu and UI
function Show-Menu {
    Clear-Host
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "        Network Optimizer v1.0" -ForegroundColor Yellow
    Write-Host "==========================================="
    if ($script:selectedAdapter) {
        Write-Host "Selected Adapter: $($script:selectedAdapter.Name) ($script:cachedInterfaceDescription)" -ForegroundColor Green
        Write-Host "  Vendor: $script:cachedVendor" -ForegroundColor Gray
        Write-Host "  Driver: $script:cachedDriverVersion ($script:cachedDriverDate)" -ForegroundColor Gray
        Write-Host "  Link Speed: $script:cachedLinkSpeed" -ForegroundColor Gray
        $presetDisplay = if ($script:lastAppliedPreset) { $script:lastAppliedPreset } else { 'None' }
        Write-Host "  Current Preset: $presetDisplay" -ForegroundColor Gray
    } else {
        Write-Host "No adapter selected." -ForegroundColor Red
    }
    Write-Host "Log Location: $script:logFilePath" -ForegroundColor Gray
    Write-Host "PowerShell: $script:psVersion | OS: $script:windowsVersion" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1. Gaming Preset"
    Write-Host "2. Balanced Preset"
    Write-Host "3. Throughput Preset"
    Write-Host "4. Backup Current Settings"
    Write-Host "5. Restore from Backup"
    Write-Host "6. Show Current Settings"
    Write-Host "7. Select Network Adapter"
    Write-Host "8. Exit"
    Write-Host ""
    Write-Host "Choose an option: " -NoNewline
}

function Select-Adapter {
    $adapters = Get-PhysicalNetworkAdapters -IncludeActiveOnly
    if (-not $adapters) {
        Write-Error "No active physical network adapters found."
        return $null
    }
    $adapterArray = @($adapters)
    if ($adapterArray.Count -eq 1) {
        $adapter = $adapterArray[0]
        Write-Host "Auto-selected the only active physical adapter: $($adapter.Name)" -ForegroundColor Green
        return $adapter
    }
    Write-Host "Multiple active physical adapters found. Please select one:" -ForegroundColor Cyan
    $i = 1
    $adapterList = @()
    foreach ($adapter in $adapterArray) {
        $status = if ($adapter.Status -eq 'Up') { 'Up' } else { 'Down' }
        Write-Host "$i. $($adapter.Name) - $($adapter.InterfaceDescription) [$status]"
        $adapterList += $adapter
        $i++
    }
    Write-Host "Enter number (1-$($adapterArray.Count)): " -NoNewline
    $choice = Read-Host
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $adapterArray.Count) {
        return $adapterList[[int]$choice - 1]
    }
    Write-Warning "Invalid selection."
    return $null
}
#endregion

#region Core Functions
function Apply-Preset {
    param(
        [Parameter(Mandatory)]
        [string]$PresetName,
        [Microsoft.Management.Infrastructure.CimInstance]$Adapter = $script:selectedAdapter
    )

    if (-not $Adapter) {
        Write-Error "No adapter selected. Please select one first."
        $script:exitCode = 3
        return
    }

    $adapterName = $Adapter.Name
    Write-Log "Applying preset '$PresetName' to adapter '$adapterName'" -Level Info
    if ($VerbosePreference -eq 'Continue') { Write-Verbose "Preset '$PresetName' selected for adapter '$adapterName'." }

    $properties = Get-NetAdapterAdvancedProperty -Name $adapterName -ErrorAction Stop
    if ($VerbosePreference -eq 'Continue') { Write-Verbose "Retrieved $($properties.Count) advanced properties." }

    $script:propertyLookup = Build-PropertyLookupTable -Properties $properties
    if ($VerbosePreference -eq 'Continue') { Write-Verbose "Property lookup table built with $($script:propertyLookup.Count) entries." }

    $backupFile = Backup-AdapterSettings -AdapterName $adapterName -Properties $properties
    if ($backupFile) {
        Write-Log "Backup saved to $backupFile" -Level Info
        if ($VerbosePreference -eq 'Continue') { Write-Verbose "Backup file: $backupFile" }
    }

    $preset = Get-Preset -Name $PresetName
    if (-not $preset) {
        Write-Error "Preset '$PresetName' not found."
        $script:exitCode = 1
        return
    }

    $supportedCount = 0
    $presetKeys = @($preset.Keys)
    foreach ($key in $presetKeys) {
        if (Resolve-Property -PropertyName $key -UseCache) { $supportedCount++ }
    }
    if ($VerbosePreference -eq 'Continue') { Write-Verbose "Supported properties count: $supportedCount out of $($presetKeys.Count) in preset." }

    if (-not (Confirm-PresetApplication -AdapterName $adapterName -PresetName $PresetName -Count $supportedCount)) {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        $script:exitCode = 2
        return
    }

    Write-Host "Applying preset... (progress will be logged)" -ForegroundColor Cyan

    $results = @()
    $restartRequired = $false
    $successCount = 0
    $totalSteps = $presetKeys.Count
    $currentStep = 0

    foreach ($key in $presetKeys) {
        $currentStep++
        $desiredValue = $preset[$key]
        Write-Progress -Activity "Applying Preset '$PresetName'" -Status "Processing $key" -PercentComplete (($currentStep / $totalSteps) * 100) -CurrentOperation "Property: $key"

        $prop = Resolve-Property -PropertyName $key -UseCache
        if (-not $prop) {
            Write-Log "Property '$key' not supported on this adapter. Skipping." -Level Warning
            if ($VerbosePreference -eq 'Continue') { Write-Verbose "Property '$key' not found in lookup table." }
            $results += [PSCustomObject]@{ Property = $key; OldValue = $null; NewValue = $null; Status = "SKIPPED"; Reason = "Not supported"; ElapsedMs = 0 }
            continue
        }

        $keyword = $prop.RegistryKeyword
        $oldValue = $prop.RegistryValue
        if ($VerbosePreference -eq 'Continue') { Write-Verbose "Resolved '$key' to keyword '$keyword', current value '$oldValue'." }

        $validValues = $prop.ValidRegistryValues
        if (-not $validValues) { $validValues = $prop.ValidDisplayValues }
        if ($validValues) {
            $normalizedDesired = Normalize-Value $desiredValue
            $found = $false
            foreach ($v in $validValues) {
                if ((Normalize-Value $v) -eq $normalizedDesired) { $found = $true; break }
            }
            if (-not $found) {
                Write-Log "Value '$desiredValue' is not in valid list for '$keyword'. Skipping." -Level Warning
                if ($VerbosePreference -eq 'Continue') { Write-Verbose "Value '$desiredValue' not in valid values: $($validValues -join ', ')" }
                $results += [PSCustomObject]@{ Property = $key; OldValue = $oldValue; NewValue = $desiredValue; Status = "SKIPPED"; Reason = "Invalid value (not in ValidRegistryValues)"; ElapsedMs = 0 }
                continue
            }
        } else {
            if ($VerbosePreference -eq 'Continue') { Write-Verbose "No validation info available for '$keyword'; attempting change." }
        }

        $start = Get-Date
        try {
            Set-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword $keyword -RegistryValue $desiredValue -ErrorAction Stop
            $success = $true
        } catch [System.UnauthorizedAccessException] {
            Log-Exception -Exception $_.Exception -Property $key -RegistryKeyword $keyword -AdapterName $adapterName -RequestedValue $desiredValue
            $success = $false
        } catch [System.InvalidOperationException] {
            Log-Exception -Exception $_.Exception -Property $key -RegistryKeyword $keyword -AdapterName $adapterName -RequestedValue $desiredValue
            $success = $false
        } catch [Microsoft.Management.Infrastructure.CimException] {
            Log-Exception -Exception $_.Exception -Property $key -RegistryKeyword $keyword -AdapterName $adapterName -RequestedValue $desiredValue
            $success = $false
        } catch {
            Log-Exception -Exception $_.Exception -Property $key -RegistryKeyword $keyword -AdapterName $adapterName -RequestedValue $desiredValue
            $success = $false
        }
        $elapsed = (Get-Date) - $start

        if ($success) {
            $newProp = Get-NetAdapterAdvancedProperty -Name $adapterName -RegistryKeyword $keyword -ErrorAction SilentlyContinue
            $oldNormalized = Normalize-Value $oldValue
            $desiredNormalized = Normalize-Value $desiredValue
            $actualNormalized = Normalize-Value $newProp.RegistryValue
            if ($newProp -and $actualNormalized -eq $desiredNormalized) {
                $status = "SUCCESS"
                $reason = ""
                $successCount++
                $restartRequired = $true
                if ($VerbosePreference -eq 'Continue') { Write-Verbose "Successfully set '$keyword' to '$desiredValue'." }
            } else {
                $status = "FAILED"
                $reason = "Value mismatch after set: expected '$desiredValue', got '$($newProp.RegistryValue)'"
                if ($VerbosePreference -eq 'Continue') { Write-Verbose "Validation failed: expected normalized '$desiredNormalized', got '$actualNormalized'." }
            }
        } else {
            $status = "FAILED"
            $reason = "Set operation threw exception"
        }

        $results += [PSCustomObject]@{
            Property = $key
            OldValue = $oldValue
            NewValue = $desiredValue
            Status = $status
            Reason = $reason
            ElapsedMs = [math]::Round($elapsed.TotalMilliseconds, 2)
        }
    }

    Write-Progress -Activity "Applying Preset" -Completed

    foreach ($res in $results) {
        Write-Log "Property: $($res.Property), Old: $($res.OldValue), New: $($res.NewValue), Status: $($res.Status), Reason: $($res.Reason), Elapsed: $($res.ElapsedMs)ms" -Level Info
    }

    Write-Host "`nPreset application summary:" -ForegroundColor Cyan
    $results | Format-Table -Property Property, OldValue, NewValue, Status, Reason, ElapsedMs -AutoSize

    if ($successCount -gt 0) {
        $script:lastAppliedPreset = $PresetName
    }

    # --- RESTART LOGIC ---
    if ($restartRequired) {
        Write-Log "Restarting adapter '$adapterName' to apply changes..." -Level Info
        Write-Host "Restarting adapter..." -ForegroundColor Yellow
        # Attempt restart regardless of current state – catch errors
        try {
            Restart-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
            if (Wait-AdapterUp -AdapterName $adapterName) {
                Write-Host "Adapter restarted successfully and is up." -ForegroundColor Green
            } else {
                Write-Warning "Adapter restart completed but did not return to 'Up' within 60 seconds. A system reboot may be required."
                $script:exitCode = 4
            }
        } catch {
            Log-Exception -Exception $_.Exception -AdapterName $adapterName
            Write-Host "Failed to restart adapter. Please restart manually." -ForegroundColor Red
            $script:exitCode = 1
        }
    } else {
        Write-Log "No successful property changes; adapter restart not required." -Level Info
        Write-Host "No changes applied; adapter restart skipped." -ForegroundColor Gray
    }

    if ($successCount -gt 0) {
        Write-Host "`nNote: Some network driver changes may require a system reboot to take full effect." -ForegroundColor Yellow
        Write-Log "Reboot may be required for some changes." -Level Warning
    }

    if ($successCount -gt 0 -and $script:exitCode -eq 0) {
        $script:exitCode = 0
    } elseif ($successCount -eq 0 -and $results.Count -gt 0) {
        $script:exitCode = 4
    }
}

function Resolve-Property {
    param(
        [array]$Properties,
        [Parameter(Mandatory)]
        [string]$PropertyName,
        [switch]$UseCache
    )

    if ($UseCache -and $script:propertyLookup) {
        if ($script:propertyLookup.ContainsKey($PropertyName)) {
            return $script:propertyLookup[$PropertyName]
        }
        $aliases = Get-PropertyAliases
        foreach ($key in $aliases.Keys) {
            if ($aliases[$key] -contains $PropertyName) {
                if ($script:propertyLookup.ContainsKey($key)) {
                    return $script:propertyLookup[$key]
                }
            }
        }
        return $null
    }

    if (-not $Properties) {
        Write-Error "Properties array required when not using cache."
        return $null
    }

    $match = $Properties | Where-Object { $_.RegistryKeyword -eq $PropertyName }
    if ($match) { return $match }

    $match = $Properties | Where-Object { $_.DisplayName -ieq $PropertyName }
    if ($match) { return $match }

    $aliases = Get-PropertyAliases
    $candidates = $aliases[$PropertyName]
    if ($candidates) {
        foreach ($alias in $candidates) {
            $match = $Properties | Where-Object { $_.RegistryKeyword -eq $alias }
            if ($match) { return $match }
            if ($alias -like "*") {
                $match = $Properties | Where-Object { $_.RegistryKeyword -like $alias }
                if ($match) { return $match }
            }
        }
    }
    return $null
}

function Show-CurrentSettings {
    if (-not $script:selectedAdapter) {
        Write-Error "No adapter selected."
        return
    }
    $props = Get-NetAdapterAdvancedProperty -Name $script:selectedAdapter.Name
    $props | Select-Object Name, DisplayName, RegistryKeyword, RegistryValue, DisplayValue | Format-Table -AutoSize
}
#endregion

#region Main Execution
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    $script:exitCode = 1
    exit $script:exitCode
}

Initialize-SystemInfo
$script:logFilePath = Initialize-LoggerEx
Write-Log "=== Network Optimizer started ===" -Level Info
if ($VerbosePreference -eq 'Continue') {
    Write-Verbose "Script started with parameters: Silent=$Silent, LogPath=$LogPath, Preset=$Preset, AdapterName=$AdapterName, Transcript=$Transcript"
}

$physical = Get-PhysicalNetworkAdapters -IncludeActiveOnly
if ($physical) {
    $physicalArray = @($physical)
    if ($physicalArray.Count -eq 1) {
        $script:selectedAdapter = $physicalArray[0]
        Write-Log "Auto-selected adapter: $($script:selectedAdapter.Name)" -Level Info
        Write-Host "Auto-selected the only active physical adapter: $($script:selectedAdapter.Name)" -ForegroundColor Green
        Update-CachedAdapterInfo
    } else {
        $adapter = Select-Adapter
        if ($adapter) {
            $script:selectedAdapter = $adapter
            Write-Log "Selected adapter: $($adapter.Name)" -Level Info
            Update-CachedAdapterInfo
        }
    }
} else {
    Write-Warning "No active physical adapters found."
    $script:exitCode = 3
}

if ($Preset -and $script:selectedAdapter) {
    if ($AdapterName) {
        $target = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
        if (-not $target) {
            $target = Get-NetAdapter | Where-Object { $_.Name -like "*$AdapterName*" -or $_.InterfaceDescription -like "*$AdapterName*" } | Select-Object -First 1
        }
        if ($target) {
            $script:selectedAdapter = $target
            Update-CachedAdapterInfo
        } else {
            Write-Error "Adapter '$AdapterName' not found."
            $script:exitCode = 1
            if ($Transcript) { Stop-Transcript -ErrorAction SilentlyContinue }
            exit $script:exitCode
        }
    }
    Apply-Preset -PresetName $Preset -Adapter $script:selectedAdapter
    if ($Transcript) { Stop-Transcript -ErrorAction SilentlyContinue }
    exit $script:exitCode
}

if (-not $script:selectedAdapter) {
    Write-Error "No adapter selected. Exiting."
    $script:exitCode = 3
    if ($Transcript) { Stop-Transcript -ErrorAction SilentlyContinue }
    exit $script:exitCode
}

do {
    Show-Menu
    $choice = Read-Host
    switch ($choice) {
        '1' { Apply-Preset -PresetName "Gaming" }
        '2' { Apply-Preset -PresetName "Balanced" }
        '3' { Apply-Preset -PresetName "Throughput" }
        '4' {
            if ($script:selectedAdapter) {
                $props = Get-NetAdapterAdvancedProperty -Name $script:selectedAdapter.Name
                Backup-AdapterSettings -AdapterName $script:selectedAdapter.Name -Properties $props
            } else {
                Write-Error "No adapter selected."
            }
        }
        '5' {
            if ($script:selectedAdapter) {
                Restore-AdapterSettings -AdapterName $script:selectedAdapter.Name
            } else {
                Write-Error "No adapter selected."
            }
        }
        '6' { Show-CurrentSettings }
        '7' {
            $adapter = Select-Adapter
            if ($adapter) {
                $script:selectedAdapter = $adapter
                Write-Log "Selected adapter: $($adapter.Name)" -Level Info
                Update-CachedAdapterInfo
                $script:lastAppliedPreset = $null
                $script:propertyLookup = $null
            }
        }
        '8' { Write-Host "Exiting."; break }
        default { Write-Host "Invalid option." }
    }
    if ($choice -ne '8') {
        Read-Host "`nPress Enter to continue"
    }
} while ($choice -ne '8')

if ($Transcript) {
    Stop-Transcript -ErrorAction SilentlyContinue
}
exit $script:exitCode
#endregion
