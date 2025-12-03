import Foundation

struct Snapshot: Identifiable {
    let id: String
    let name: String
    let date: Date?
    let vmSize: String?
}

class SnapshotService {
    static let shared = SnapshotService()

    /// List all snapshots for a disk image
    func list(diskPath: String) -> [Snapshot] {
        let expandedPath = NSString(string: diskPath).expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/qemu-img")
        process.arguments = ["snapshot", "-l", expandedPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return parseSnapshots(output)
        } catch {
            return []
        }
    }

    /// Create a new snapshot
    func create(diskPath: String, name: String) -> Bool {
        let expandedPath = NSString(string: diskPath).expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/qemu-img")
        process.arguments = ["snapshot", "-c", name, expandedPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Restore a snapshot (VM must be stopped)
    func restore(diskPath: String, name: String) -> Bool {
        let expandedPath = NSString(string: diskPath).expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/qemu-img")
        process.arguments = ["snapshot", "-a", name, expandedPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Delete a snapshot
    func delete(diskPath: String, name: String) -> Bool {
        let expandedPath = NSString(string: diskPath).expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/qemu-img")
        process.arguments = ["snapshot", "-d", name, expandedPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Parse qemu-img snapshot -l output
    private func parseSnapshots(_ output: String) -> [Snapshot] {
        var snapshots: [Snapshot] = []
        let lines = output.components(separatedBy: "\n")

        // Skip header lines, look for snapshot entries
        // Format: ID  TAG  VM_SIZE  DATE  VM_CLOCK
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if trimmed.isEmpty || trimmed.hasPrefix("Snapshot") || trimmed.hasPrefix("ID") {
                continue
            }

            // Parse snapshot line
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 2 {
                let id = components[0]
                let name = components[1]
                let vmSize = components.count > 2 ? components[2] : nil

                // Try to parse date (format varies)
                var date: Date? = nil
                if components.count >= 5 {
                    let dateStr = "\(components[3]) \(components[4])"
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    date = formatter.date(from: dateStr)
                }

                snapshots.append(Snapshot(id: id, name: name, date: date, vmSize: vmSize))
            }
        }

        return snapshots
    }
}
