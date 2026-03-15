import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var clipboardStore: ClipboardStore!
    private(set) var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!
    private(set) var overlayController: OverlayController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Check accessibility permissions
        checkAccessibilityPermissions()

        // 2. Initialize core services
        clipboardStore = ClipboardStore()
        clipboardMonitor = ClipboardMonitor(store: clipboardStore)

        // 3. Create overlay controller
        overlayController = OverlayController(store: clipboardStore, monitor: clipboardMonitor)

        // 4. Register global hotkey (⌥⌘V)
        hotKeyManager = HotKeyManager { [weak self] in
            self?.overlayController.toggle()
        }

        // 5. Start clipboard monitoring
        clipboardMonitor.startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopPolling()
    }

    private nonisolated func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }
}
