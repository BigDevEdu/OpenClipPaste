import AppKit
import SwiftUI
import Observation

@Observable @MainActor
final class PanelState {
    var openToken = 0   // muda a cada abertura → recria o ScrollView (volta ao início)
    var query = ""
}

final class ClipPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { orderOut(nil) } else { super.keyDown(with: event) }
    }
}

@MainActor
final class PanelController {
    private let panel: ClipPanel
    private let state = PanelState()
    private var outsideMonitor: Any?
    private var dragMonitor: Any?

    init(store: HistoryStore) {
        panel = ClipPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 300),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        let host = NSHostingView(rootView: PanelView(store: store, state: state,
                                                     onDragStart: { [weak self] in self?.watchDrag() },
                                                     onClose: { [weak self] in self?.hide() }))
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect
    }

    func toggle() { panel.isVisible ? hide() : show() }

    private func show() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        panel.setFrame(NSRect(x: vf.minX + 8, y: vf.minY + 8, width: vf.width - 16, height: 300), display: true)
        state.query = ""
        state.openToken += 1
        panel.orderFrontRegardless()
        panel.makeKey()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func hide() {
        panel.orderOut(nil)
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        if let m = dragMonitor { NSEvent.removeMonitor(m); dragMonitor = nil }
    }

    /// Ao iniciar um drag: no próximo mouse-up fora do painel (drop em outro app), fecha.
    private func watchDrag() {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let m = self.dragMonitor { NSEvent.removeMonitor(m); self.dragMonitor = nil }
                if !self.panel.frame.contains(NSEvent.mouseLocation) { self.hide() }
            }
        }
    }
}

// MARK: - SwiftUI

@MainActor
private enum Media {
    static let thumbs = NSCache<NSString, NSImage>()
    static let icons = NSCache<NSString, NSImage>()

    static func thumbnail(_ url: URL) -> NSImage? {
        if let c = thumbs.object(forKey: url.path as NSString) { return c }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 480,
              ] as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbs.setObject(img, forKey: url.path as NSString)
        return img
    }

    static func icon(_ bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let c = icons.object(forKey: bundleID as NSString) { return c }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        icons.setObject(img, forKey: bundleID as NSString)
        return img
    }
}

struct PanelView: View {
    let store: HistoryStore
    @Bindable var state: PanelState
    let onDragStart: () -> Void
    let onClose: () -> Void
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        let q = state.query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.items }
        return store.items.filter { $0.text?.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var body: some View {
        let items = filtered
        let pinned = items.filter(\.isPinned)
        let recent = items.filter { !$0.isPinned }
        VStack(spacing: 10) {
            HStack {
                Label("Área de transferência", systemImage: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.15), in: Capsule())
                Spacer()
                Text("\(store.items.count) itens").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .overlay { // busca centralizada no painel
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar", text: $state.query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onKeyPress(.escape) {
                            if state.query.isEmpty { onClose() } else { state.query = "" }
                            return .handled
                        }
                }
                .font(.system(size: 13))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(width: 320)
                .background(.white.opacity(0.1), in: Capsule())
            }
            if items.isEmpty {
                Text(store.items.isEmpty ? "Copie algo para começar" : "Nada encontrado")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(pinned.enumerated()), id: \.element.id) { i, item in
                            card(item, position: i + 1)
                        }
                        if !pinned.isEmpty && !recent.isEmpty {
                            Divider().frame(height: 200)
                        }
                        ForEach(Array(recent.enumerated()), id: \.element.id) { i, item in
                            card(item, position: pinned.count + i + 1)
                        }
                    }
                }
                .id(state.openToken)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .preferredColorScheme(.dark)
        .onAppear { searchFocused = true }
        .onChange(of: state.openToken) { searchFocused = true }
    }

    private func card(_ item: ClipItem, position: Int) -> some View {
        CardView(item: item, position: position, blobURL: store.blobURL(for: item), onDragStart: onDragStart)
            .contextMenu {
                Button(item.isPinned ? "Desafixar" : "Fixar") { store.togglePin(item.id) }
            }
    }
}

struct CardView: View {
    let item: ClipItem
    let position: Int
    let blobURL: URL?
    let onDragStart: () -> Void

    private var isText: Bool { item.kind == .text }

    var body: some View {
        VStack(spacing: 0) {
            header
            body_
            footer
        }
        .frame(width: 240, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onDrag {
            onDragStart()
            if isText { return NSItemProvider(object: (item.text ?? "") as NSString) }
            if let blobURL, let p = NSItemProvider(contentsOf: blobURL) { return p }
            if let blobURL, let img = NSImage(contentsOf: blobURL) { return NSItemProvider(object: img) }
            return NSItemProvider()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(isText ? "Texto" : "Imagem").font(.system(size: 15, weight: .bold))
                    if item.isPinned { Image(systemName: "pin.fill").font(.system(size: 11)) }
                }
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(Self.relative.localizedString(for: item.createdAt, relativeTo: Date()))
                        .font(.system(size: 11)).opacity(0.85)
                }
            }
            Spacer()
            if let icon = Media.icon(item.sourceBundleID) {
                Image(nsImage: icon).resizable().frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(isText ? Color.blue : Color.purple)
    }

    private var body_: some View {
        ZStack {
            Color(white: 0.12)
            if isText {
                Text(item.text ?? "")
                    .font(.system(size: 12)).foregroundStyle(.white)
                    .lineLimit(8).multilineTextAlignment(.leading)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Checkerboard()
                if let blobURL, let img = Media.thumbnail(blobURL) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).padding(6)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(isText ? "\(item.text?.count ?? 0) caracteres" : "\(item.imageWidth ?? 0) × \(item.imageHeight ?? 0)")
            Spacer()
            Text("\(position)")
        }
        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 12).frame(height: 28)
        .background(Color(white: 0.16))
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.unitsStyle = .full
        return f
    }()
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 8
            for y in 0..<Int(size.height / s) + 1 {
                for x in 0..<Int(size.width / s) + 1 where (x + y) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * s, y: CGFloat(y) * s, width: s, height: s)),
                             with: .color(.white.opacity(0.08)))
                }
            }
        }
    }
}
