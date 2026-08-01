<#
.SYNOPSIS
    Defines the optimization presets.
.DESCRIPTION
    Each preset is a hashtable mapping property names (as used in aliases) to desired values.
    The property names are resolved via VendorMappings.ps1.
#>

function Get-Preset {
    param(
        [string]$Name
    )
    $presets = @{
        "Gaming" = @{
            # Low latency
            "InterruptModeration"  = "Disabled"
            "FlowControl"          = "Disabled"
            "LsoV2IPv4"            = "Disabled"
            "LsoV2IPv6"            = "Disabled"
            "RscIPv4"              = "Disabled"
            "RscIPv6"              = "Disabled"
            "EEE"                  = "Disabled"
            "GreenEthernet"        = "Disabled"
            "PacketCoalescing"     = "Disabled"
            "AdaptiveIFS"          = "Disabled"   # if present
            "RSS"                  = "Enabled"
            "NumRssQueues"         = "16"         # or max; will be validated
            "ReceiveBuffers"       = "1024"       # try to set high; validation will catch max
            "TransmitBuffers"      = "1024"
            # SpeedDuplex: keep Auto unless manually specified. We'll not set it.
            # Checksum offloads: leave as is (document tradeoffs)
            # Wake on LAN: disable
            "WakeOnMagicPacket"    = "Disabled"
            "WakeOnPattern"        = "Disabled"
            "ShutdownWakeOnLan"    = "Disabled"
            # JumboFrames: not enabled by default
        }
        "Balanced" = @{
            # Keep defaults; we will not change anything unless it's known beneficial.
            # We'll define a few safe optimizations like RSS enabled, moderate buffers.
            "RSS"                  = "Enabled"
            "InterruptModeration"  = "Enabled"
            # Leave others as is; we might skip entirely.
        }
        "Throughput" = @{
            # Maximize throughput
            "JumboPacket"          = "9014"       # if supported
            "LsoV2IPv4"            = "Enabled"
            "LsoV2IPv6"            = "Enabled"
            "InterruptModeration"  = "Enabled"
            "RSS"                  = "Enabled"
            "NumRssQueues"         = "16"
            "ReceiveBuffers"       = "2048"
            "TransmitBuffers"      = "2048"
            "RscIPv4"              = "Enabled"
            "RscIPv6"              = "Enabled"
            "FlowControl"          = "Enabled"    # for throughput, may help
            "EEE"                  = "Disabled"   # Energy efficient can reduce throughput
            "GreenEthernet"        = "Disabled"
        }
    }

    if ($presets.ContainsKey($Name)) {
        return $presets[$Name]
    }
    return $null
}
