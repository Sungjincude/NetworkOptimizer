<#
.SYNOPSIS
    Defines the optimization presets.
.DESCRIPTION
    Each preset is a hashtable mapping property names (as used in aliases) to desired values.
    Property names are resolved via VendorMappings.ps1.
#>

function Get-Preset {
    param(
        [string]$Name
    )
    $presets = @{
        "Gaming" = @{
            # ----- Core low‑latency settings -----
            "InterruptModeration"      = "0"          # Disabled
            "InterruptModerationRate"  = "0"          # Off
            "FlowControl"              = "0"          # Disabled
            "LsoV2IPv4"                = "0"          # Disabled
            "LsoV2IPv6"                = "0"          # Disabled
            "RscIPv4"                  = "0"          # Disabled
            "RscIPv6"                  = "0"          # Disabled
            "EEE"                      = "0"          # Disabled
            "GreenEthernet"            = "0"          # Disabled
            "PacketCoalescing"         = "0"          # Disabled
            "AdaptiveIFS"              = "0"          # Disabled
            "WakeOnMagicPacket"        = "0"          # Disabled
            "WakeOnPattern"            = "0"          # Disabled
            "ShutdownWakeOnLan"        = "0"          # Disabled
            "WakeOnLinkSettings"       = "0"          # Disabled

            # ----- RSS and buffering -----
            "RSS"                      = "Enabled"    # Enable RSS if supported
            "NumRssQueues"             = "128"        # Max queues (fallback to driver max)
            "RSSProfile"               = "1"          # RssProcessor (distribute across CPUs)
            "ReceiveBuffers"           = "512"        # Max for Realtek (32‑512)
            "TransmitBuffers"          = "128"        # Max for Realtek (32‑128)

            # ----- Checksum offloads (kept enabled for performance) -----
            "IPChecksumOffloadIPv4"    = "1"          # Enabled
            "TCPChecksumOffloadIPv4"   = "1"          # Enabled
            "TCPChecksumOffloadIPv6"   = "1"          # Enabled
            "UDPChecksumOffloadIPv4"   = "1"          # Enabled
            "UDPChecksumOffloadIPv6"   = "1"          # Enabled

            # ----- Power saving / unnecessary features (disabled) -----
            "SoftwareTimestamp"        = "0"          # Disabled
            "SystemIdlePowerSaver"     = "0"          # Disabled
            "UltraLowPowerMode"        = "0"          # Disabled
            "WaitForLink"              = "0"          # Disabled
            "ProtocolARPOffload"       = "0"          # Disabled
            "ProtocolNSOffload"        = "0"          # Disabled
            "PTPHardwareTimestamp"     = "0"          # Disabled
            "ReduceSpeedOnPowerDown"   = "0"          # Disabled
            "EnablePME"                = "0"          # Disabled
            "LegacySwitchCompatibility"= "0"          # Disabled
            "LinkSpeedBatterySaver"    = "0"          # Disabled
            "LogLinkStateEvent"        = "0"          # Disabled (optional)
        }

        "Balanced" = @{
            "RSS"                      = "Enabled"
            "InterruptModeration"      = "Enabled"    # Let driver decide
            "IPChecksumOffloadIPv4"    = "1"
            "TCPChecksumOffloadIPv4"   = "1"
            "TCPChecksumOffloadIPv6"   = "1"
            "UDPChecksumOffloadIPv4"   = "1"
            "UDPChecksumOffloadIPv6"   = "1"
        }

        "Throughput" = @{
            "JumboPacket"              = "9014"
            "LsoV2IPv4"                = "Enabled"
            "LsoV2IPv6"                = "Enabled"
            "InterruptModeration"      = "Enabled"
            "RSS"                      = "Enabled"
            "NumRssQueues"             = "128"
            "RSSProfile"               = "1"
            "ReceiveBuffers"           = "512"
            "TransmitBuffers"          = "128"
            "RscIPv4"                  = "Enabled"
            "RscIPv6"                  = "Enabled"
            "FlowControl"              = "Enabled"    # Helps with large transfers
            "EEE"                      = "0"
            "GreenEthernet"            = "0"
            "IPChecksumOffloadIPv4"    = "1"
            "TCPChecksumOffloadIPv4"   = "1"
            "TCPChecksumOffloadIPv6"   = "1"
            "UDPChecksumOffloadIPv4"   = "1"
            "UDPChecksumOffloadIPv6"   = "1"
        }
    }

    if ($presets.ContainsKey($Name)) {
        return $presets[$Name]
    }
    return $null
}
