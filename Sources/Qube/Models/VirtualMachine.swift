import Foundation

struct VirtualMachine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var architecture: Architecture
    var memoryMB: Int
    var cpuCores: Int
    var diskImagePath: String
    var isoPath: String?
    var displayMode: DisplayMode

    enum Architecture: String, Codable, CaseIterable {
        case x86_64 = "x86_64"
        case aarch64 = "aarch64"

        var qemuBinary: String {
            switch self {
            case .x86_64: return "qemu-system-x86_64"
            case .aarch64: return "qemu-system-aarch64"
            }
        }
    }

    enum DisplayMode: String, Codable, CaseIterable {
        case cocoa = "cocoa"
        case spice = "spice-app"
        case vnc = "vnc"
        case none = "none"
    }

    static var example: VirtualMachine {
        VirtualMachine(
            name: "Windows 11",
            architecture: .x86_64,
            memoryMB: 4096,
            cpuCores: 4,
            diskImagePath: "~/VMs/windows.qcow2",
            isoPath: nil,
            displayMode: .cocoa
        )
    }
}
