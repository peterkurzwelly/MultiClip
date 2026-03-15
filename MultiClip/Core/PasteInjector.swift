import AppKit
import CoreGraphics

@MainActor
enum PasteInjector {

    /// Writes a ClipboardItem to the system pasteboard and simulates ⌘V.
    @discardableResult
    static func pasteItem(_ item: ClipboardItem) -> Bool {
        writeToPasteboard(items: [item])

        guard AXIsProcessTrusted() else {
            return false
        }

        return simulatePaste()
    }

    /// Writes multiple items to pasteboard and simulates ⌘V.
    /// Text items are concatenated with newlines. Files are combined.
    /// Images paste the first one (pasteboard supports one image at a time).
    @discardableResult
    static func pasteItems(_ items: [ClipboardItem]) -> Bool {
        guard !items.isEmpty else { return false }

        writeToPasteboard(items: items)

        guard AXIsProcessTrusted() else {
            return false
        }

        return simulatePaste()
    }

    private static func writeToPasteboard(items: [ClipboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Collect all content by type
        var texts: [String] = []
        var fileURLs: [URL] = []
        var firstImageData: Data?

        for item in items {
            switch item.contentType {
            case .text, .code, .url, .richText:
                if let text = item.textContent {
                    texts.append(text)
                }
            case .image:
                if firstImageData == nil {
                    firstImageData = item.imageData
                }
            case .file:
                if let urls = item.fileURLs {
                    fileURLs.append(contentsOf: urls)
                }
            }
        }

        // Write to pasteboard — prioritize by what we have
        if !fileURLs.isEmpty {
            pasteboard.writeObjects(fileURLs as [NSURL])
        }

        if let imageData = firstImageData {
            pasteboard.setData(imageData, forType: .png)
            if let image = NSImage(data: imageData), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }

        if !texts.isEmpty {
            let combined = texts.joined(separator: "\n")
            pasteboard.setString(combined, forType: .string)
        }
    }

    private static func simulatePaste() -> Bool {
        let vKeyCode: CGKeyCode = 0x09

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)

        guard let keyDown, let keyUp else {
            return false
        }

        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand

        keyDown.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)

        return true
    }
}
