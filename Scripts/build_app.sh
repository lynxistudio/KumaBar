#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCRATCH="${KUMABAR_SWIFT_SCRATCH_PATH:-$ROOT/.build/swiftpm}"
swift build --disable-sandbox --scratch-path "$SCRATCH" -c release

APP="$ROOT/.build/KumaBar.app"
CONTENTS="$APP/Contents"
rm -rf "$APP" "$ROOT/.build/dmg"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$SCRATCH/release/KumaBar" "$CONTENTS/MacOS/KumaBar"
cp "$ROOT/Config/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

if [[ ! -f "$ROOT/Assets/AppIcon.icns" ]]; then
  rm -rf "$ROOT/Assets/AppIcon.iconset"
  xcrun swift "$ROOT/Scripts/generate_icon.swift" "$ROOT/Assets/AppIcon.iconset" "$ROOT/Assets/AppIcon.icns"
fi
cp "$ROOT/Assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "$APP"
