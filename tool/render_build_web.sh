#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_ROOT="${FLUTTER_ROOT:-$REPO_ROOT/.render/flutter}"
FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"

if [ ! -x "$FLUTTER_BIN" ]; then
  mkdir -p "$FLUTTER_ROOT"
  if [ ! -d "$FLUTTER_ROOT/.git" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
  else
    git -C "$FLUTTER_ROOT" pull --ff-only
  fi
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release --base-href /

# Keep AdSense/domain verification files in the final static publish folder.
mkdir -p "$REPO_ROOT/build/web"

if [ -f "$REPO_ROOT/web/ads.txt" ]; then
  cp "$REPO_ROOT/web/ads.txt" "$REPO_ROOT/build/web/ads.txt"
fi

if [ -f "$REPO_ROOT/web/adsense-config.js" ]; then
  cp "$REPO_ROOT/web/adsense-config.js" "$REPO_ROOT/build/web/adsense-config.js"
fi

# Google site verification files (if any): googleXXXXXXXX.html
for f in "$REPO_ROOT"/web/google*.html; do
  if [ -f "$f" ]; then
    cp "$f" "$REPO_ROOT/build/web/"
  fi
done
