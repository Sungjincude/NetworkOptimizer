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
        # Existing mappings
        "FlowControl"                = @("*FlowControl")
        "RSS"                        = @("*RSS")
        "NumRssQueues"               = @("*NumRssQueues", "Maximum Number of RSS Queues")
        "RSSProfile"                 = @("*RSSProfile", "RSS load balancing profile")
        "InterruptModeration"        = @("*InterruptModeration")
        "InterruptModerationRate"    = @("*InterruptModerationRate")
        "ITR"                        = @("*ITR")
        "LsoV2IPv4"                  = @("*LsoV2IPv4", "Large Send Offload V2 (IPv4)")
        "LsoV2IPv6"                  = @("*LsoV2IPv6", "Large Send Offload V2 (IPv6)")
        "IPChecksumOffloadIPv4"      = @("*IPChecksumOffloadIPv4", "IPv4 Checksum Offload")
        "TCPChecksumOffloadIPv4"     = @("*TCPChecksumOffloadIPv4", "TCP Checksum Offload (IPv4)")
        "TCPChecksumOffloadIPv6"     = @("*TCPChecksumOffloadIPv6", "TCP Checksum Offload (IPv6)")
        "UDPChecksumOffloadIPv4"     = @("*UDPChecksumOffloadIPv4", "UDP Checksum Offload (IPv4)")
        "UDPChecksumOffloadIPv6"     = @("*UDPChecksumOffloadIPv6", "UDP Checksum Offload (IPv6)")
        "JumboPacket"                = @("*JumboPacket", "Jumbo Packet")
        "ReceiveBuffers"             = @("*ReceiveBuffers", "Receive Buffers")
        "TransmitBuffers"            = @("*TransmitBuffers", "Transmit Buffers")
        "RscIPv4"                    = @("*RscIPv4")
        "RscIPv6"                    = @("*RscIPv6")
        "EEE"                        = @("*EEE", "Energy Efficient Ethernet", "EnableGreenEthernet", "AdvancedEEE", "EEELinkAdvertisement")
        "GreenEthernet"              = @("EnableGreenEthernet", "GreenEthernet", "*EEE")
        "AdvancedEEE"                = @("AdvancedEEE", "*EEE")
        "PacketCoalescing"           = @("*PacketCoalescing")
        "PriorityVLANTag"            = @("*PriorityVLANTag", "Packet Priority & VLAN")
        "VlanID"                     = @("*VlanID")
        "SpeedDuplex"                = @("*SpeedDuplex", "Speed & Duplex")
        "WakeOnMagicPacket"          = @("*WakeOnMagicPacket", "Wake on Magic Packet")
        "WakeOnPattern"              = @("*WakeOnPattern", "Wake on Pattern Match")
        "ShutdownWakeOnLan"          = @("ShutdownWakeOnLan")
        "AdaptiveIFS"                = @("*AdaptiveIFS", "Adaptive Inter-Frame Spacing")
        "MasterSlave"                = @("*MasterSlave", "Gigabit Master Slave Mode")
        "NetworkAddress"             = @("NetworkAddress", "Locally Administered Address")
        "AutoDisableGigabit"         = @("AutoDisableGigabit")
        "GigabitLite"                = @("GigabitLite")

        # ----- Newly added mappings (from images) -----
        "SoftwareTimestamp"          = @("*SoftwareTimestamp", "Software Timestamp")
        "SystemIdlePowerSaver"       = @("*SystemIdlePowerSaver", "System Idle Power Saver")
        "UltraLowPowerMode"          = @("*UltraLowPowerMode", "Ultra Low Power Mode")
        "WaitForLink"                = @("*WaitForLink", "Wait for Link")
        "WakeOnLinkSettings"         = @("*WakeOnLinkSettings", "Wake on Link Settings")
        "LogLinkStateEvent"          = @("*LogLinkStateEvent", "Log Link State Event")
        "ProtocolARPOffload"         = @("*ProtocolARPOffload", "Protocol ARP Offload")
        "ProtocolNSOffload"          = @("*ProtocolNSOffload", "Protocol NS Offload")
        "PTPHardwareTimestamp"       = @("*PTPHardwareTimestamp", "PTP Hardware Timestamp")
        "ReduceSpeedOnPowerDown"     = @("*ReduceSpeedOnPowerDown", "Reduce Speed On Power Down")
        "EnablePME"                  = @("*EnablePME", "Enable PME")
        "LegacySwitchCompatibility"  = @("*LegacySwitchCompatibility", "Legacy Switch Compatibility Mode")
        "LinkSpeedBatterySaver"      = @("*LinkSpeedBatterySaver", "Link Speed Battery Saver")
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
        # Wildcard match if alias contains '*'
        if ($alias -like "*") {
            $match = $Properties | Where-Object { $_.RegistryKeyword -like $alias }
            if ($match) {
                return $match
            }
        }
        # Also try partial match on DisplayName (some aliases may be display names)
        $match = $Properties | Where-Object { $_.DisplayName -ieq $alias }
        if ($match) {
            return $match
        }
    }

    return $null
}
