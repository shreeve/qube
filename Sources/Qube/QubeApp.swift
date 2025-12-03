import SwiftUI

@main
struct QubeApp: App {
    @StateObject private var vmManager = VMManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vmManager)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Virtual Machine...") {
                    vmManager.showingNewVM = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

