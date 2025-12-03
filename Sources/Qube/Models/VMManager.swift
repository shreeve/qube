import Foundation
import SwiftUI
import Yams

@MainActor
class VMManager: ObservableObject {
    @Published var virtualMachines: [VirtualMachine] = []
    @Published var runningVMs: Set<UUID> = []
    @Published var showingNewVM: Bool = false
    @Published var selectedVM: VirtualMachine?

    private var processes: [UUID: Process] = [:]
    let machinesDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let qubeDir = appSupport.appendingPathComponent("Qube", isDirectory: true)
        self.machinesDirectory = qubeDir.appendingPathComponent("Machines", isDirectory: true)

        // Create directories
        try? FileManager.default.createDirectory(at: machinesDirectory, withIntermediateDirectories: true)

        load()
    }

    func load() {
        virtualMachines = []

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: machinesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for fileURL in files where fileURL.pathExtension == "yaml" {
            if var vm = loadVM(from: fileURL) {
                // Attach file metadata
                vm.configPath = fileURL
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    vm.lastModified = modDate
                }
                virtualMachines.append(vm)
            }
        }

        // Sort by last modified, newest first
        virtualMachines.sort { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
    }

    private func loadVM(from url: URL) -> VirtualMachine? {
        guard let yamlString = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let decoder = YAMLDecoder()
        return try? decoder.decode(VirtualMachine.self, from: yamlString)
    }

    func save(_ vm: VirtualMachine) {
        let encoder = YAMLEncoder()
        guard let yamlString = try? encoder.encode(vm) else { return }

        let fileName = sanitizeFileName(vm.name) + ".yaml"
        let fileURL = vm.configPath ?? machinesDirectory.appendingPathComponent(fileName)

        try? yamlString.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func add(_ vm: VirtualMachine) {
        var newVM = vm
        let fileName = sanitizeFileName(vm.name) + ".yaml"
        newVM.configPath = machinesDirectory.appendingPathComponent(fileName)
        newVM.lastModified = Date()

        save(newVM)
        virtualMachines.insert(newVM, at: 0)
    }

    func delete(_ vm: VirtualMachine) {
        // Delete the YAML file
        if let configPath = vm.configPath {
            try? FileManager.default.removeItem(at: configPath)
        }
        virtualMachines.removeAll { $0.id == vm.id }
    }

    func update(_ vm: VirtualMachine) {
        guard let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) else { return }

        let oldVM = virtualMachines[index]
        var updatedVM = vm
        updatedVM.lastModified = Date()

        // If name changed, we need to rename the file
        if oldVM.name != vm.name, let oldPath = oldVM.configPath {
            let newFileName = sanitizeFileName(vm.name) + ".yaml"
            let newPath = machinesDirectory.appendingPathComponent(newFileName)

            // Delete old file
            try? FileManager.default.removeItem(at: oldPath)
            updatedVM.configPath = newPath
        }

        save(updatedVM)
        virtualMachines[index] = updatedVM
    }

    func isRunning(_ vm: VirtualMachine) -> Bool {
        runningVMs.contains(vm.id)
    }

    private func sanitizeFileName(_ name: String) -> String {
        // Remove characters that aren't safe for filenames
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    func configDirectoryPath() -> String {
        machinesDirectory.path
    }
}
