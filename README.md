# Qube

A clean, minimal SwiftUI frontend for QEMU on macOS.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2015+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/Architecture-Apple%20Silicon-green?style=flat-square" alt="Architecture">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="License">
</p>

---

## Overview

Qube is a native macOS application that provides a beautiful, intuitive interface for managing QEMU virtual machines. Built with SwiftUI, it's designed for power users who understand QEMU but want a polished launcher without the complexity of enterprise virtualization tools.

**Philosophy**: Simple, focused, and stays out of your way. QEMU does the heavy lifting; Qube makes it pleasant.

## Features

- **VM Library** — Visual list of all your virtual machines with status indicators
- **One-Click Launch** — Start and stop VMs with a single click
- **Live Snapshots** — Create, restore, and manage snapshots while VMs are running
- **Native Feel** — Built with SwiftUI for a true macOS experience
- **YAML Configs** — Human-readable configuration files you can edit by hand
- **Multiple Architectures** — ARM64, x86_64, and i386 support
- **Guest OS Detection** — Automatic icons for Windows, macOS, and Linux guests

## Requirements

- **macOS 15** (Tahoe) or later
- **Apple Silicon** (M1/M2/M3/M4/M5) recommended
- **QEMU** installed via Homebrew
- **Xcode 15+** (for building from source)

## Installation

### Prerequisites

Install QEMU and required firmware:

```bash
# Install QEMU
brew install qemu

# For ARM64 VMs, you'll also need UEFI firmware
brew install edk2  # Provides aarch64 UEFI
```

### Building from Source

```bash
# Clone the repository
git clone https://github.com/your-username/qube.git
cd qube

# Build and run (command line)
swift build -c release
.build/release/Qube
```

### Creating an App Bundle

Use the included build script to create a proper `.app` bundle with icon:

```bash
# Build Qube.app
./Scripts/build-app.sh

# Or build with a DMG for distribution
./Scripts/build-app.sh --dmg
```

This creates:
- `dist/Qube.app` — Ready-to-use application (3.3 MB)
- `dist/Qube-1.0.0.dmg` — Distributable disk image (1.8 MB)

**Install to Applications:**
```bash
cp -R dist/Qube.app /Applications/
```

### Pre-built Releases

Download the latest `Qube-x.x.x.dmg` from the [Releases](https://github.com/your-username/qube/releases) page:

1. Open the DMG
2. Drag `Qube.app` to Applications
3. Launch from Applications or Spotlight

## Quick Start

1. **Launch Qube** — The app opens with an empty VM library
2. **Create a VM** — Click the `+` button or press `⌘N`
3. **Configure** — Set name, architecture, RAM, CPU cores, and disk image
4. **Run** — Click the Play button to start your VM

### Creating a Disk Image

Qube can create disk images for you, or you can create one manually:

```bash
# Create a 64GB dynamically-sized disk
qemu-img create -f qcow2 ~/VMs/my-disk.qcow2 64G
```

## Configuration

VM configurations are stored as YAML files in:

```
~/.config/qube/
```

Example configuration:

```yaml
id: "550e8400-e29b-41d4-a716-446655440000"
name: "Ubuntu 24.04"
guestOS: "linux"
architecture: "aarch64"
memoryMB: 8192
cpuCores: 4
diskImagePath: "~/VMs/ubuntu.qcow2"
isoPath: "~/ISOs/ubuntu-24.04-arm64.iso"
displayMode: "cocoa"
snapshotNames:
  snap_20241203_142530: "Fresh Install"
  snap_20241203_153045: "After Updates"
```

## Snapshots

Qube supports both offline and live snapshots:

| Type | VM State | What's Saved |
|------|----------|--------------|
| **Offline** | Stopped | Disk state only |
| **Live** | Running | Disk + RAM (full state) |

Live snapshots let you "time travel" — restore to any point and continue exactly where you left off, including all running applications.

### Snapshot Commands

Under the hood, Qube uses:

```bash
# Offline snapshots (qemu-img)
qemu-img snapshot -c "snapshot_name" disk.qcow2
qemu-img snapshot -a "snapshot_name" disk.qcow2  # restore
qemu-img snapshot -l disk.qcow2                   # list

# Live snapshots (QEMU Monitor)
savevm snapshot_name
loadvm snapshot_name
info snapshots
```

---

## Getting Started with Guest Operating Systems

### Ubuntu (ARM64) — Recommended First VM

Ubuntu ARM64 runs excellently on Apple Silicon via QEMU with hardware virtualization.

1. **Download Ubuntu ARM64**:
   - Visit [ubuntu.com/download/server/arm](https://ubuntu.com/download/server/arm)
   - Or for Desktop: [cdimage.ubuntu.com](https://cdimage.ubuntu.com/jammy/daily-live/current/)

2. **Create disk image**:
   ```bash
   qemu-img create -f qcow2 ~/VMs/ubuntu.qcow2 64G
   ```

3. **Create VM in Qube**:
   - Name: `Ubuntu 24.04`
   - Guest OS: Linux
   - Architecture: ARM 64-bit
   - RAM: 4096 MB (or more)
   - CPU Cores: 4
   - Disk Image: `~/VMs/ubuntu.qcow2`
   - ISO: Your downloaded Ubuntu ISO

4. **Run and install** — Ubuntu installer will boot automatically

---

### Windows 11 (ARM64)

Windows 11 ARM64 runs great on Apple Silicon with near-native performance using Hypervisor.framework acceleration.

#### Option 1: Microsoft Insider Preview (Recommended)

Microsoft provides ready-to-use VHDX images — no installation required!

1. **Download from Microsoft**:
   - Visit: [microsoft.com/en-us/software-download/windowsinsiderpreviewarm64](https://www.microsoft.com/en-us/software-download/windowsinsiderpreviewarm64)
   - Sign in with a Microsoft account (free)
   - Download the VHDX file (~10GB)

2. **Convert VHDX to QCOW2** (recommended for snapshots):
   ```bash
   qemu-img convert -p -f vhdx -O qcow2 \
     ~/Downloads/Windows11_InsiderPreview_Client_ARM64_en-us_XXXXX.VHDX \
     ~/VMs/windows11-arm64.qcow2
   ```

3. **Create VM in Qube**:
   - Name: `Windows 11`
   - Guest OS: Windows
   - Architecture: ARM 64-bit
   - RAM: 8192 MB (8GB minimum)
   - CPU Cores: 4+
   - Disk Image: `~/VMs/windows11-arm64.qcow2`
   - Display: macOS

4. **First boot** — Windows will complete setup (OOBE)

#### Option 2: UUP Dump (Build ISO from Update Files)

This method downloads official Microsoft update packages and builds an ISO locally.

1. **Install required tools**:
   ```bash
   brew install aria2 wimlib cabextract cdrtools
   ```

2. **Visit [uupdump.net](https://uupdump.net)**:
   - Select "Latest Public Release build" → ARM64
   - Choose language (English US)
   - Select edition (Windows Pro)
   - Choose "Download and convert to ISO"
   - Click "Create download package"

3. **Build the ISO** (requires Linux or Docker on macOS):
   ```bash
   # On Linux
   chmod +x uup_download_linux.sh
   ./uup_download_linux.sh

   # On macOS with Docker
   docker run -it --rm -v $(pwd):/uup debian:latest bash -c "
     apt-get update &&
     apt-get install -y cabextract wimtools chntpw genisoimage aria2 xxd &&
     cd /uup && bash uup_download_linux.sh
   "
   ```

#### Why ARM64 Instead of x86?

| | ARM64 (Native) | x86_64 (Emulated) |
|---|---|---|
| **Performance** | Near-native speed | 5-10x slower |
| **Virtualization** | HVF accelerated | Full emulation |
| **Use case** | Daily driver | Legacy software only |

> **Recommendation**: Always use ARM64 Windows on Apple Silicon. x86 emulation is functional but painfully slow.

---

### Legacy Operating Systems (x86/i386)

For older operating systems like Windows XP, DOS, or 32-bit Linux:

```bash
# Create a small disk for legacy OS
qemu-img create -f qcow2 ~/VMs/legacy.qcow2 20G
```

In Qube, select:
- Architecture: **Intel/AMD 32-bit** (for Windows XP, DOS)
- Architecture: **Intel/AMD 64-bit** (for older 64-bit systems)

> **Note**: x86 emulation on ARM is slow. Use for compatibility testing, not daily use.

---

## Architecture

```
Qube/
├── Package.swift           # Swift Package Manager config
└── Sources/Qube/
    ├── QubeApp.swift       # App entry point, lifecycle
    ├── Models/
    │   ├── VirtualMachine.swift   # VM data model
    │   └── VMManager.swift        # State management
    ├── Services/
    │   ├── QEMUService.swift      # QEMU process management
    │   └── SnapshotService.swift  # Snapshot operations
    └── Views/
        ├── ContentView.swift      # Main layout
        ├── VMListView.swift       # Sidebar VM list
        ├── VMDetailView.swift     # VM configuration panel
        └── NewVMView.swift        # New VM creation sheet
```

## QEMU Command Generation

Qube generates QEMU commands based on your VM configuration. Example for an ARM64 VM:

```bash
qemu-system-aarch64 \
  -name "Ubuntu 24.04" \
  -machine virt \
  -accel hvf \
  -cpu host \
  -smp 4 \
  -m 8192 \
  -device qemu-xhci \
  -device usb-kbd \
  -device usb-tablet \
  -device virtio-gpu-pci \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -drive if=virtio,file=ubuntu.qcow2,format=qcow2 \
  -cdrom ubuntu-24.04-arm64.iso \
  -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -display cocoa \
  -qmp unix:/tmp/qube-vm-id.sock,server,nowait
```

## Troubleshooting

### VM won't start

1. **Check QEMU installation**: `which qemu-system-aarch64`
2. **Verify firmware**: `ls /opt/homebrew/share/qemu/edk2-aarch64-code.fd`
3. **Check disk image**: `qemu-img info your-disk.qcow2`

### No network in guest

Qube uses QEMU's user-mode networking (NAT). The guest should automatically get an IP via DHCP. If not:
- Check that `virtio-net-pci` is being used
- Some guests need VirtIO drivers installed

### Snapshots not working

- **Live snapshots** require the VM to be started through Qube (for QMP socket)
- **Offline snapshots** work on any qcow2 disk
- Certain QEMU devices block live snapshots (audio devices, some USB)

### Slow performance

- Use **ARM64** guests on Apple Silicon (not x86 emulation)
- Enable **HVF acceleration** (automatic for ARM64)
- Allocate sufficient **RAM** (4GB+ for modern OSes)
- Use **VirtIO** drivers in guests for disk/network

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [QEMU](https://www.qemu.org/) — The incredible emulator that makes this possible
- [Yams](https://github.com/jpsim/Yams) — YAML parsing for Swift
- Apple's Hypervisor.framework — Near-native ARM64 virtualization

---

<p align="center">
  Made with ❤️ for the Mac
</p>
