import Foundation

class QEMUService {
    static let shared = QEMUService()

    private var processes: [UUID: Process] = [:]

    func buildCommand(for vm: VirtualMachine) -> [String] {
        var args: [String] = []

        // Memory
        args.append(contentsOf: ["-m", "\(vm.memoryMB)M"])

        // CPU
        args.append(contentsOf: ["-smp", "\(vm.cpuCores)"])
        args.append(contentsOf: ["-cpu", "max"])

        // Machine type
        args.append(contentsOf: ["-machine", "q35"])

        // Display
        args.append(contentsOf: ["-display", vm.displayMode.rawValue])

        // Disk
        let expandedDiskPath = NSString(string: vm.diskImagePath).expandingTildeInPath
        args.append(contentsOf: ["-drive", "file=\(expandedDiskPath),format=qcow2"])

        // ISO if present
        if let isoPath = vm.isoPath, !isoPath.isEmpty {
            let expandedISOPath = NSString(string: isoPath).expandingTildeInPath
            args.append(contentsOf: ["-cdrom", expandedISOPath])
        }

        // USB tablet for better mouse support
        args.append(contentsOf: ["-usb", "-device", "usb-tablet"])

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
