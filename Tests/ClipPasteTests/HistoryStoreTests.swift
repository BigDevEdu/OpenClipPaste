import Testing
import AppKit
@testable import ClipPaste

@MainActor
struct HistoryStoreTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipPasteTests-\(UUID().uuidString)")

    @Test func dedupeMovesToTop() {
        let s = HistoryStore(directory: dir)
        s.add(.text("a")); s.add(.text("b")); s.add(.text("a"))
        #expect(s.items.map(\.text) == ["a", "b"])
    }

    @Test func limitRemovesExcessAndBlobs() throws {
        let s = HistoryStore(directory: dir)
        let png = Data([1, 2, 3])
        let img = ClipItem.image(png: png, width: 1, height: 1)
        s.add(img, pngData: png)
        let blob = try #require(s.blobURL(for: img))
        #expect(FileManager.default.fileExists(atPath: blob.path))
        for i in 0..<HistoryStore.maxItems { s.add(.text("t\(i)")) }
        #expect(s.items.count == HistoryStore.maxItems)
        #expect(!s.items.contains { $0.id == img.id })
        #expect(!FileManager.default.fileExists(atPath: blob.path))
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func roundTrip() {
        let s = HistoryStore(directory: dir)
        s.add(.text("x", source: "com.apple.Notes")); s.add(.text("y"))
        #expect(HistoryStore(directory: dir).items == s.items)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func corruptedJSONStartsEmpty() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: dir.appendingPathComponent("index.json"))
        #expect(HistoryStore(directory: dir).items.isEmpty)
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func classify() {
        let c = ClipboardMonitor.classify
        #expect(c([.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]) == nil)
        #expect(c([.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")]) == nil)
        #expect(c([.fileURL, .tiff]) == nil)
        #expect(c([.png]) == .image)
        #expect(c([.tiff, .string]) == .image)
        #expect(c([.string]) == .text)
        #expect(c([]) == nil)
    }
}

@MainActor
struct PinTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ClipPasteTests-\(UUID().uuidString)")

    @Test func pinnedSurvivesLimitAndClear() {
        let s = HistoryStore(directory: dir)
        s.add(.text("fixo"))
        s.togglePin(s.items[0].id)
        for i in 0..<HistoryStore.maxItems + 5 { s.add(.text("t\(i)")) }
        #expect(s.items.contains { $0.text == "fixo" && $0.isPinned })
        #expect(s.items.count == HistoryStore.maxItems + 1)
        s.add(.text("fixo")) // dedupe mantém fixado
        #expect(s.items.filter { $0.text == "fixo" }.count == 1 && s.items[0].isPinned)
        s.clear()
        #expect(s.items.map(\.text) == ["fixo"])
        #expect(HistoryStore(directory: dir).items.map(\.isPinned) == [true])
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func oldJSONWithoutPinnedLoads() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = #"[{"id":"\#(UUID().uuidString)","kind":"text","createdAt":0,"text":"a","hash":"h"}]"#
        try Data(json.utf8).write(to: dir.appendingPathComponent("index.json"))
        let items = HistoryStore(directory: dir).items
        #expect(items.count == 1 && !items[0].isPinned)
        try? FileManager.default.removeItem(at: dir)
    }
}
