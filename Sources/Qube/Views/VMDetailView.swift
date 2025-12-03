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
    @State private var showingDiskPicker = false

    // Snapshots
    @State private var snapshots: [Snapshot] = []
    @State private var showingCreateSnapshot = false
    @State private var newSnapshotName = ""
    @State private var snapshotToDelete: Snapshot?
    @State private var snapshotToStart: Snapshot?
    @State private var snapshotToClone: Snapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with icon and name
                headerSection

                Divider()
                    .padding(.horizontal)

                // Configuration sections
                VStack(spacing: 24) {
                    // System and Hardware side by side (responsive)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 24) {
                            systemSection
                                .frame(maxWidth: .infinity, alignment: .leading)
                            hardwareSection
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 24) {
                            systemSection
                            hardwareSection
                        }
                    }

                    storageSection
                    snapshotsSection
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
                        .disabled(!canSave)
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
        .sheet(isPresented: $showingDiskPicker) {
            DiskPickerView(vmName: name, currentPath: diskImagePath) { path in
                diskImagePath = path
                checkForChanges()
            }
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

                    Text(architecture.displayName)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                // Validation message
                if let validationError = validationError {
                    Text(validationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Config file info (top right, subtle)
            if let configPath = vm.configPath {
                VStack(alignment: .trailing, spacing: 4) {
                    Button(action: {
                        NSWorkspace.shared.selectFile(configPath.path, inFileViewerRootedAtPath: "")
                    }) {
                        HStack(spacing: 4) {
                            Text(configPath.lastPathComponent)
                                .font(.caption)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")

                    if let modified = vm.lastModified {
                        Text(modified, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
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
                        Text(arch.displayName).tag(arch)
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
                        Text(mode.displayName).tag(mode)
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

                    Button(diskImagePath.isEmpty ? "Select…" : "Change…") {
                        showingDiskPicker = true
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

    // MARK: - Snapshots Section

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Snapshots", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(.primary)

            // Content
            VStack(spacing: 0) {
                // Top row with status/create button
                HStack {
                    if diskImagePath.isEmpty {
                        Text("Select a disk image first")
                            .foregroundStyle(.secondary)
                    } else if snapshots.isEmpty {
                        Text("No snapshots")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(snapshots.count) snapshot\(snapshots.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !diskImagePath.isEmpty {
                        Button("Create…") {
                            newSnapshotName = "Snapshot \(snapshots.count + 1)"
                            showingCreateSnapshot = true
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if !diskImagePath.isEmpty && !snapshots.isEmpty {
                    Divider()
                    // Table header
                    HStack(spacing: 0) {
                        Text("#")
                            .frame(width: 30, alignment: .center)
                        Text("Name")
                            .frame(minWidth: 80, alignment: .leading)
                        Spacer()
                        Text("Created")
                            .frame(width: 130, alignment: .leading)
                        Text("Size")
                            .frame(width: 60, alignment: .trailing)
                        Text("Actions")
                            .frame(width: 110, alignment: .center)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .separatorColor).opacity(0.2))

                    // Snapshot rows
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Divider()
                            }

                            HStack(spacing: 0) {
                                Text("\(index + 1)")
                                    .frame(width: 30, alignment: .center)
                                    .foregroundStyle(.tertiary)
                                    .font(.caption.monospacedDigit())

                                Text(snapshot.name)
                                    .frame(minWidth: 80, alignment: .leading)
                                    .lineLimit(1)

                                Spacer()

                                if let date = snapshot.date {
                                    Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                        .frame(width: 130, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                } else {
                                    Text("—")
                                        .frame(width: 130, alignment: .leading)
                                        .foregroundStyle(.tertiary)
                                }

                                Text(snapshot.vmSize ?? "—")
                                    .frame(width: 60, alignment: .trailing)
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)

                                HStack(spacing: 12) {
                                    Button {
                                        snapshotToStart = snapshot
                                    } label: {
                                        Image(systemName: "play.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Start from this snapshot")

                                    Button {
                                        snapshotToClone = snapshot
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Clone this snapshot")

                                    Button {
                                        snapshotToDelete = snapshot
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.red)
                                    .help("Delete this snapshot")
                                }
                                .frame(width: 110, alignment: .center)
                            }
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onAppear { loadSnapshots() }
        .onChange(of: diskImagePath) { _, _ in loadSnapshots() }
        .alert(vmManager.isRunning(vm) ? "Create Live Snapshot" : "Create Snapshot", isPresented: $showingCreateSnapshot) {
            TextField("Name", text: $newSnapshotName)
            Button("Cancel", role: .cancel) { }
            Button("Create") { createSnapshot() }
        } message: {
            if vmManager.isRunning(vm) {
                Text("This will briefly pause the VM to capture memory + disk state. You can resume exactly where you left off!")
            } else {
                Text("This will save the current disk state.")
            }
        }
        .alert("Start from Snapshot?", isPresented: .init(
            get: { snapshotToStart != nil },
            set: { if !$0 { snapshotToStart = nil } }
        )) {
            Button("Cancel", role: .cancel) { snapshotToStart = nil }
            Button("Start") {
                if let snapshot = snapshotToStart {
                    startFromSnapshot(snapshot)
                }
            }
        } message: {
            if let snapshot = snapshotToStart {
                Text("Restore \"\(snapshot.name)\" and start the VM?")
            }
        }
        .alert("Clone Snapshot?", isPresented: .init(
            get: { snapshotToClone != nil },
            set: { if !$0 { snapshotToClone = nil } }
        )) {
            Button("Cancel", role: .cancel) { snapshotToClone = nil }
            Button("Clone") {
                if let snapshot = snapshotToClone {
                    cloneSnapshot(snapshot)
                }
            }
        } message: {
            if let snapshot = snapshotToClone {
                Text("Create a copy of \"\(snapshot.name)\"?")
            }
        }
        .alert("Delete Snapshot?", isPresented: .init(
            get: { snapshotToDelete != nil },
            set: { if !$0 { snapshotToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { snapshotToDelete = nil }
            Button("Delete", role: .destructive) {
                if let snapshot = snapshotToDelete {
                    deleteSnapshot(snapshot)
                }
            }
        } message: {
            if let snapshot = snapshotToDelete {
                Text("Delete \"\(snapshot.name)\"? This cannot be undone.")
            }
        }
    }

    private func loadSnapshots() {
        guard !diskImagePath.isEmpty else {
            snapshots = []
            return
        }

        // Check if VM is running (either tracked by manager OR socket exists)
        let socketPath = QEMUService.shared.monitorSocketPath(for: vm)
        let socketExists = FileManager.default.fileExists(atPath: socketPath)

        if vmManager.isRunning(vm) || socketExists {
            // Use QEMU monitor when VM is running
            snapshots = QEMUService.shared.listSnapshots(vm)
        } else {
            // Use qemu-img when VM is stopped
            snapshots = SnapshotService.shared.list(diskPath: diskImagePath)
        }
    }

    private func createSnapshot() {
        guard !diskImagePath.isEmpty, !newSnapshotName.isEmpty else { return }

        if vmManager.isRunning(vm) {
            // Live snapshot - captures RAM + disk state!
            // Pause briefly for consistency
            _ = QEMUService.shared.pause(vm)

            // Save the snapshot (includes memory state)
            let success = QEMUService.shared.saveSnapshot(vm, name: newSnapshotName)

            // Resume immediately
            _ = QEMUService.shared.resume(vm)

            if success {
                // Give QEMU a moment to write the snapshot, then refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadSnapshots()
                }
            }
        } else {
            // Offline snapshot - disk state only
            if SnapshotService.shared.create(diskPath: diskImagePath, name: newSnapshotName) {
                loadSnapshots()
            }
        }
        newSnapshotName = ""
    }

    private func startFromSnapshot(_ snapshot: Snapshot) {
        guard !diskImagePath.isEmpty else { return }
        // First restore the snapshot
        if SnapshotService.shared.restore(diskPath: diskImagePath, name: snapshot.name) {
            loadSnapshots()
            // Then start the VM
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
        snapshotToStart = nil
    }

    private func cloneSnapshot(_ snapshot: Snapshot) {
        guard !diskImagePath.isEmpty else { return }
        // Restore the snapshot first, then create a new one
        if SnapshotService.shared.restore(diskPath: diskImagePath, name: snapshot.name) {
            let newName = "\(snapshot.name) copy"
            _ = SnapshotService.shared.create(diskPath: diskImagePath, name: newName)
            loadSnapshots()
        }
        snapshotToClone = nil
    }

    private func deleteSnapshot(_ snapshot: Snapshot) {
        guard !diskImagePath.isEmpty else { return }

        var success = false
        if vmManager.isRunning(vm) {
            // Live delete via QEMU monitor
            success = QEMUService.shared.deleteSnapshot(vm, name: snapshot.name)
        } else {
            // Offline delete via qemu-img
            success = SnapshotService.shared.delete(diskPath: diskImagePath, name: snapshot.name)
        }

        if success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                loadSnapshots()
            }
        }
        snapshotToDelete = nil
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

    private var canSave: Bool {
        validationError == nil
    }

    private var validationError: String? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Name is required
        if trimmedName.isEmpty {
            return "Name is required"
        }

        // Name must be unique (except for this VM)
        let isDuplicate = vmManager.virtualMachines.contains { otherVM in
            otherVM.name.lowercased() == trimmedName.lowercased() && otherVM.id != vm.id
        }
        if isDuplicate {
            return "A VM with this name already exists"
        }

        return nil
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
