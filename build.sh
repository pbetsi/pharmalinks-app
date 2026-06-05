#!/bin/bash
set -e

# Télécharger et installer Flutter
echo "🔧 Installing Flutter..."
curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar xf flutter_linux_3.24.0-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

# Installer les dépendances
echo "📦 Installing dependencies..."
flutter pub get

# Builder pour le web
echo "🏗️ Building for web..."
flutter build web --release --web-renderer html

echo "✅ Build completed!"