#!/usr/bin/env bash
set -e

echo "=== MD Chef Studio Netlify Build ==="

# Check if Flutter is already installed or available in /tmp/flutter_sdk
if ! command -v flutter &> /dev/null; then
  if [ -x "/tmp/flutter_sdk/flutter/bin/flutter" ]; then
    echo "Found existing Flutter SDK in /tmp/flutter_sdk/flutter/bin"
    export PATH="/tmp/flutter_sdk/flutter/bin:$PATH"
  else
    echo "Flutter not found. Installing Flutter SDK (stable channel)..."
    mkdir -p /tmp/flutter_sdk
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git /tmp/flutter_sdk/flutter
    export PATH="/tmp/flutter_sdk/flutter/bin:$PATH"
  fi
fi

# Prevent Git dubious ownership errors in CI/Netlify build container
git config --global --add safe.directory /tmp/flutter_sdk/flutter 2>/dev/null || true
git config --global --add safe.directory "$PWD" 2>/dev/null || true

flutter --version
flutter config --no-analytics
flutter config --enable-web

echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter Web (release)..."
flutter build web --release

echo "=== Build Completed Successfully ==="
