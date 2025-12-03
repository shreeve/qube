import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VMDetailView: View {
    let vm: VirtualMachine
    @EnvironmentObject var vmManager: VMManager

    // Editable fields
    @State private var name: String = ""
    @State private var guestOS: VirtualMachine.GuestOS = .linux
    @State private var architecture: VirtualMachine.Architecture = .aarch64
    @State private var memoryMB: Int = 4096
    @State private var cpuCores: Int = 4
    @State private var diskImagePath: String = ""
    @State private var isoPath: String = ""
    @State private var displayMode: VirtualMachine.DisplayMode = .cocoa

    @State private var hasChanges = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with icon and name
                headerSection

                Divider()
                    .padding(.horizontal)

                // Configuration sections
                VStack(spacing: 24) {
                    systemSection
                    hardwareSection
                    storageSection
                    configInfoSection
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if hasChanges {
                    Button("Revert") { loadFromVM() }
                        .foregroundStyle(.secondary)

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                }

                Button(action: toggleRun) {
                    Image(systemName: vmManager.isRunning(vm) ? "stop.fill" : "play.fill")
                        .foregroundStyle(vmManager.isRunning(vm) ? .red : .green)
                }
                .buttonStyle(.bordered)

                Menu {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete VM", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { loadFromVM() }
        .onChange(of: vm.id) { _, _ in loadFromVM() }
        .alert("Delete Virtual Machine?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                vmManager.delete(vm)
                vmManager.selectedVM = nil
            }
        } message: {
            Text("This will delete \"\(vm.name)\" and its configuration file. Disk images will not be deleted.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Large OS icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(iconBackgroundColor.gradient)
                    .frame(width: 72, height: 72)

                Image(systemName: guestOS.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("VM Name", text: $name)
                    .font(.title.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: name) { _, _ in checkForChanges() }

                HStack(spacing: 8) {
                    if vmManager.isRunning(vm) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Running")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text("Stopped")
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(architecture.rawValue)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - System Section

    private var systemSection: some View {
        ConfigSection(title: "System", icon: "cpu") {
            ConfigRow(label: "Guest OS") {
                Picker("", selection: $guestOS) {
                    ForEach(VirtualMachine.GuestOS.allCases, id: \.self) { os in
                        Label(os.displayName, systemImage: os.iconName).tag(os)
                    }
                }
                .labelsHidden()
                .onChange(of: guestOS) { _, _ in checkForChanges() }
            }

            ConfigRow(label: "Architecture") {
                Picker("", selection: $architecture) {
                    ForEach(VirtualMachine.Architecture.allCases, id: \.self) { arch in
                        Text(arch.rawValue).tag(arch)
                    }
                }
                .labelsHidden()
                .onChange(of: architecture) { _, _ in checkForChanges() }
            }
        }
    }

    // MARK: - Hardware Section

    private var hardwareSection: some View {
        ConfigSection(title: "Hardware", icon: "memorychip") {
            ConfigRow(label: "Memory") {
                Picker("", selection: $memoryMB) {
                    Text("2 GB").tag(2048)
                    Text("4 GB").tag(4096)
                    Text("8 GB").tag(8192)
                    Text("16 GB").tag(16384)
                }
                .labelsHidden()
                .onChange(of: memoryMB) { _, _ in checkForChanges() }
            }

            ConfigRow(label: "CPU Cores") {
                Picker("", selection: $cpuCores) {
                    ForEach([1, 2, 4, 6, 8], id: \.self) { cores in
                        Text("\(cores)").tag(cores)
                    }
                }
                .labelsHidden()
                .onChange(of: cpuCores) { _, _ in checkForChanges() }
            }

            ConfigRow(label: "Display") {
                Picker("", selection: $displayMode) {
                    ForEach(VirtualMachine.DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .onChange(of: displayMode) { _, _ in checkForChanges() }
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        ConfigSection(title: "Storage", icon: "internaldrive") {
            ConfigRow(label: "Disk Image") {
                HStack(spacing: 8) {
                    Text(diskImagePath.isEmpty ? "None" : (diskImagePath as NSString).lastPathComponent)
                        .foregroundStyle(diskImagePath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if !diskImagePath.isEmpty {
                        Button(action: { diskImagePath = ""; checkForChanges() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Browse…") {
                        selectFile(for: .disk)
                    }
                }
            }

            ConfigRow(label: "ISO") {
                HStack(spacing: 8) {
                    Text(isoPath.isEmpty ? "None" : (isoPath as NSString).lastPathComponent)
                        .foregroundStyle(isoPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if !isoPath.isEmpty {
                        Button(action: { isoPath = ""; checkForChanges() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Browse…") {
                        selectFile(for: .iso)
                    }
                }
            }
        }
    }

    // MARK: - Config Info Section

    private var configInfoSection: some View {
        ConfigSection(title: "Configuration File", icon: "doc.text") {
            if let configPath = vm.configPath {
                ConfigRow(label: "Location") {
                    HStack {
                        Text(configPath.lastPathComponent)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }

            if let modified = vm.lastModified {
                ConfigRow(label: "Last Modified") {
                    Text(modified, format: .dateTime.month().day().year().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var iconBackgroundColor: Color {
        switch guestOS {
        case .windows: return .blue
        case .macos: return .primary
        case .linux: return .orange
        }
    }

    private func loadFromVM() {
        name = vm.name
        guestOS = vm.guestOS
        architecture = vm.architecture
        memoryMB = vm.memoryMB
        cpuCores = vm.cpuCores
        diskImagePath = vm.diskImagePath
        isoPath = vm.isoPath ?? ""
        displayMode = vm.displayMode
        hasChanges = false
    }

    private func checkForChanges() {
        hasChanges = name != vm.name ||
            guestOS != vm.guestOS ||
            architecture != vm.architecture ||
            memoryMB != vm.memoryMB ||
            cpuCores != vm.cpuCores ||
            diskImagePath != vm.diskImagePath ||
            isoPath != (vm.isoPath ?? "") ||
            displayMode != vm.displayMode
    }

    private func save() {
        var updatedVM = vm
        updatedVM.name = name
        updatedVM.guestOS = guestOS
        updatedVM.architecture = architecture
        updatedVM.memoryMB = memoryMB
        updatedVM.cpuCores = cpuCores
        updatedVM.diskImagePath = diskImagePath
        updatedVM.isoPath = isoPath.isEmpty ? nil : isoPath
        updatedVM.displayMode = displayMode

        vmManager.update(updatedVM)
        hasChanges = false

        // Update selection to reflect changes
        vmManager.selectedVM = updatedVM
    }

    private enum FileType {
        case disk, iso
    }

    private func selectFile(for type: FileType) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        switch type {
        case .disk:
            panel.title = "Select Disk Image"
            panel.allowedContentTypes = ["qcow2", "raw", "vmdk", "vdi", "img"].compactMap { UTType(filenameExtension: $0) }
        case .iso:
            panel.title = "Select ISO Image"
            panel.allowedContentTypes = ["iso", "img"].compactMap { UTType(filenameExtension: $0) }
        }

        if panel.runModal() == .OK, let url = panel.url {
            switch type {
            case .disk:
                diskImagePath = url.path
            case .iso:
                isoPath = url.path
            }
            checkForChanges()
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

// MARK: - Config Section Component

struct ConfigSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Config Row Component

struct ConfigRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
