#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOSITORY_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$REPOSITORY_DIR/VERSION")"
TAG_VERSION="${GITHUB_REF_NAME:-}"

if [[ "$TAG_VERSION" == v* && "$TAG_VERSION" != "v$VERSION" ]]; then
  echo "Tag $TAG_VERSION does not match VERSION $VERSION." >&2
  exit 1
fi

DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/AgentOre.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$DIST_DIR/AgentOre.iconset"
APP_ICON_SOURCE="$REPOSITORY_DIR/assets/agentore-app-icon.png"
TOKEN_ICON_SOURCE="$REPOSITORY_DIR/assets/agentore-token.png"
ARCHIVE="$DIST_DIR/AgentOre-v$VERSION-macos-universal.zip"
CHECKSUM="$ARCHIVE.sha256"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 --product AgentOre
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
install -m 755 "$BIN_DIR/AgentOre" "$MACOS_DIR/AgentOre"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  read -r size filename <<< "$spec"
  sips -z "$size" "$size" "$APP_ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
done
swift "$SCRIPT_DIR/make-icns.swift" "$ICONSET_DIR" "$RESOURCES_DIR/AgentOre.icns"
sips -z 128 128 "$TOKEN_ICON_SOURCE" --out "$RESOURCES_DIR/AgentOreToken.png" >/dev/null
rm -rf "$ICONSET_DIR"

plutil -create xml1 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string en "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleExecutable -string AgentOre "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIdentifier -string net.smallyu.agentore "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleIconFile -string AgentOre "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleName -string AgentOre "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleDisplayName -string AgentOre "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$CONTENTS_DIR/Info.plist"
plutil -insert CFBundleVersion -string "$VERSION" "$CONTENTS_DIR/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.0 "$CONTENTS_DIR/Info.plist"
plutil -insert LSUIElement -bool true "$CONTENTS_DIR/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - --options runtime --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ARCHITECTURES="$(lipo -archs "$MACOS_DIR/AgentOre")"
[[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]] || {
  echo "Expected a universal binary, found: $ARCHITECTURES" >&2
  exit 1
}

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
cd "$DIST_DIR"
shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$CHECKSUM")"

echo "Created $ARCHIVE"
echo "Architectures: $ARCHITECTURES"
cat "$CHECKSUM"
