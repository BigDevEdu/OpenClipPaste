import AppKit
import ServiceManagement

/// Controla se o ClipPaste abre sozinho ao iniciar a sessão (ligar/reiniciar o Mac).
///
/// Usa `SMAppService.mainApp` (macOS 13+), que registra o próprio app como item de início
/// sem helper nem permissão extra; o sistema só mostra uma notificação informando que o
/// item foi adicionado. Só funciona com o app empacotado (`ClipPaste.app`), não via `swift run`.
@MainActor
enum LaunchAtLogin {
    private static var service: SMAppService { .mainApp }

    /// `true` se o app está registrado para abrir ao iniciar a sessão.
    static var isEnabled: Bool { service.status == .enabled }

    /// `true` se o registro existe mas o usuário desativou o item nos Ajustes do Sistema.
    static var requiresApproval: Bool { service.status == .requiresApproval }

    /// Liga/desliga a abertura ao iniciar a sessão, mostrando um alerta em caso de erro.
    static func toggle() {
        if requiresApproval {
            // Já registrado, mas desativado pelo usuário: só ele pode reativar nos Ajustes.
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if isEnabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Não foi possível alterar a abertura ao iniciar sessão"
            alert.informativeText = """
                \(error.localizedDescription)

                Verifique se o ClipPaste está na pasta Aplicativos ou adicione-o manualmente em \
                Ajustes do Sistema → Geral → Itens de Início.
                """
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Abrir Ajustes")
            if alert.runModal() == .alertSecondButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
