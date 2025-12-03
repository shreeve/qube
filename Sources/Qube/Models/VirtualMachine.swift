import Foundation

struct VirtualMachine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var guestOS: GuestOS
    var architecture: Architecture
    var memoryMB: Int
    var cpuCores: Int
    var diskImagePath: String
    var isoPath: String?
    var displayMode: DisplayMode

    // File metadata (not persisted in YAML)
    var configPath: URL?
    var lastModified: Date?

    enum GuestOS: String, Codable, CaseIterable {
        case windows = "windows"
        case macos = "macos"
        case linux = "linux"

        var displayName: String {
            switch self {
            case .windows: return "Windows"
            case .macos: return "macOS"
            case .linux: return "Linux"
            }
        }

        var iconName: String {
            switch self {
            case .windows: return "window.vertical.closed"
            case .macos: return "apple.logo"
            case .linux: return "terminal"
            }
        }
    }

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

    // Keys to exclude from YAML encoding
    enum CodingKeys: String, CodingKey {
        case id, name, guestOS, architecture, memoryMB, cpuCores
        case diskImagePath, isoPath, displayMode
    }

    static var example: VirtualMachine {
        VirtualMachine(
            name: "Windows 11",
            guestOS: .windows,
            architecture: .x86_64,
            memoryMB: 4096,
            cpuCores: 4,
            diskImagePath: "~/VMs/windows.qcow2",
            isoPath: nil,
            displayMode: .cocoa
        )
    }
}
