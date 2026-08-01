# Network Optimizer

**Production-grade PowerShell utility for Windows 10 and Windows 11** that optimizes network adapter advanced properties for gaming, low latency, and throughput.

## Features

- **Automatic detection** of network adapters (Ethernet, Wi‑Fi, USB Ethernet).
- **Supports all major vendors** – Intel, Realtek, Killer, Broadcom, Marvell, Aquantia, Qualcomm, Microsoft, and unknown.
- **Smart property resolution** – never assume a property exists; uses `Get-NetAdapterAdvancedProperty` and resolves aliases via RegistryKeyword.
- **Three presets**:
  - **Gaming** – minimal latency (disables interrupt moderation, flow control, LSO, RSC, EEE, etc.; enables RSS and max buffers).
  - **Balanced** – keeps Microsoft defaults; only safe optimizations.
  - **Throughput** – maximises file transfer performance (enables Jumbo Frames, LSO, interrupt moderation, RSS, RSC).
- **Backup & Restore** – exports all advanced properties to JSON before any change; restore with a single command.
- **Detailed logging** – timestamped logs with every property change, old/new values, status, and elapsed time.
- **Validation** – reads back each property to confirm the change succeeded.
- **No external dependencies** – pure PowerShell 5.1 / 7.

## Installation

Run the following command in an elevated PowerShell console:

```powershell
irm https://raw.githubusercontent.com//Sungjincude/NetworkOptimizer/main/Install.ps1 | iex
