# PRD — ClipPaste

> Product Requirements Document · v1.0 · 2026-09-29

## 1. Visão

ClipPaste é um gerenciador de histórico da área de transferência nativo para macOS. Ele guarda tudo que o usuário copia (texto e imagens) e, com um atalho global (padrão **⇧⌘V**), abre uma faixa horizontal de cards na parte inferior da tela. O usuário **arrasta um card e solta em qualquer campo de input** de qualquer app.

Referência visual: faixa translúcida escura, full-width, com barra superior (busca, "Área de transferência", listas, "+", menu "…") e cards horizontais roláveis.

## 2. Problema

O macOS guarda só o último item copiado. Quem copia várias coisas em sequência (trechos de código, prints, URLs, arquivos) perde o que copiou antes e precisa voltar à origem para copiar de novo.

## 3. Público-alvo

- Desenvolvedores, designers e profissionais de suporte que copiam/colam dezenas de itens por hora.
- Usuário principal: o próprio autor (uso pessoal, Apple Silicon, macOS 26).

## 4. Objetivos e métricas

| Objetivo | Métrica de sucesso |
|---|---|
| Painel abre instantaneamente | < 150 ms do atalho até o painel visível |
| Captura confiável | 100% das cópias de texto/imagem registradas enquanto o app roda |
| Leve | < 1% CPU em idle, < 80 MB RAM com 500 itens |
| Reutilizar item em ≤ 2 ações | Atalho → arrastar |

## 5. Escopo

### 5.1 MVP (v1.0) — decidido em 2026-09-29

Uso **pessoal** (build local, assinatura ad-hoc). Nenhuma permissão especial do macOS.

| ID | Requisito |
|---|---|
| F1 | Monitorar a área de transferência e salvar cada novo item |
| F2 | Tipos: **Texto** (inclui URLs, tratadas como texto) e **Imagem** (PNG/TIFF). Arquivos do Finder são ignorados |
| F3 | Atalho global configurável, padrão **⇧⌘V**, abre/fecha o painel |
| F4 | Painel inferior full-width, translúcido, cards em rolagem horizontal (mais recente à esquerda) |
| F5 | Card: cabeçalho colorido com tipo + tempo relativo ("há 7 minutos"), ícone do app de origem, preview (texto ou miniatura), rodapé com detalhe (`200 × 200` ou nº de caracteres) e posição |
| F6 | **Arrastar e soltar** um card em qualquer input/app |
| F7 | Painel **não rouba o foco** do app atual |
| F8 | Fecha com Esc, clique fora, atalho de novo, e automaticamente após o drop |
| F9 | Persistência entre reinicializações, **máx. 200 itens**; cópia repetida sobe para o topo |
| F10 | Ignorar itens concealed/transient (gerenciadores de senha) |
| F11 | Só na barra de menus (sem Dock): Mudar atalho…, Limpar histórico, Sair |

### 5.2 Depois do MVP

- Busca; setas + Enter para colar direto (requer Acessibilidade); excluir item.
- Links e arquivos como tipos próprios.
- Listas/Pinboards ("Sem Título" + "+").
- Abrir no login.

### 5.3 Fora de escopo

- Sincronização, outras plataformas, OCR, edição, Mac App Store.

## 6. Fluxos principais

**Arrastar (fluxo principal)**
1. Usuário está com o cursor num input (ex.: campo do Chrome).
2. Pressiona ⇧⌘V → painel sobe da borda inferior.
3. Arrasta o card desejado até o input e solta → conteúdo inserido.
4. Painel fecha sozinho.


## 7. Requisitos não funcionais

- **Plataforma:** macOS 14 Sonoma ou superior, Apple Silicon e Intel.
- **Privacidade:** dados 100% locais em `~/Library/Application Support/ClipPaste`; nenhuma rede.
- **Acessibilidade:** navegação completa por teclado; respeitar "Reduzir movimento" e modo claro/escuro.
- **Idioma:** interface em pt-BR.
- **Permissões:** nenhuma permissão especial no MVP.

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Não existe notificação de mudança do pasteboard no macOS | Polling leve do `changeCount` (ver TRD) |
| Alguns apps não aceitam drop de imagem | Pós-MVP: Enter cola via pasteboard |
| Conflito do ⇧⌘V com atalho de outro app ("Colar e manter estilo") | Atalho configurável; avisar se o registro falhar |
| Guardar dados sensíveis | Respeitar tipos concealed/transient + lista de apps ignorados |

## 9. Critérios de aceite do MVP

- [ ] Copiar texto e imagem → aparecem como cards com tipo, app de origem e tempo corretos.
- [ ] ⇧⌘V abre o painel sobre qualquer app, inclusive em tela cheia, sem tirar o foco do input.
- [ ] Arrastar card de texto para um input do Chrome insere o texto; imagem para o Slack/Notes insere a imagem.
- [ ] Trocar o atalho pelo menu funciona sem reiniciar.
- [ ] Reiniciar o app mantém o histórico.
- [ ] Copiar uma senha no 1Password não gera card.
