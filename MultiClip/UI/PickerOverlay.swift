import AppKit
import SwiftUI

// MARK: - Custom NSPanel that doesn't steal focus

final class OverlayPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .transient]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
    }
}

// MARK: - NSHostingView that accepts first mouse click

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Overlay Controller

@MainActor
@Observable
final class OverlayController {
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    private var panel: OverlayPanel?
    private(set) var isVisible = false
    private(set) var showGeneration: Int = 0

    init(store: ClipboardStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    func setupPanel() {
        let panel = OverlayPanel()

        let rootView = OverlayRootView(store: store, controller: self) { [weak self] item in
            self?.handleItemSelected(item)
        } onMultiPaste: { [weak self] items in
            self?.handleMultiPaste(items)
        } onDismiss: { [weak self] in
            self?.hide()
        }

        let hostingView = FirstMouseHostingView(rootView: rootView)
        panel.contentView = hostingView

        self.panel = panel
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        showGeneration += 1
        if panel == nil { setupPanel() }
        guard let panel else { return }

        // Center on screen where mouse cursor is
        let mouseScreen = NSScreen.screens.first { screen in
            NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
        } ?? NSScreen.main

        if let screen = mouseScreen {
            let panelSize = NSSize(width: 760, height: 560)
            let x = screen.frame.midX - panelSize.width / 2
            let y = screen.frame.midY - panelSize.height / 2
            panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: false)
        }

        panel.ignoresMouseEvents = false
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        isVisible = true
    }

    func hide() {
        guard let panel, isVisible else { return }
        isVisible = false
        panel.ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        })
    }

    private func handleItemSelected(_ item: ClipboardItem) {
        hide()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            let success = PasteInjector.pasteItem(item)
            self?.monitor.syncChangeCount()
            SoundManager.playPasteSound()

            if !success {
                ToastController.show(message: "Copied to clipboard — paste with \u{2318}V")
            }
        }
    }

    private func handleMultiPaste(_ items: [ClipboardItem]) {
        guard !items.isEmpty else { return }
        hide()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            let success = PasteInjector.pasteItems(items)
            self?.monitor.syncChangeCount()
            SoundManager.playPasteSound()

            if !success {
                ToastController.show(message: "Copied \(items.count) items to clipboard — paste with \u{2318}V")
            }
        }
    }
}

// MARK: - Root SwiftUI view for the overlay

struct OverlayRootView: View {
    let store: ClipboardStore
    let controller: OverlayController
    let onItemSelected: (ClipboardItem) -> Void
    let onMultiPaste: ([ClipboardItem]) -> Void
    let onDismiss: () -> Void

    var body: some View {
        CardGridView(
            store: store,
            showGeneration: controller.showGeneration,
            onItemSelected: onItemSelected,
            onMultiPaste: onMultiPaste
        )
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
}
