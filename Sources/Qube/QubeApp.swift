import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force activation
        NSApp.activate(ignoringOtherApps: true)

        // Make sure we're the active app
        NSApp.setActivationPolicy(.regular)

        // Bring all windows to front
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure windows are key when we become active
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}

@main
struct QubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vmManager = VMManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vmManager)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
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
