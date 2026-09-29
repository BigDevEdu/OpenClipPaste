# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ClipPaste — native macOS clipboard history app (Swift 6, SwiftUI + AppKit). Global hotkey (default ⇧⌘V) opens a bottom full-width panel of cards; the user drags a card into any input. Specs: `docs/PRD.md` (product) and `docs/TRD.md` (technical). MVP scope (TRD v1.1): text + image only, drag & drop, no permissions, personal use.

## Commands

Only Command Line Tools are installed (no Xcode) — use SwiftPM, never `.xcodeproj`.

```bash
swift build                 # debug build
swift run                   # run without bundle
swift test                  # tests (Tests/ClipPasteTests)
./scripts/bundle.sh         # release build → build/ClipPaste.app (ad-hoc signed)
```

## Architecture rules

- Zero third-party dependencies; AppKit/Carbon/Foundation cover everything.
- Panel is an `NSPanel` with `.nonactivatingPanel` — it must never steal focus from the target app (drag & drop depends on this).
- Clipboard is polled via `NSPasteboard.changeCount` (no system notification exists). Skip concealed/transient types and ClipPaste's own writes.
- Global hotkey via Carbon `RegisterEventHotKey` (no Accessibility permission). No Accessibility permission in MVP.
- Persistence: `~/Library/Application Support/ClipPaste/index.json` + `blobs/*.png`, max 200 items.
- UI strings in pt-BR.

## Language

Reply to the user in Brazilian Portuguese (pt-BR). Code identifiers in English.
