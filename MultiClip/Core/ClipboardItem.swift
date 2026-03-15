import Foundation
import AppKit
import UniformTypeIdentifiers

struct ClipboardItem: Identifiable, Equatable, Codable {
    // Custom Equatable — excludes transient imageData to avoid expensive byte comparisons
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id && lhs.isPinned == rhs.isPinned && lhs.imageFilename == rhs.imageFilename
    }

    let id: UUID
    let contentType: ContentType
    let sourceAppBundleID: String?
    let copiedAt: Date
    let changeCount: Int
    var isPinned: Bool = false

    // Content storage — only the relevant one is populated
    var textContent: String?
    var imageFilename: String?   // Filename in images/ directory (persistence)
    var fileURLs: [URL]?

    // Transient — not persisted
    var imageData: Data?

    enum ContentType: String, Codable, CaseIterable {
        case text
        case code
        case url
        case image
        case file
        case richText

        var sfSymbolName: String {
            switch self {
            case .text:     return "doc.plaintext"
            case .code:     return "chevron.left.slash.chevron.right"
            case .url:      return "link"
            case .image:    return "photo"
            case .file:     return "folder"
            case .richText: return "doc.richtext"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, contentType, sourceAppBundleID, copiedAt, changeCount, isPinned
        case textContent, imageFilename, fileURLs
    }

    // MARK: - Computed display helpers

    var previewText: String {
        switch contentType {
        case .text, .code, .url, .richText:
            guard let text = textContent else { return "" }
            let lines = text.components(separatedBy: .newlines)
            var preview = lines.prefix(3).joined(separator: "\n")
            if preview.count > 200 {
                preview = String(preview.prefix(200))
            }
            if lines.count > 3 || text.count > 200 {
                return preview + "…"
            }
            return preview
        case .image:
            if let data = imageData, let image = NSImage(data: data) {
                let w = Int(image.size.width)
                let h = Int(image.size.height)
                return "\(w)×\(h)"
            }
            return "Image"
        case .file:
            guard let urls = fileURLs else { return "File" }
            if urls.count == 1 {
                return urls[0].lastPathComponent
            }
            return "\(urls.count) files"
        }
    }

    var detailLabel: String {
        switch contentType {
        case .text, .code, .url, .richText:
            return "\(textContent?.count ?? 0) chars"
        case .image:
            if let data = imageData {
                return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            }
            return "Image"
        case .file:
            guard let urls = fileURLs else { return "" }
            if urls.count == 1 {
                return fileSize(at: urls[0])
            }
            return "\(urls.count) files"
        }
    }

    /// Unique content key for deduplication (deterministic across process launches)
    var contentKey: String {
        switch contentType {
        case .text, .code, .url, .richText:
            return textContent ?? ""
        case .image:
            if let data = imageData {
                return "img:\(data.count):\(data.prefix(32).base64EncodedString())"
            }
            if let filename = imageFilename {
                return "img:file:\(filename)"
            }
            return "img:\(id.uuidString)"
        case .file:
            return fileURLs?.map(\.absoluteString).joined(separator: ",") ?? ""
        }
    }

    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var filesExist: Bool {
        guard contentType == .file, let urls = fileURLs else { return true }
        return urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    func isExpired(interval: TimeInterval) -> Bool {
        if isPinned { return false }
        guard interval > 0 else { return false } // "Never" = 0
        return Date().timeIntervalSince(copiedAt) > interval
    }

    // MARK: - Factory

    static func from(pasteboard: NSPasteboard) -> ClipboardItem? {
        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let changeCount = pasteboard.changeCount

        // Check for files first (highest priority)
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            return ClipboardItem(
                id: UUID(),
                contentType: .file,
                sourceAppBundleID: sourceApp,
                copiedAt: Date(),
                changeCount: changeCount,
                fileURLs: fileURLs
            )
        }

        // Check for image data
        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            guard let tiffRep = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffRep),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }

            let finalData: Data
            if pngData.count > 10_000_000 {
                if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    finalData = jpegData
                } else {
                    finalData = pngData
                }
            } else {
                finalData = pngData
            }

            return ClipboardItem(
                id: UUID(),
                contentType: .image,
                sourceAppBundleID: sourceApp,
                copiedAt: Date(),
                changeCount: changeCount,
                imageData: finalData
            )
        }

        // Check for text
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Truncate very large text
            let text = string.count > 50_000 ? String(string.prefix(50_000)) : string

            // Detect rich text (RTF/HTML on pasteboard alongside plain text)
            let hasRTF = pasteboard.data(forType: .rtf) != nil || pasteboard.data(forType: .html) != nil
            let textType: ContentType = hasRTF ? .richText : classifyText(text)
            return ClipboardItem(
                id: UUID(),
                contentType: textType,
                sourceAppBundleID: sourceApp,
                copiedAt: Date(),
                changeCount: changeCount,
                textContent: text
            )
        }

        return nil
    }

    private static func classifyText(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmed), let scheme = url.scheme,
           ["http", "https", "ftp", "ssh"].contains(scheme) {
            return .url
        }

        let codeIndicators = ["{", "}", "func ", "let ", "var ", "import ", "class ", "->", "//", "/*", "def ", "return "]
        let matchCount = codeIndicators.filter { trimmed.contains($0) }.count
        if matchCount >= 2 {
            return .code
        }

        return .text
    }

    private func fileSize(at url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
