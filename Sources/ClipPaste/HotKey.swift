import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKey {
    static var shared: HotKey?

    var onPress: (() -> Void)?
    private(set) var keyCode: UInt32
    private(set) var modifiers: UInt32
    private(set) var label: String   // tecla para exibição, ex.: "V"
    private var ref: EventHotKeyRef?

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "hotKeyCode") != nil {
            keyCode = UInt32(d.integer(forKey: "hotKeyCode"))
            modifiers = UInt32(d.integer(forKey: "hotKeyModifiers"))
            label = d.string(forKey: "hotKeyLabel") ?? "?"
        } else {
            keyCode = UInt32(kVK_ANSI_V)
            modifiers = UInt32(cmdKey | shiftKey)
            label = "V"
        }
        HotKey.shared = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.shared?.onPress?() }  // Carbon chama na main thread
            return noErr
        }, 1, &spec, nil, nil)
        _ = register(keyCode, modifiers)
    }

    /// Ex.: "⇧⌘V"
    var display: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") + (modifiers & UInt32(optionKey) != 0 ? "⌥" : "")
            + (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") + (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + label
    }

    private func register(_ code: UInt32, _ mods: UInt32) -> Bool {
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x434C5054, id: 1)
        let status = RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &newRef)
        if status == noErr { ref = newRef }
        return status == noErr
    }

    func update(keyCode: UInt32, modifiers: UInt32, label: String) -> Bool {
        let oldRef = ref
        ref = nil
        guard register(keyCode, modifiers) else { ref = oldRef; return false }
        if let oldRef { UnregisterEventHotKey(oldRef) }
        self.keyCode = keyCode; self.modifiers = modifiers; self.label = label
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: "hotKeyCode")
        d.set(Int(modifiers), forKey: "hotKeyModifiers")
        d.set(label, forKey: "hotKeyLabel")
        return true
    }

    static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var m = 0
        if f.contains(.command) { m |= cmdKey }
        if f.contains(.shift) { m |= shiftKey }
        if f.contains(.option) { m |= optionKey }
        if f.contains(.control) { m |= controlKey }
        return UInt32(m)
    }

    /// Janelinha que captura o próximo atalho (exige ⌘, ⌥ ou ⌃). Esc cancela.
    func promptForNewShortcut() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Mudar atalho"
        alert.informativeText = "Pressione a nova combinação de teclas (com ⌘, ⌥ ou ⌃). Esc cancela."
        alert.addButton(withTitle: "Cancelar")
        var captured: (UInt32, UInt32, String)?
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let code = UInt32(e.keyCode)
            let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = (e.charactersIgnoringModifiers ?? "?").uppercased()
            if code == 53 { return e }  // Esc: deixa o botão Cancelar tratar
            MainActor.assumeIsolated {
                if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
                    captured = (code, HotKey.carbonModifiers(flags), key)
                    NSApp.stopModal()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
        alert.runModal()
        if let monitor { NSEvent.removeMonitor(monitor) }
        guard let (code, mods, key) = captured else { return }
        if !update(keyCode: code, modifiers: mods, label: key) {
            let err = NSAlert()
            err.messageText = "Não foi possível registrar o atalho"
            err.informativeText = "A combinação já está em uso por outro app ou pelo sistema. O atalho anterior foi mantido."
            err.runModal()
        }
    }
}
