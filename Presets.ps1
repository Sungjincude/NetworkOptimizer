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
            # Low latency – use numeric values where expected
            "InterruptModeration"  = "0"          # Disabled
            "FlowControl"          = "0"          # Disabled
            "LsoV2IPv4"            = "0"          # Disabled
            "LsoV2IPv6"            = "0"          # Disabled
            "RscIPv4"              = "0"          # Disabled
            "RscIPv6"              = "0"          # Disabled
            "EEE"                  = "0"          # Disabled (if supported)
            "GreenEthernet"        = "0"          # Disabled
            "PacketCoalescing"     = "0"          # Disabled
            "AdaptiveIFS"          = "0"          # Disabled
            "RSS"                  = "Enabled"    # Enable if supported
            "NumRssQueues"         = "128"        # Max for Intel; will skip if not supported
            "ReceiveBuffers"       = "512"        # Max for Realtek (32‑512)
            "TransmitBuffers"      = "128"        # Max for Realtek (32‑128)
            "WakeOnMagicPacket"    = "0"          # Disabled
            "WakeOnPattern"        = "0"          # Disabled
            "ShutdownWakeOnLan"    = "0"          # Disabled
        }
        "Balanced" = @{
            "RSS"                  = "Enabled"
            "InterruptModeration"  = "Enabled"    # May be string or numeric; validation will handle
        }
        "Throughput" = @{
            "JumboPacket"          = "9014"
            "LsoV2IPv4"            = "Enabled"
            "LsoV2IPv6"            = "Enabled"
            "InterruptModeration"  = "Enabled"
            "RSS"                  = "Enabled"
            "NumRssQueues"         = "128"
            "ReceiveBuffers"       = "512"
            "TransmitBuffers"      = "128"
            "RscIPv4"              = "Enabled"
            "RscIPv6"              = "Enabled"
            "FlowControl"          = "Enabled"
            "EEE"                  = "0"
            "GreenEthernet"        = "0"
        }
    }

    if ($presets.ContainsKey($Name)) {
        return $presets[$Name]
    }
    return $null
}
