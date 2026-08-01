<#
.SYNOPSIS
    Network adapter detection and filtering.
.DESCRIPTION
    Functions to enumerate physical, active, and virtual adapters.
#>

function Get-PhysicalNetworkAdapters {
    <#
    .SYNOPSIS
        Returns physical network adapters, optionally filtering to active only.
    .PARAMETER IncludeActiveOnly
        If $true, only returns adapters with status 'Up' and not virtual/hidden.
    .PARAMETER IncludeHidden
        If $true, includes hidden adapters (typically virtual or software).
    #>
    param(
        [switch]$IncludeActiveOnly,
        [switch]$IncludeHidden
    )

    # Get all adapters
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue

    # Filter out virtual adapters by default: exclude adapters with "Virtual" in name or description
    # Also exclude loopback, tunnel, etc.
    $physical = $adapters | Where-Object {
        $_.InterfaceDescription -notmatch "Virtual|Loopback|Tunnel|Hyper-V|VMware|VirtualBox|VPN|WFP|Microsoft Wi-Fi Direct|Bluetooth" -and
        $_.Name -notmatch "Loopback|Tunnel|Virtual|VPN"
    }

    # Optionally include hidden (disabled) adapters? We'll consider hidden as those with NetEnabled = $false? Actually hidden adapters are not shown by Get-NetAdapter by default unless -IncludeHidden is used.
    # To include hidden, we must use Get-NetAdapter -IncludeHidden. We'll do that if $IncludeHidden.
    if ($IncludeHidden) {
        $hidden = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object {
            $_.InterfaceDescription -notmatch "Virtual|Loopback|Tunnel|Hyper-V|VMware|VirtualBox|VPN|WFP|Microsoft Wi-Fi Direct|Bluetooth" -and
            $_.Name -notmatch "Loopback|Tunnel|Virtual|VPN"
        }
        $physical = $physical + $hidden
    }

    if ($IncludeActiveOnly) {
        $physical = $physical | Where-Object { $_.Status -eq 'Up' }
    }

    return $physical
}

function Get-AdapterVendor {
    <#
    .SYNOPSIS
        Attempts to determine the vendor of a network adapter.
    .PARAMETER Adapter
        A NetAdapter object.
    #>
    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimInstance]$Adapter
    )

    $description = $Adapter.InterfaceDescription
    $vendorMap = Get-VendorMapping
    foreach ($vendor in $vendorMap.Keys) {
        foreach ($id in $vendorMap[$vendor]) {
            if ($description -match $id) {
                return $vendor
            }
        }
    }
    # Try to get from PnPDeviceID
    $pnpId = $Adapter.PnPDeviceID
    if ($pnpId) {
        # Extract vendor ID: PCI\VEN_XXXX&...
        if ($pnpId -match 'VEN_([0-9A-Fa-f]{4})') {
            $venId = $Matches[1].ToUpper()
            foreach ($vendor in $vendorMap.Keys) {
                if ($vendorMap[$vendor] -contains $venId) {
                    return $vendor
                }
            }
        }
    }
    return "Unknown"
}

function Get-AdapterInfo {
    <#
    .SYNOPSIS
        Gathers comprehensive information about a network adapter.
    #>
    param(
        [Parameter(Mandatory)]
        [Microsoft.Management.Infrastructure.CimInstance]$Adapter
    )

    $info = [PSCustomObject]@{
        Name                 = $Adapter.Name
        InterfaceDescription = $Adapter.InterfaceDescription
        Vendor               = Get-AdapterVendor -Adapter $Adapter
        DriverVersion        = $Adapter.DriverVersion
        DriverDate           = $Adapter.DriverDate
        LinkSpeed            = $Adapter.LinkSpeed
        Status               = $Adapter.Status
        NetEnabled           = $Adapter.NetEnabled
        MediaType            = $Adapter.MediaType
        PhysicalMediaType    = $Adapter.PhysicalMediaType
        InterfaceType        = $Adapter.InterfaceType
    }

    # Determine connection type
    if ($Adapter.MediaType -match "Ethernet|802\.3") {
        $info | Add-Member -MemberType NoteProperty -Name "ConnectionType" -Value "Ethernet"
    } elseif ($Adapter.MediaType -match "Wireless|802\.11") {
        $info | Add-Member -MemberType NoteProperty -Name "ConnectionType" -Value "Wi-Fi"
    } elseif ($Adapter.MediaType -match "USB") {
        $info | Add-Member -MemberType NoteProperty -Name "ConnectionType" -Value "USB Ethernet"
    } else {
        $info | Add-Member -MemberType NoteProperty -Name "ConnectionType" -Value "Unknown"
    }

    return $info
}
