import Foundation
import Observation

@Observable @MainActor
final class HistoryStore {
    static let maxItems = 200

    private(set) var items: [ClipItem] = []
    let directory: URL
    var blobsDir: URL { directory.appendingPathComponent("blobs") }
    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let loaded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = loaded
        } // JSON ausente ou corrompido → começa vazio
    }

    func blobURL(for item: ClipItem) -> URL? {
        item.imageFile.map { blobsDir.appendingPathComponent($0) }
    }

    /// `pngData` é gravado em blobs/ só se o item não for duplicata.
    func add(_ item: ClipItem, pngData: Data? = nil) {
        if let idx = items.firstIndex(where: { $0.hash == item.hash }) {
            var old = items.remove(at: idx)
            old.createdAt = Date()
            old.sourceBundleID = item.sourceBundleID
            items.insert(old, at: 0)
        } else {
            if let pngData, let url = blobURL(for: item) { try? pngData.write(to: url, options: .atomic) }
            items.insert(item, at: 0)
        }
        // Fixados não contam para o limite.
        while items.count(where: { !$0.isPinned }) > Self.maxItems,
              let idx = items.lastIndex(where: { !$0.isPinned }) {
            deleteBlob(of: items.remove(at: idx))
        }
        save()
    }

    func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned = !items[idx].isPinned
        save()
    }

    /// Apaga só os não fixados.
    func clear() {
        items.filter { !$0.isPinned }.forEach(deleteBlob)
        items.removeAll { !$0.isPinned }
        save()
    }

    private func deleteBlob(of item: ClipItem) {
        if let url = blobURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: indexURL, options: .atomic) }
    }
}
