import AppKit
@preconcurrency import HotKey

@MainActor
final class HotKeyManager {
    private var hotKey: HotKey?

    init(toggleHandler: @escaping @MainActor () -> Void) {
        // Option + Command + V
        hotKey = HotKey(key: .v, modifiers: [.option, .command])
        hotKey?.keyDownHandler = {
            Task { @MainActor in
                toggleHandler()
            }
        }
    }

    deinit {
        hotKey = nil
    }
}
