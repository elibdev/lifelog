#!/bin/bash
# Installs Flutter SDK and resolves project dependencies.
# Designed for CI and Claude Code web sessions where Flutter is not pre-installed.
#
# Usage: bash scripts/setup-flutter.sh

set -euo pipefail

FLUTTER_VERSION="3.38.9"
FLUTTER_DIR="/opt/flutter"
FLUTTER_TAR="/tmp/flutter_linux.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if command -v flutter &>/dev/null && flutter --version 2>/dev/null | head -1 | grep -q "$FLUTTER_VERSION"; then
  echo "Flutter $FLUTTER_VERSION already installed."
else
  echo "Installing Flutter $FLUTTER_VERSION..."
  curl -sS --fail -o "$FLUTTER_TAR" "$FLUTTER_URL"
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  tar xf "$FLUTTER_TAR" -C "$(dirname "$FLUTTER_DIR")"
  rm -f "$FLUTTER_TAR"
  git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true
  echo "Flutter $FLUTTER_VERSION installed to $FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"

# Persist PATH for the rest of the session
if ! grep -q '/opt/flutter/bin' ~/.bashrc 2>/dev/null; then
  echo 'export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"' >> ~/.bashrc
fi

echo "Resolving dependencies..."
flutter pub get

echo ""
flutter --version
echo ""
echo "Setup complete. Run 'dart analyze' or 'flutter analyze' to check code."
