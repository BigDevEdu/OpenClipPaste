# ClipPaste

Histórico da área de transferência para macOS, nativo e leve. Escrito em Swift 6 com SwiftUI e AppKit.

Aperte **⇧⌘V** e um painel com os itens copiados abre na parte de baixo da tela. Arraste um card para qualquer campo de texto, documento ou app.

## Recursos

- **Texto e imagem**: guarda tudo o que você copia, com miniatura das imagens.
- **Arrastar e soltar**: o painel não rouba o foco do app em que você está, então dá para soltar o card direto no campo.
- **Busca**: filtra os textos do histórico, sem diferenciar maiúsculas nem acentos.
- **Fixar itens**: clique com o botão direito em um card e escolha **Fixar**. Itens fixados aparecem primeiro e não são apagados pelo limite do histórico.
- **Origem**: cada card mostra o ícone do app de onde o conteúdo foi copiado.
- **Atalho configurável**: dá para trocar pelo menu da barra de status, em **Mudar atalho…**.
- **Privacidade**: ignora conteúdo marcado como sensível ou temporário (por exemplo, senhas de gerenciadores) e tudo fica salvo só no seu Mac.
- **Nenhuma permissão necessária**: não pede Acessibilidade nem qualquer outra autorização do sistema.
- **Zero dependências**: usa só AppKit, SwiftUI, Carbon e Foundation.

## Download

Baixe o `ClipPaste-<versão>-macos-arm64.zip` na página de [Releases](https://github.com/BigDevEdu/OpenClipPaste/releases), descompacte e mova o `ClipPaste.app` para `/Applications`.

> [!NOTE]
> O app tem só assinatura ad-hoc e não é notarizado pela Apple, então o macOS bloqueia a primeira abertura. Para liberar, rode:
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/ClipPaste.app
> ```
>
> Ou clique com o botão direito no app → **Abrir**.

## Requisitos

- macOS 14 (Sonoma) ou posterior
- Swift 6: basta ter as Command Line Tools instaladas (`xcode-select --install`). O Xcode não é necessário.

## Como compilar e rodar

```bash
swift build          # build de debug
swift run            # roda sem gerar o .app
swift test           # roda os testes
```

### Gerar o app

```bash
./scripts/bundle.sh
```

Isso gera `build/ClipPaste.app`: build de release para arm64, com assinatura ad-hoc. Para instalar, mova o app para `/Applications`.

> O ClipPaste roda como app de barra de menus (`LSUIElement`). Ele não aparece no Dock, só como ícone de prancheta na barra de status.

### Publicar uma release

O workflow [`release.yml`](.github/workflows/release.yml) roda sozinho quando uma tag `v*` é enviada:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Ele roda os testes, gera o app com a versão da tag aplicada no `Info.plist` e cria o GitHub Release com o `.zip` e o checksum SHA-256 anexados. Também dá para rodar manualmente pela aba **Actions**: nesse caso ele só gera o `.zip` como artefato da execução, sem criar release.

## Uso

| Ação | Como |
| --- | --- |
| Abrir/fechar o painel | **⇧⌘V** (ou **Abrir** no menu da barra de status) |
| Colar um item | Arraste o card até o destino |
| Buscar | Digite no campo **Buscar** |
| Limpar a busca / fechar | **Esc** |
| Fixar / desafixar | Botão direito no card → **Fixar** |
| Trocar o atalho | Menu da barra de status → **Mudar atalho…** |
| Apagar o histórico | Menu da barra de status → **Limpar histórico** |

## Armazenamento

O histórico fica em:

```
~/Library/Application Support/ClipPaste/
├── index.json     # metadados dos itens
└── blobs/*.png    # imagens copiadas
```

São guardados no máximo **200 itens não fixados**. Quando passa disso, os mais antigos saem primeiro.

## Estrutura do projeto

```
Sources/ClipPaste/
├── ClipPasteApp.swift      # entrada do app, AppDelegate e menu da barra de status
├── ClipboardMonitor.swift  # verifica o NSPasteboard (changeCount) periodicamente
├── HistoryStore.swift      # histórico, persistência e limite de itens
├── ClipItem.swift          # modelo de um item (texto/imagem)
├── HotKey.swift            # atalho global via Carbon RegisterEventHotKey
└── Panel.swift             # NSPanel não ativável e a interface SwiftUI dos cards
Tests/ClipPasteTests/       # testes do HistoryStore
Resources/Info.plist        # Info.plist do bundle
scripts/bundle.sh           # gera o ClipPaste.app
```

## Notas técnicas

- O painel é um `NSPanel` com `.nonactivatingPanel`. Ele não pode virar o app ativo, senão o arrastar e soltar para o app de destino deixa de funcionar.
- O macOS não avisa quando a área de transferência muda, então o app verifica `NSPasteboard.changeCount` a cada 0,5 s. Arquivos copiados no Finder (`fileURL`) são ignorados.
- O atalho global usa a API Carbon `RegisterEventHotKey`, que não exige permissão de Acessibilidade.
