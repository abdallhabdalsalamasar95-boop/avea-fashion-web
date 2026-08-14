#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_FIXED="$REPO_ROOT/deploy_web_fixed.zip"
ARCHIVE_LEGACY="$REPO_ROOT/deploy_web.zip"
TARGET="$REPO_ROOT/build/web"
TMP_TARGET="$REPO_ROOT/build/web_unpacked_tmp"
FALLBACK_BUILD_SCRIPT="$REPO_ROOT/tool/render_build_web.sh"

resolve_archive() {
  if [ -f "$ARCHIVE_FIXED" ]; then
    echo "$ARCHIVE_FIXED"
    return
  fi
  echo "$ARCHIVE_LEGACY"
}

fallback_build() {
  echo "[render_unpack_web] Falling back to source build..."
  if [ ! -x "$FALLBACK_BUILD_SCRIPT" ]; then
    echo "Missing fallback build script: $FALLBACK_BUILD_SCRIPT" >&2
    exit 1
  fi
  bash "$FALLBACK_BUILD_SCRIPT"
}

validate_unpacked_site() {
  local root="$1"
  [ -f "$root/index.html" ] || return 1
  [ -f "$root/main.dart.js" ] || return 1
  [ -f "$root/sqflite_sw.js" ] || return 1
  [ -f "$root/sqlite3.wasm" ] || return 1
  [ -f "$root/manifest.json" ] || return 1
  [ -f "$root/assets/FontManifest.json" ] || return 1
  grep -q 'id="welcome"' "$root/index.html" || return 1
  grep -q 'AVEA FASHION' "$root/manifest.json" || return 1
  if [ ! -f "$root/assets/AssetManifest.json" ] \
    && [ ! -f "$root/assets/AssetManifest.bin.json" ] \
    && [ ! -f "$root/assets/AssetManifest.bin" ]; then
    return 1
  fi
  return 0
}

rm -rf "$TARGET"
rm -rf "$TMP_TARGET"
mkdir -p "$REPO_ROOT/build"

ARCHIVE="$(resolve_archive)"

if [ ! -f "$ARCHIVE" ]; then
  echo "Missing archive: $ARCHIVE" >&2
  fallback_build
  exit 0
fi

if ! unzip -q "$ARCHIVE" -d "$TMP_TARGET"; then
  echo "[render_unpack_web] Failed to unzip archive: $ARCHIVE" >&2
  fallback_build
  exit 0
fi

if ! validate_unpacked_site "$TMP_TARGET"; then
  echo "[render_unpack_web] Archive is incomplete (missing Flutter runtime/assets)." >&2
  fallback_build
  rm -rf "$TMP_TARGET"
  exit 0
fi

mv "$TMP_TARGET" "$TARGET"
