import SwiftUI

struct VMDetailView: View {
    let vm: VirtualMachine
    @EnvironmentObject var vmManager: VMManager
    @State private var isEditing = false

    var body: some View {
        Form {
            Section("Configuration") {
                LabeledContent("Architecture", value: vm.architecture.rawValue)
                LabeledContent("Memory", value: "\(vm.memoryMB) MB")
                LabeledContent("CPU Cores", value: "\(vm.cpuCores)")
                LabeledContent("Display", value: vm.displayMode.rawValue)
            }

            Section("Storage") {
                LabeledContent("Disk Image", value: vm.diskImagePath)
                if let iso = vm.isoPath, !iso.isEmpty {
                    LabeledContent("ISO", value: iso)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(vm.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                }

                Button(action: toggleRun) {
                    Image(systemName: vmManager.isRunning(vm) ? "stop.fill" : "play.fill")
                }
                .tint(vmManager.isRunning(vm) ? .red : .green)
            }
        }
        .sheet(isPresented: $isEditing) {
            VMFormView(vm: vm)
        }
    }

    private func toggleRun() {
        if vmManager.isRunning(vm) {
            QEMUService.shared.stop(vm)
            vmManager.runningVMs.remove(vm.id)
        } else {
            do {
                let process = try QEMUService.shared.start(vm)
                vmManager.runningVMs.insert(vm.id)

                // Monitor process termination
                process.terminationHandler = { _ in
                    Task { @MainActor in
                        vmManager.runningVMs.remove(vm.id)
                    }
                }
            } catch {
                print("Failed to start VM: \(error)")
            }
        }
    }
}

