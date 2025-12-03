import SwiftUI

struct VMListView: View {
    @EnvironmentObject var vmManager: VMManager

    var body: some View {
        List(vmManager.virtualMachines, selection: $vmManager.selectedVM) { vm in
            VMRowView(vm: vm)
                .tag(vm)
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
    }
}

struct VMRowView: View {
    let vm: VirtualMachine
    @EnvironmentObject var vmManager: VMManager

    var body: some View {
        HStack {
            Image(systemName: vmManager.isRunning(vm) ? "play.circle.fill" : "desktopcomputer")
                .foregroundStyle(vmManager.isRunning(vm) ? .green : .secondary)

            VStack(alignment: .leading) {
                Text(vm.name)
                    .fontWeight(.medium)
                Text(vm.architecture.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

