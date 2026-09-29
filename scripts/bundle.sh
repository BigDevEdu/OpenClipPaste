#!/bin/bash
# Gera build/ClipPaste.app (release, arm64, assinatura ad-hoc).
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/ClipPaste.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if swift build -c release 2>/dev/null; then
    cp "$(swift build -c release --show-bin-path)/ClipPaste" "$APP/Contents/MacOS/ClipPaste"
else
    # Fallback: SwiftPM quebrado (CLT com versões misturadas) → swiftc direto com o SDK 26.
    echo "swift build falhou; usando swiftc direto" >&2
    SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
    [ -d "$SDK" ] || SDK=$(xcrun --show-sdk-path)
    swiftc -swift-version 6 -parse-as-library -O -target arm64-apple-macos14.0 -sdk "$SDK" \
        Sources/ClipPaste/*.swift -o "$APP/Contents/MacOS/ClipPaste"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "OK: $APP"
