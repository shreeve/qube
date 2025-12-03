import Foundation

class QEMUService {
    static let shared = QEMUService()

    private var processes: [UUID: Process] = [:]
    private var monitorSockets: [UUID: String] = [:]

    /// Get the monitor socket path for a VM
    func monitorSocketPath(for vm: VirtualMachine) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("qube-\(vm.id.uuidString).sock").path
    }

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

        // USB controller and devices
        if vm.architecture == .aarch64 {
            // ARM virt machine needs explicit USB controller
            args.append(contentsOf: ["-device", "qemu-xhci"])
        } else {
            // x86 machines have built-in USB
            args.append(contentsOf: ["-usb"])
        }
        args.append(contentsOf: ["-device", "usb-tablet"])
        args.append(contentsOf: ["-device", "usb-kbd"])

        // Audio (if on desktop)
        args.append(contentsOf: ["-audiodev", "coreaudio,id=audio0"])
        args.append(contentsOf: ["-device", "virtio-sound-pci,audiodev=audio0"])

        // Boot order: CD first (for installation), then disk
        args.append(contentsOf: ["-boot", "order=dc"])

        // Monitor socket for control (pause, snapshots, etc.)
        let socketPath = monitorSocketPath(for: vm)
        args.append(contentsOf: ["-monitor", "unix:\(socketPath),server,nowait"])

        return args
    }

    func start(_ vm: VirtualMachine) throws -> Process {
        let process = Process()

        // Clean up old socket if exists
        let socketPath = monitorSocketPath(for: vm)
        try? FileManager.default.removeItem(atPath: socketPath)

        // Find QEMU binary
        let qemuPath = "/opt/homebrew/bin/\(vm.architecture.qemuBinary)"
        process.executableURL = URL(fileURLWithPath: qemuPath)
        process.arguments = buildCommand(for: vm)

        try process.run()
        processes[vm.id] = process
        monitorSockets[vm.id] = socketPath

        return process
    }

    func stop(_ vm: VirtualMachine) {
        // Try graceful shutdown via monitor first
        sendMonitorCommand(vm: vm, command: "quit")

        // Give it a moment, then force terminate if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.processes[vm.id]?.isRunning == true {
                self?.processes[vm.id]?.terminate()
            }
            self?.processes.removeValue(forKey: vm.id)
            self?.monitorSockets.removeValue(forKey: vm.id)

            // Clean up socket
            let socketPath = self?.monitorSocketPath(for: vm) ?? ""
            try? FileManager.default.removeItem(atPath: socketPath)
        }
    }

    func isRunning(_ vm: VirtualMachine) -> Bool {
        processes[vm.id]?.isRunning ?? false
    }

    // MARK: - Monitor Commands

    /// Send a command to the QEMU monitor
    @discardableResult
    func sendMonitorCommand(vm: VirtualMachine, command: String) -> String? {
        guard let socketPath = monitorSockets[vm.id] else { return nil }

        // Use socat or nc to send command to socket
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "echo '\(command)' | nc -U '\(socketPath)'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Pause a running VM
    func pause(_ vm: VirtualMachine) -> Bool {
        sendMonitorCommand(vm: vm, command: "stop") != nil
    }

    /// Resume a paused VM
    func resume(_ vm: VirtualMachine) -> Bool {
        sendMonitorCommand(vm: vm, command: "cont") != nil
    }

    /// Take a live snapshot (includes RAM state!)
    func saveSnapshot(_ vm: VirtualMachine, name: String) -> Bool {
        sendMonitorCommand(vm: vm, command: "savevm \(name)") != nil
    }

    /// Load a snapshot (restores RAM state too)
    func loadSnapshot(_ vm: VirtualMachine, name: String) -> Bool {
        sendMonitorCommand(vm: vm, command: "loadvm \(name)") != nil
    }

    /// Get VM status
    func getStatus(_ vm: VirtualMachine) -> String? {
        sendMonitorCommand(vm: vm, command: "info status")
    }
}
