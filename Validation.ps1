<#
.SYNOPSIS
    Validation functions to verify that settings were applied correctly.
#>

function Test-PropertyApplied {
    <#
    .SYNOPSIS
        Checks if a property has the expected value.
    .PARAMETER AdapterName
        Name of the adapter.
    .PARAMETER RegistryKeyword
        The RegistryKeyword of the property.
    .PARAMETER ExpectedValue
        The expected value.
    .OUTPUTS
        True if the property matches, false otherwise.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AdapterName,
        [Parameter(Mandatory)]
        [string]$RegistryKeyword,
        [Parameter(Mandatory)]
        $ExpectedValue
    )
    try {
        $prop = Get-NetAdapterAdvancedProperty -Name $AdapterName -RegistryKeyword $RegistryKeyword -ErrorAction Stop
        if ($prop -and $prop.RegistryValue -eq $ExpectedValue) {
            return $true
        }
    } catch {
        Write-Log "Validation error for '$RegistryKeyword': $_" -Level Error
    }
    return $false
}
