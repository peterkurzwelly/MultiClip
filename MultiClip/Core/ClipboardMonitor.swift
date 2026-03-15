import AppKit

@MainActor
@Observable
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int
    private var pendingChange: Task<Void, Never>?

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// Call after writing to the pasteboard (e.g. paste injection)
    /// so the monitor doesn't re-capture what we just pasted.
    func syncChangeCount() {
        pendingChange?.cancel()
        pendingChange = nil
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        pendingChange?.cancel()
        pendingChange = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            if let item = ClipboardItem.from(pasteboard: NSPasteboard.general) {
                self.store.add(item)
            }
        }
    }
}
