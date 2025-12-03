import Foundation
import SwiftUI

@MainActor
class VMManager: ObservableObject {
    @Published var virtualMachines: [VirtualMachine] = []
    @Published var runningVMs: Set<UUID> = []
    @Published var showingNewVM: Bool = false
    @Published var selectedVM: VirtualMachine?

    private var processes: [UUID: Process] = [:]
    private let configURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let qubeDir = appSupport.appendingPathComponent("Qube", isDirectory: true)
        try? FileManager.default.createDirectory(at: qubeDir, withIntermediateDirectories: true)
        self.configURL = qubeDir.appendingPathComponent("vms.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: configURL),
              let vms = try? JSONDecoder().decode([VirtualMachine].self, from: data) else {
            return
        }
        virtualMachines = vms
    }

    func save() {
        guard let data = try? JSONEncoder().encode(virtualMachines) else { return }
        try? data.write(to: configURL)
    }

    func add(_ vm: VirtualMachine) {
        virtualMachines.append(vm)
        save()
    }

    func delete(_ vm: VirtualMachine) {
        virtualMachines.removeAll { $0.id == vm.id }
        save()
    }

    func update(_ vm: VirtualMachine) {
        if let index = virtualMachines.firstIndex(where: { $0.id == vm.id }) {
            virtualMachines[index] = vm
            save()
        }
    }

    func isRunning(_ vm: VirtualMachine) -> Bool {
        runningVMs.contains(vm.id)
    }
}

