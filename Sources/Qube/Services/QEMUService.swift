import Foundation

class QEMUService {
    static let shared = QEMUService()

    private var processes: [UUID: Process] = [:]

    func buildCommand(for vm: VirtualMachine) -> [String] {
        var args: [String] = []

        // Memory
        args.append(contentsOf: ["-m", "\(vm.memoryMB)M"])

        // CPU and machine type depend on architecture
        switch vm.architecture {
        case .aarch64:
            // ARM64 on Apple Silicon - use hardware virtualization
            args.append(contentsOf: ["-machine", "virt,highmem=on"])
            args.append(contentsOf: ["-accel", "hvf"])
            args.append(contentsOf: ["-cpu", "host"])
            args.append(contentsOf: ["-smp", "\(vm.cpuCores)"])

            // UEFI firmware (required for aarch64)
            let efiPath = "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
            args.append(contentsOf: ["-bios", efiPath])

            // VirtIO GPU for better graphics (good for desktops)
            args.append(contentsOf: ["-device", "virtio-gpu-pci"])

        case .x86_64:
            // x86_64 - emulated (slow on Apple Silicon)
            args.append(contentsOf: ["-machine", "q35"])
            args.append(contentsOf: ["-cpu", "max"])
            args.append(contentsOf: ["-smp", "\(vm.cpuCores)"])
            
        case .i386:
            // 32-bit x86 - for legacy OSes like Windows XP
            args.append(contentsOf: ["-machine", "pc"])
            args.append(contentsOf: ["-cpu", "pentium3"])
            args.append(contentsOf: ["-smp", "\(vm.cpuCores)"])
        }

        // Display
        args.append(contentsOf: ["-display", vm.displayMode.rawValue])

        // Disk (if provided)
        if !vm.diskImagePath.isEmpty {
            let expandedDiskPath = NSString(string: vm.diskImagePath).expandingTildeInPath
            args.append(contentsOf: ["-drive", "file=\(expandedDiskPath),format=qcow2,if=virtio"])
        }

        // ISO/CD-ROM (if provided)
        if let isoPath = vm.isoPath, !isoPath.isEmpty {
            let expandedISOPath = NSString(string: isoPath).expandingTildeInPath
            args.append(contentsOf: ["-cdrom", expandedISOPath])
        }

        // Network (virtio for best performance)
        args.append(contentsOf: ["-device", "virtio-net-pci,netdev=net0"])
        args.append(contentsOf: ["-netdev", "user,id=net0"])

        // USB for mouse/keyboard
        args.append(contentsOf: ["-usb"])
        args.append(contentsOf: ["-device", "usb-tablet"])
        args.append(contentsOf: ["-device", "usb-kbd"])

        // Audio (if on desktop)
        args.append(contentsOf: ["-audiodev", "coreaudio,id=audio0"])
        args.append(contentsOf: ["-device", "virtio-sound-pci,audiodev=audio0"])

        // Boot order: CD first (for installation), then disk
        args.append(contentsOf: ["-boot", "order=dc"])

        return args
    }

    func start(_ vm: VirtualMachine) throws -> Process {
        let process = Process()

        // Find QEMU binary
        let qemuPath = "/opt/homebrew/bin/\(vm.architecture.qemuBinary)"
        process.executableURL = URL(fileURLWithPath: qemuPath)
        process.arguments = buildCommand(for: vm)

        try process.run()
        processes[vm.id] = process

        return process
    }

    func stop(_ vm: VirtualMachine) {
        processes[vm.id]?.terminate()
        processes.removeValue(forKey: vm.id)
    }

    func isRunning(_ vm: VirtualMachine) -> Bool {
        processes[vm.id]?.isRunning ?? false
    }
}
