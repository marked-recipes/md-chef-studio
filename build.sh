#!/usr/bin/env bash
set -e

echo "=== MD Chef Studio Netlify Build ==="

# Check if Flutter is already installed
if ! command -v flutter &> /dev/null; then
  echo "Flutter not found. Installing Flutter SDK..."
  FLUTTER_VERSION="3.24.3"
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

  mkdir -p /tmp/flutter_sdk
  curl -s -L "$FLUTTER_URL" | tar -xJ -C /tmp/flutter_sdk
  export PATH="/tmp/flutter_sdk/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter Web (release)..."
flutter build web --release

echo "=== Build Completed Successfully ==="
