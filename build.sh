#!/bin/bash
set -e

echo "🔧 Installing Flutter..."

# Télécharger Flutter
curl -LO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
tar xf flutter_linux_3.24.0-stable.tar.xz

# ✅ FIX: Autoriser Git à travailler avec ces dossiers
git config --global --add safe.directory /vercel/path0/flutter
git config --global --add safe.directory /vercel/path0

# Ajouter Flutter au PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Désactiver les analytics pour éviter les prompts
flutter config --no-analytics

echo "📦 Installing dependencies..."
flutter pub get

echo "🏗️ Building for web..."
flutter build web --release --web-renderer html

echo "✅ Build completed!"