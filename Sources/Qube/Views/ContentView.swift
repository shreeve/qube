import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vmManager: VMManager

    var body: some View {
        NavigationSplitView {
            VMListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            if let vm = vmManager.selectedVM {
                VMDetailView(vm: vm)
            } else {
                Text("Select a virtual machine")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $vmManager.showingNewVM) {
            VMFormView(vm: nil)
        }
    }
}
