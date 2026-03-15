import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []

    private let storageDir: URL
    private let historyFile: URL
    private let imagesDir: URL
    private var pruneTimer: Timer?

    var unpinnedItems: [ClipboardItem] { items.filter { !$0.isPinned } }
    var pinnedItems: [ClipboardItem] { items.filter { $0.isPinned } }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("MultiClip", isDirectory: true)
        historyFile = storageDir.appendingPathComponent("history.json")
        imagesDir = storageDir.appendingPathComponent("images", isDirectory: true)

        // Create directories
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Load from disk
        loadFromDisk()

        // Start prune timer (every 60 seconds)
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pruneExpired()
            }
        }
    }

    // MARK: - Public API

    func add(_ item: ClipboardItem) {
        // Deduplicate
        items.removeAll { $0.contentKey == item.contentKey }

        // Save image data to disk if needed
        var newItem = item
        if item.contentType == .image, let data = item.imageData {
            let filename = "\(item.id.uuidString).png"
            let fileURL = imagesDir.appendingPathComponent(filename)
            try? data.write(to: fileURL)
            newItem.imageFilename = filename
        }

        items.insert(newItem, at: 0)

        // Cap unpinned items
        enforceCapacity()

        saveToDisk()
    }

    func remove(_ item: ClipboardItem) {
        // Delete image file if exists
        deleteImageFile(for: item)
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    func clear() {
        // Delete entire images directory and recreate (catches orphans too)
        try? FileManager.default.removeItem(at: imagesDir)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        items.removeAll()
        saveToDisk()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        enforceCapacity()
        saveToDisk()
    }

    func item(at index: Int) -> ClipboardItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    // MARK: - Persistence

    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: historyFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var loaded = try? decoder.decode([ClipboardItem].self, from: data) else { return }

        // Rehydrate image data from disk
        for i in loaded.indices {
            if loaded[i].contentType == .image, let filename = loaded[i].imageFilename {
                let fileURL = imagesDir.appendingPathComponent(filename)
                loaded[i].imageData = try? Data(contentsOf: fileURL)
            }
        }

        // Prune expired unpinned items and delete their image files
        let interval = Settings.shared.autoClearInterval
        let expired = loaded.filter { $0.isExpired(interval: interval) }
        for item in expired {
            deleteImageFile(for: item)
        }
        loaded.removeAll { $0.isExpired(interval: interval) }

        // Remove image items whose files are missing from disk
        loaded.removeAll { item in
            item.contentType == .image && item.imageFilename != nil && item.imageData == nil
        }

        items = loaded
    }

    private func enforceCapacity() {
        let maxUnpinned = Settings.shared.historySize
        let unpinned = items.filter { !$0.isPinned }

        guard unpinned.count > maxUnpinned else { return }

        // Remove oldest unpinned items (they appear later in the array)
        let overflow = unpinned.suffix(from: maxUnpinned)
        let overflowIDs = Set(overflow.map(\.id))
        for item in overflow {
            deleteImageFile(for: item)
        }
        items.removeAll { overflowIDs.contains($0.id) }
    }

    private func pruneExpired() {
        let interval = Settings.shared.autoClearInterval
        let expired = items.filter { $0.isExpired(interval: interval) }
        guard !expired.isEmpty else { return }
        let expiredIDs = Set(expired.map(\.id))
        for item in expired {
            deleteImageFile(for: item)
        }
        items.removeAll { expiredIDs.contains($0.id) }
        saveToDisk()
    }

    private func deleteImageFile(for item: ClipboardItem) {
        guard let filename = item.imageFilename else { return }
        let fileURL = imagesDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
