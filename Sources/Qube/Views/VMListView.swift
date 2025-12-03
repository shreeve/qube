import SwiftUI

struct VMListView: View {
    @EnvironmentObject var vmManager: VMManager
    @State private var hoveredVM: UUID?

    var body: some View {
        List(vmManager.virtualMachines, selection: $vmManager.selectedVM) { vm in
            VMRowView(vm: vm, isHovered: hoveredVM == vm.id)
                .tag(vm)
                .onHover { hovering in
                    hoveredVM = hovering ? vm.id : nil
                }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { vmManager.showingNewVM = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationTitle("Qube")
        .contextMenu(forSelectionType: VirtualMachine.self) { vms in
            if let vm = vms.first {
                Button(action: { toggleRun(vm) }) {
                    Label(
                        vmManager.isRunning(vm) ? "Stop" : "Start",
                        systemImage: vmManager.isRunning(vm) ? "stop.fill" : "play.fill"
                    )
                }
                Divider()
                Button(role: .destructive, action: { vmManager.delete(vm) }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func toggleRun(_ vm: VirtualMachine) {
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

struct VMRowView: View {
    let vm: VirtualMachine
    let isHovered: Bool
    @EnvironmentObject var vmManager: VMManager
    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(spacing: 10) {
            // Guest OS icon
            Image(systemName: vm.guestOS.iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            // VM info
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(vm.guestOS.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let modified = vm.lastModified {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(modified, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Status / Action button
            if vmManager.isRunning(vm) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        if vmManager.isRunning(vm) {
            return .green
        }
        switch vm.guestOS {
        case .windows: return .blue
        case .macos: return .primary
        case .linux: return .orange
        }
    }
}
