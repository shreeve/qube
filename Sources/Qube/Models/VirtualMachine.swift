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

    // Snapshot display names (internal QEMU name → user-friendly name)
    var snapshotNames: [String: String] = [:]

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
        case aarch64 = "aarch64"
        case x86_64 = "x86_64"
        case i386 = "i386"

        var displayName: String {
            switch self {
            case .aarch64: return "ARM 64-bit"
            case .x86_64: return "Intel/AMD 64-bit"
            case .i386: return "Intel/AMD 32-bit"
            }
        }

        var qemuBinary: String {
            switch self {
            case .aarch64: return "qemu-system-aarch64"
            case .x86_64: return "qemu-system-x86_64"
            case .i386: return "qemu-system-i386"
            }
        }
    }

    enum DisplayMode: String, Codable, CaseIterable {
        case cocoa = "cocoa"
        case spice = "spice-app"
        case vnc = "vnc"
        case none = "none"

        var displayName: String {
            switch self {
            case .cocoa: return "macOS"
            case .spice: return "Spice"
            case .vnc: return "VNC"
            case .none: return "None"
            }
        }
    }

    // Keys to exclude from YAML encoding (configPath, lastModified are excluded)
    enum CodingKeys: String, CodingKey {
        case id, name, guestOS, architecture, memoryMB, cpuCores
        case diskImagePath, isoPath, displayMode, snapshotNames
    }

    // Custom decoder to handle missing snapshotNames in old YAML files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        guestOS = try container.decode(GuestOS.self, forKey: .guestOS)
        architecture = try container.decode(Architecture.self, forKey: .architecture)
        memoryMB = try container.decode(Int.self, forKey: .memoryMB)
        cpuCores = try container.decode(Int.self, forKey: .cpuCores)
        diskImagePath = try container.decode(String.self, forKey: .diskImagePath)
        isoPath = try container.decodeIfPresent(String.self, forKey: .isoPath)
        displayMode = try container.decode(DisplayMode.self, forKey: .displayMode)
        // Handle missing snapshotNames for backwards compatibility
        snapshotNames = try container.decodeIfPresent([String: String].self, forKey: .snapshotNames) ?? [:]
    }

    // Standard initializer
    init(id: UUID = UUID(), name: String, guestOS: GuestOS, architecture: Architecture,
         memoryMB: Int, cpuCores: Int, diskImagePath: String, isoPath: String? = nil,
         displayMode: DisplayMode, snapshotNames: [String: String] = [:],
         configPath: URL? = nil, lastModified: Date? = nil) {
        self.id = id
        self.name = name
        self.guestOS = guestOS
        self.architecture = architecture
        self.memoryMB = memoryMB
        self.cpuCores = cpuCores
        self.diskImagePath = diskImagePath
        self.isoPath = isoPath
        self.displayMode = displayMode
        self.snapshotNames = snapshotNames
        self.configPath = configPath
        self.lastModified = lastModified
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
