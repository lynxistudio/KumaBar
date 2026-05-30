#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build_app.sh"

STAGING="$ROOT/.build/dmg"
DMG="$ROOT/.build/KumaBar.dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$ROOT/.build/KumaBar.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "KumaBar" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

echo "$DMG"
