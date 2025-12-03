import SwiftUI

struct VMFormView: View {
    @EnvironmentObject var vmManager: VMManager
    @Environment(\.dismiss) var dismiss

    let existingVM: VirtualMachine?

    @State private var name: String
    @State private var architecture: VirtualMachine.Architecture
    @State private var memoryMB: Int
    @State private var cpuCores: Int
    @State private var diskImagePath: String
    @State private var isoPath: String
    @State private var displayMode: VirtualMachine.DisplayMode

    init(vm: VirtualMachine?) {
        self.existingVM = vm
        _name = State(initialValue: vm?.name ?? "")
        _architecture = State(initialValue: vm?.architecture ?? .x86_64)
        _memoryMB = State(initialValue: vm?.memoryMB ?? 4096)
        _cpuCores = State(initialValue: vm?.cpuCores ?? 4)
        _diskImagePath = State(initialValue: vm?.diskImagePath ?? "")
        _isoPath = State(initialValue: vm?.isoPath ?? "")
        _displayMode = State(initialValue: vm?.displayMode ?? .cocoa)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Name", text: $name)
                    Picker("Architecture", selection: $architecture) {
                        ForEach(VirtualMachine.Architecture.allCases, id: \.self) { arch in
                            Text(arch.rawValue).tag(arch)
                        }
                    }
                }

                Section("Hardware") {
                    Picker("Memory", selection: $memoryMB) {
                        Text("2 GB").tag(2048)
                        Text("4 GB").tag(4096)
                        Text("8 GB").tag(8192)
                        Text("16 GB").tag(16384)
                    }
                    Picker("CPU Cores", selection: $cpuCores) {
                        ForEach([1, 2, 4, 6, 8], id: \.self) { cores in
                            Text("\(cores)").tag(cores)
                        }
                    }
                    Picker("Display", selection: $displayMode) {
                        ForEach(VirtualMachine.DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Storage") {
                    TextField("Disk Image Path", text: $diskImagePath)
                    TextField("ISO Path (optional)", text: $isoPath)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingVM == nil ? "New Virtual Machine" : "Edit Virtual Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || diskImagePath.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    private func save() {
        var vm = existingVM ?? VirtualMachine(
            name: name,
            architecture: architecture,
            memoryMB: memoryMB,
            cpuCores: cpuCores,
            diskImagePath: diskImagePath,
            isoPath: isoPath.isEmpty ? nil : isoPath,
            displayMode: displayMode
        )

        if existingVM != nil {
            vm.name = name
            vm.architecture = architecture
            vm.memoryMB = memoryMB
            vm.cpuCores = cpuCores
            vm.diskImagePath = diskImagePath
            vm.isoPath = isoPath.isEmpty ? nil : isoPath
            vm.displayMode = displayMode
            vmManager.update(vm)
        } else {
            vmManager.add(vm)
        }

        dismiss()
    }
}
