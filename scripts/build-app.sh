#!/bin/zsh
set -euo pipefail

APP_NAME="Capsomnia"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if (( $# > 1 )); then
  echo "Usage: scripts/build-app.sh [output-app-path]" >&2
  exit 64
fi

REQUESTED_APP_BUNDLE="${1:-$ROOT_DIR/dist/$APP_NAME.app}"
case "$REQUESTED_APP_BUNDLE" in
  /*) APP_BUNDLE="$REQUESTED_APP_BUNDLE" ;;
  *) APP_BUNDLE="$ROOT_DIR/$REQUESTED_APP_BUNDLE" ;;
esac

if [[ "$APP_BUNDLE" != *.app ]]; then
  echo "Output path must end with .app: $APP_BUNDLE" >&2
  exit 64
fi

CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Resolve a certificate before building; never silently use ad-hoc signing.
SIGNING_IDENTITIES="$(/usr/bin/security find-identity -v -p codesigning)"
APPLE_IDENTITIES="$(printf '%s\n' "$SIGNING_IDENTITIES" | /usr/bin/awk '/"(Apple Development:|Mac Developer:|Apple Distribution:|Developer ID Application:)/ { print $2 }')"
if [[ -n "${APP_SIGN_ID:-}" ]]; then
  SIGNING_ID="$(printf '%s\n' "$SIGNING_IDENTITIES" | /usr/bin/awk -v requested="$APP_SIGN_ID" '
    /"(Apple Development:|Mac Developer:|Apple Distribution:|Developer ID Application:)/ {
      name = $0; sub(/^[^"]*"/, "", name); sub(/".*$/, "", name)
      if ($2 == requested || name == requested) print $2
    }')"
else
  SIGNING_ID="$APPLE_IDENTITIES"
fi
if [[ -z "$SIGNING_ID" || "$SIGNING_ID" == *$'\n'* ]]; then
  echo "Select exactly one valid Apple signing identity with APP_SIGN_ID; signing stopped." >&2
  exit 1
fi
echo "Signing identity: $SIGNING_ID" >&2

cd "$ROOT_DIR"
/usr/bin/swift build -c release >&2

/bin/rm -rf "$APP_BUNDLE"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/install -m 0755 ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
/usr/bin/install -m 0644 "resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/install -m 0644 "resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/install -m 0644 "LICENSE" "$RESOURCES_DIR/LICENSE"
/usr/bin/install -m 0755 "scripts/uninstall.sh" "$RESOURCES_DIR/uninstall.sh"

/usr/bin/codesign --force --options runtime --sign "$SIGNING_ID" "$APP_BUNDLE" >&2
/usr/bin/codesign --force --options runtime --sign "$SIGNING_ID" ".build/release/capsomnia-pmset" >&2
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE" >&2
/usr/bin/codesign --verify --strict ".build/release/capsomnia-pmset" >&2

echo "$APP_BUNDLE"
