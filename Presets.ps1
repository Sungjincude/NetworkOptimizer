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
            "AdaptiveIFS"          = "Disabled"
            "RSS"                  = "Enabled"
            "NumRssQueues"         = "128"        # Changed from 16 to 128 (valid range: 32‑128, inc 8)
            "ReceiveBuffers"       = "2048"       # Increased from 1024
            "TransmitBuffers"      = "2048"       # Increased from 1024
            "WakeOnMagicPacket"    = "Disabled"
            "WakeOnPattern"        = "Disabled"
            "ShutdownWakeOnLan"    = "Disabled"
        }
        "Balanced" = @{
            "RSS"                  = "Enabled"
            "InterruptModeration"  = "Enabled"
        }
        "Throughput" = @{
            "JumboPacket"          = "9014"
            "LsoV2IPv4"            = "Enabled"
            "LsoV2IPv6"            = "Enabled"
            "InterruptModeration"  = "Enabled"
            "RSS"                  = "Enabled"
            "NumRssQueues"         = "128"
            "ReceiveBuffers"       = "2048"
            "TransmitBuffers"      = "2048"
            "RscIPv4"              = "Enabled"
            "RscIPv6"              = "Enabled"
            "FlowControl"          = "Enabled"
            "EEE"                  = "Disabled"
            "GreenEthernet"        = "Disabled"
        }
    }

    if ($presets.ContainsKey($Name)) {
        return $presets[$Name]
    }
    return $null
}
