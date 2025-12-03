# Agent Instructions for Qube

This document helps AI agents get up to speed quickly on the Qube codebase.

## What is Qube?

Qube is a **SwiftUI frontend for QEMU** on macOS. It provides a clean, native UI for managing virtual machines while QEMU does the actual virtualization/emulation work.

**Philosophy**: Keep it simple. Don't over-engineer. QEMU is the powerhouse; Qube is just a nice launcher.

## Quick Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run directly
.build/release/Qube

# Build app bundle + DMG
./Scripts/build-app.sh --dmg

# Output location
dist/Qube.app
dist/Qube-1.0.0.dmg
```

## Project Structure

```
qube/
├── Package.swift                 # SPM config, depends on Yams for YAML
├── Sources/Qube/
│   ├── QubeApp.swift            # App entry point, AppDelegate, single-instance logic
│   ├── Models/
│   │   ├── VirtualMachine.swift # VM data model (Codable for YAML)
│   │   └── VMManager.swift      # State management, VM collection, persistence
│   ├── Services/
│   │   ├── QEMUService.swift    # QEMU command building, process management, monitor
│   │   └── SnapshotService.swift # qemu-img snapshot operations (offline)
│   └── Views/
│       ├── ContentView.swift    # Main NavigationSplitView layout
│       ├── VMListView.swift     # Sidebar with VM list
│       ├── VMDetailView.swift   # Detail pane with config editing
│       ├── VMFormView.swift     # New/Edit VM sheet
│       ├── NewVMView.swift      # Wrapper for VMFormView
│       └── DiskPickerView.swift # Disk image create/select dialog
├── Scripts/
│   ├── build-app.sh             # Creates Qube.app bundle and DMG
│   └── create-icns.sh           # Generates app icon
└── Resources/
    └── AppIcon.icns             # App icon
```

## Key Concepts

### VM Configuration Storage
- VMs stored as YAML files in `~/.config/qube/`
- One file per VM: `{uuid}.yaml`
- Human-readable and editable by hand
- Model: `VirtualMachine` struct with `Codable` conformance

### Architecture Support
| Architecture | QEMU Binary | Use Case |
|--------------|-------------|----------|
| `aarch64` | `qemu-system-aarch64` | ARM64 (native on Apple Silicon, fast!) |
| `x86_64` | `qemu-system-x86_64` | Intel/AMD 64-bit (emulated, slow) |
| `i386` | `qemu-system-i386` | Legacy 32-bit (XP, DOS) |

### Storage/Network by Architecture
```swift
// In QEMUService.buildCommand()
aarch64 & x86_64 → VirtIO disk + VirtIO network (modern, fast)
i386             → IDE disk + RTL8139 network (legacy compatible)
```

### QEMU Monitor (QMP)
- Each running VM has a Unix socket at `/tmp/qube-{uuid}.sock`
- Used for: pause, resume, live snapshots, graceful shutdown
- Commands sent via `nc -U` (netcat to Unix socket)
- Live snapshots include RAM state!

### Snapshots
Two types:
1. **Offline** (VM stopped): Uses `qemu-img snapshot` commands
2. **Live** (VM running): Uses QEMU monitor `savevm`/`loadvm` commands

Snapshot names:
- Internal QEMU name: `snap_YYYYMMDD_HHMMSS` (timestamp-based)
- Display name: User-editable, stored in `vm.snapshotNames` dictionary

## Important Files Deep Dive

### QEMUService.swift
The heart of VM launching. Key methods:
- `buildCommand(for:)` — Generates QEMU command-line arguments
- `start(_:)` — Spawns QEMU process
- `stop(_:)` — Graceful shutdown via monitor, then terminate
- `sendMonitorCommand(vm:command:)` — Sends commands to running VM
- `saveSnapshot/loadSnapshot/deleteSnapshot` — Live snapshot operations

### VMManager.swift
Observable state container:
- `virtualMachines: [VirtualMachine]` — All VMs
- `selectedVM: VirtualMachine?` — Currently selected
- `runningVMs: Set<UUID>` — Which VMs are running
- Handles loading/saving YAML configs
- Detects orphaned QEMU processes on startup

### VirtualMachine.swift
The data model. Key properties:
- `id`, `name`, `guestOS`, `architecture`
- `memoryMB`, `cpuCores`
- `diskImagePath`, `isoPath`, `displayMode`
- `snapshotNames: [String: String]` — Maps QEMU names to display names
- `configPath`, `lastModified` — Computed from filesystem

### VMDetailView.swift
The most complex view. Features:
- Inline editing of all VM properties
- Responsive two-column layout using `ViewThatFits`
- Snapshot management UI with create/rename/delete/restore
- Loading spinner during snapshot operations
- Change detection for save button state

## Common Tasks

### Adding a New VM Property
1. Add property to `VirtualMachine` struct
2. Add to `CodingKeys` enum
3. Handle in custom `init(from decoder:)` with fallback for old configs
4. Add UI in `VMDetailView` and/or `VMFormView`

### Adding a New QEMU Argument
1. Edit `QEMUService.buildCommand(for:)`
2. Consider architecture differences (aarch64 vs x86)
3. Test with all guest OS types

### Changing the App Icon
1. Place new 1024x1024 PNG in `Scripts/AppIcon.appiconset/`
2. Run `./Scripts/create-icns.sh`
3. Rebuild app: `./Scripts/build-app.sh`

## Gotchas & Tips

### Single Instance
Qube enforces single-instance via `AppDelegate.applicationWillFinishLaunching`. If another instance is running, it activates that one and terminates itself.

### ARM64 Needs UEFI
aarch64 VMs require UEFI firmware:
```swift
args.append(contentsOf: ["-bios", "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"])
```

### Audio Blocks Live Snapshots
VirtIO sound device prevents live snapshots. Audio is currently disabled:
```swift
// Commented out in QEMUService.buildCommand()
// args.append(contentsOf: ["-device", "virtio-sound-pci,audiodev=audio0"])
```

### File Paths
Always expand tilde in paths before passing to QEMU:
```swift
let expandedPath = NSString(string: vm.diskImagePath).expandingTildeInPath
```

### USB Controller Differences
- ARM64 (`virt` machine): Needs explicit `-device qemu-xhci`
- x86 (`pc`/`q35` machine): Has built-in USB, just use `-usb`

### Snapshot Display Names
When modifying snapshots, always fetch the *current* VM from `vmManager` to avoid overwriting other snapshot names:
```swift
guard var currentVM = vmManager.virtualMachines.first(where: { $0.id == vm.id }) else { return }
currentVM.snapshotNames[internalName] = displayName
vmManager.update(currentVM)
```

## Dependencies

- **Yams** (SPM): YAML parsing for VM configs
- **QEMU** (Homebrew): The actual virtualization engine
- **edk2** (Homebrew): UEFI firmware for ARM64 VMs

## Testing

Currently no automated tests. Manual testing:
1. Create VM with each architecture
2. Test start/stop
3. Test live snapshots (create, restore, delete, rename)
4. Test offline snapshots
5. Test window responsiveness (resize, two-column collapse)

## Build & Distribution

```bash
# Development
swift build && .build/debug/Qube

# Release
./Scripts/build-app.sh --dmg
# Output: dist/Qube.app, dist/Qube-1.0.0.dmg

# Install
cp -R dist/Qube.app /Applications/
```

Recipients need QEMU installed: `brew install qemu`

