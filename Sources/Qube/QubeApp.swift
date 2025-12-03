import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set activation policy early - this is key for proper foreground behavior
        NSApp.setActivationPolicy(.regular)

        // Check for existing instance BEFORE we fully launch
        let runningApps = NSWorkspace.shared.runningApplications
        let myBundleIdentifier = Bundle.main.bundleIdentifier ?? "Qube"
        let myPID = ProcessInfo.processInfo.processIdentifier

        // Find other instances of Qube (by name since we're not a bundle)
        let existingInstances = runningApps.filter { app in
            // Match by executable name
            if let execURL = app.executableURL,
               execURL.lastPathComponent == "Qube",
               app.processIdentifier != myPID {
                return true
            }
            // Also match by bundle identifier if we ever become a proper app
            if app.bundleIdentifier == myBundleIdentifier,
               app.processIdentifier != myPID {
                return true
            }
            return false
        }

        if let existingApp = existingInstances.first {
            // Another instance is running - activate it and quit this one
            existingApp.activate()

            // Give it a moment to activate, then quit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Detach from terminal - this allows the terminal to return to prompt
        freopen("/dev/null", "r", stdin)
        freopen("/dev/null", "w", stdout)
        freopen("/dev/null", "w", stderr)

        // Force to foreground with a slight delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure windows are key when we become active
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When clicking dock icon, bring window to front
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first?.orderFrontRegardless()
                    }
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
