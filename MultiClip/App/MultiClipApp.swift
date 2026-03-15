import SwiftUI

@main
struct MultiClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("MultiClip", systemImage: "clipboard") {
            Button("Show Clipboard History") {
                appDelegate.overlayController?.toggle()
            }
            .keyboardShortcut("v", modifiers: [.option, .command])

            Divider()

            Button("Clear History") {
                appDelegate.clipboardMonitor?.syncChangeCount()
                appDelegate.clipboardStore?.clear()
            }

            Divider()

            Button("Preferences\u{2026}") {
                openWindow(id: "preferences")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit MultiClip") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)

        Window("MultiClip Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
