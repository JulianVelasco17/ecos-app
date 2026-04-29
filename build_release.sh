#!/bin/bash
# Lee la versión actual del pubspec.yaml
current=$(grep '^version:' pubspec.yaml | sed 's/version: //')

# Separa nombre (1.0.2) y build number (3)
name=$(echo $current | cut -d'+' -f1)
build=$(echo $current | cut -d'+' -f2)

# Suma 1 al build number
new_build=$((build + 1))
new_version="$name+$new_build"

# Actualiza el pubspec.yaml
sed -i "s/^version: .*/version: $new_version/" pubspec.yaml

echo "✓ Versión actualizada: $current → $new_version"

# Construye el bundle
flutter build appbundle --release
