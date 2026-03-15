import AppKit
import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(.body, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

@MainActor
enum ToastController {
    private static var toastWindow: NSPanel?
    private static var dismissTask: Task<Void, Never>?

    static func show(message: String, duration: TimeInterval = 2.0) {
        dismissTask?.cancel()
        dismiss()

        let toastView = ToastView(message: message)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.hidesOnDeactivate = false

        // Position at bottom center of the screen with mouse
        let mouseScreen = NSScreen.screens.first { screen in
            NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
        } ?? NSScreen.main

        if let screen = mouseScreen {
            let x = screen.frame.midX - hostingView.fittingSize.width / 2
            let y = screen.visibleFrame.minY + 80
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.alphaValue = 0
        window.orderFrontRegardless()
        toastWindow = window

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    static func dismiss() {
        guard let window = toastWindow else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: { [window] in
            Task { @MainActor in
                window.orderOut(nil)
            }
        })
        toastWindow = nil
    }
}
