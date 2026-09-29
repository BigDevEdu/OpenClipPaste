import AppKit
import SwiftUI

@main
struct ClipPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var panel: PanelController!
    private var hotKey: HotKey!
    private var statusItem: NSStatusItem!
    private var openItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipPaste")
        store = HistoryStore(directory: dir)
        monitor = ClipboardMonitor(store: store)
        monitor.start()
        panel = PanelController(store: store)
        hotKey = HotKey()
        hotKey.onPress = { [weak self] in self?.panel.toggle() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipPaste")
        let menu = NSMenu()
        menu.delegate = self
        openItem = menu.addItem(withTitle: "Abrir", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Mudar atalho…", action: #selector(changeShortcut), keyEquivalent: "")
        menu.addItem(withTitle: "Limpar histórico", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for i in menu.items where i.action != #selector(NSApplication.terminate(_:)) { i.target = self }
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) { openItem.title = "Abrir (\(hotKey.display))" }

    @objc private func openPanel() { panel.toggle() }
    @objc private func changeShortcut() { hotKey.promptForNewShortcut() }
    @objc private func clearHistory() { store.clear() }
}
