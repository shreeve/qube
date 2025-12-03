import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VMFormView: View {
    @EnvironmentObject var vmManager: VMManager
    @Environment(\.dismiss) var dismiss

    let existingVM: VirtualMachine?

    @State private var name: String
    @State private var guestOS: VirtualMachine.GuestOS
    @State private var architecture: VirtualMachine.Architecture
    @State private var memoryMB: Int
    @State private var cpuCores: Int
    @State private var diskImagePath: String
    @State private var isoPath: String
    @State private var displayMode: VirtualMachine.DisplayMode

    init(vm: VirtualMachine?) {
        self.existingVM = vm
        _name = State(initialValue: vm?.name ?? "")
        _guestOS = State(initialValue: vm?.guestOS ?? .linux)
        _architecture = State(initialValue: vm?.architecture ?? .aarch64)
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
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)

                        if let error = validationError, !name.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Picker("Guest OS", selection: $guestOS) {
                        ForEach(VirtualMachine.GuestOS.allCases, id: \.self) { os in
                            Label(os.displayName, systemImage: os.iconName).tag(os)
                        }
                    }

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
                    FilePickerRow(
                        label: "Disk Image",
                        path: $diskImagePath,
                        allowedTypes: ["qcow2", "raw", "vmdk", "vdi", "img"],
                        prompt: "Select Disk Image"
                    )

                    FilePickerRow(
                        label: "ISO (optional)",
                        path: $isoPath,
                        allowedTypes: ["iso", "img"],
                        prompt: "Select ISO Image"
                    )
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
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 480)
    }

    private var canSave: Bool {
        validationError == nil
    }

    private var validationError: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Name is required
        if trimmedName.isEmpty {
            return "Name is required"
        }

        // Name must be unique (except for the VM being edited)
        let isDuplicate = vmManager.virtualMachines.contains { vm in
            vm.name.lowercased() == trimmedName.lowercased() && vm.id != existingVM?.id
        }
        if isDuplicate {
            return "A VM with this name already exists"
        }

        return nil
    }

    private func save() {
        var vm = existingVM ?? VirtualMachine(
            name: name,
            guestOS: guestOS,
            architecture: architecture,
            memoryMB: memoryMB,
            cpuCores: cpuCores,
            diskImagePath: diskImagePath,
            isoPath: isoPath.isEmpty ? nil : isoPath,
            displayMode: displayMode
        )

        if existingVM != nil {
            vm.name = name
            vm.guestOS = guestOS
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

// MARK: - File Picker Row

struct FilePickerRow: View {
    let label: String
    @Binding var path: String
    let allowedTypes: [String]
    let prompt: String

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 8) {
                Text(displayPath)
                    .foregroundStyle(path.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !path.isEmpty {
                    Button(action: clearPath) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Browse…") {
                    selectFile()
                }
            }
        }
    }

    private var displayPath: String {
        if path.isEmpty {
            return "None"
        }
        // Show just the filename for cleaner display
        return (path as NSString).lastPathComponent
    }

    private func clearPath() {
        path = ""
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedTypes.compactMap { ext in
            UTType(filenameExtension: ext)
        }

        // Start in a sensible location
        if !path.isEmpty {
            let expandedPath = NSString(string: path).expandingTildeInPath
            panel.directoryURL = URL(fileURLWithPath: expandedPath).deletingLastPathComponent()
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }

        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
