<#
.SYNOPSIS
    Vendor‑specific mappings and property alias resolution.
.DESCRIPTION
    Provides functions to resolve property names (display names, aliases)
    to RegistryKeywords, and to map vendor names.
#>

function Get-VendorMapping {
    <#
    .SYNOPSIS
        Returns a hashtable of vendor names to their common PCI vendor IDs.
    #>
    return @{
        "Intel"    = @("8086")
        "Realtek"  = @("10EC")
        "Killer"   = @("1A56")
        "Broadcom" = @("14E4")
        "Marvell"  = @("11AB")
        "Aquantia" = @("1D6A")
        "Qualcomm" = @("168C")
        "Microsoft"= @("1414")
        # Add more as needed
    }
}

function Get-PropertyAliases {
    <#
    .SYNOPSIS
        Returns a hashtable mapping common property names to possible RegistryKeywords.
        This helps resolve display names or aliases to the actual keyword.
    #>
    return @{
        "FlowControl" = @("*FlowControl")
        "RSS" = @("*RSS")
        "NumRssQueues" = @("*NumRssQueues")
        "RSSProfile" = @("*RSSProfile")
        "InterruptModeration" = @("*InterruptModeration")
        "ITR" = @("*ITR")
        "LsoV2IPv4" = @("*LsoV2IPv4")
        "LsoV2IPv6" = @("*LsoV2IPv6")
        "IPChecksumOffloadIPv4" = @("*IPChecksumOffloadIPv4")
        "TCPChecksumOffloadIPv4" = @("*TCPChecksumOffloadIPv4")
        "TCPChecksumOffloadIPv6" = @("*TCPChecksumOffloadIPv6")
        "UDPChecksumOffloadIPv4" = @("*UDPChecksumOffloadIPv4")
        "UDPChecksumOffloadIPv6" = @("*UDPChecksumOffloadIPv6")
        "JumboPacket" = @("*JumboPacket")
        "ReceiveBuffers" = @("*ReceiveBuffers")
        "TransmitBuffers" = @("*TransmitBuffers")
        "RscIPv4" = @("*RscIPv4")
        "RscIPv6" = @("*RscIPv6")
        "EEE" = @("*EEE", "EnableGreenEthernet", "AdvancedEEE", "EEELinkAdvertisement")
        "GreenEthernet" = @("EnableGreenEthernet", "GreenEthernet", "*EEE")
        "AdvancedEEE" = @("AdvancedEEE", "*EEE")
        "PacketCoalescing" = @("*PacketCoalescing")
        "DmaCoalescing" = @("*DmaCoalescing")
        "PriorityVLANTag" = @("*PriorityVLANTag")
        "VlanID" = @("*VlanID")
        "SpeedDuplex" = @("*SpeedDuplex")
        "WakeOnMagicPacket" = @("*WakeOnMagicPacket")
        "WakeOnPattern" = @("*WakeOnPattern")
        "ShutdownWakeOnLan" = @("ShutdownWakeOnLan")
        "WolShutdownLinkSpeed" = @("WolShutdownLinkSpeed")
        "AdaptiveIFS" = @("*AdaptiveIFS")
        "MasterSlave" = @("*MasterSlave")
        "NetworkAddress" = @("NetworkAddress")
        "AutoDisableGigabit" = @("AutoDisableGigabit")
        "GigabitLite" = @("GigabitLite")
    }
}

function Resolve-Property {
    <#
    .SYNOPSIS
        Given a collection of advanced properties and a property name (alias or keyword),
        returns the matching property object.
    .PARAMETER Properties
        The array of advanced properties from Get-NetAdapterAdvancedProperty.
    .PARAMETER PropertyName
        The name to resolve (e.g., "FlowControl", "*FlowControl", "EnableGreenEthernet").
    #>
    param(
        [Parameter(Mandatory)]
        [array]$Properties,
        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    # First, try exact match on RegistryKeyword (case-insensitive)
    $match = $Properties | Where-Object { $_.RegistryKeyword -eq $PropertyName }
    if ($match) {
        return $match
    }

    # Then, try exact match on DisplayName (case-insensitive)
    $match = $Properties | Where-Object { $_.DisplayName -ieq $PropertyName }
    if ($match) {
        return $match
    }

    # Then, try alias resolution
    $aliases = Get-PropertyAliases
    $candidates = $aliases[$PropertyName]
    if (-not $candidates) {
        # If not found in aliases, maybe the property name itself is a keyword pattern
        # We'll try wildcard match on RegistryKeyword if it contains '*'
        if ($PropertyName -like "*") {
            $match = $Properties | Where-Object { $_.RegistryKeyword -like $PropertyName }
            if ($match) {
                return $match
            }
        }
        return $null
    }

    foreach ($alias in $candidates) {
        # Try exact match on RegistryKeyword
        $match = $Properties | Where-Object { $_.RegistryKeyword -eq $alias }
        if ($match) {
            return $match
        }
        # Try wildcard match if alias contains '*'
        if ($alias -like "*") {
            $match = $Properties | Where-Object { $_.RegistryKeyword -like $alias }
            if ($match) {
                return $match
            }
        }
    }

    return $null
}
