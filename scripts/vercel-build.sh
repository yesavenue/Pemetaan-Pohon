#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.29.3}"

flutter_build_sdk="$(mktemp -d /tmp/pohon-flutter.XXXXXX)"
trap 'rm -rf "$flutter_build_sdk"' EXIT

git clone --depth 1 --branch "$FLUTTER_VERSION" \
  https://github.com/flutter/flutter.git "$flutter_build_sdk"

export PATH="$flutter_build_sdk/bin:$PATH"
export CI=true

flutter config --no-analytics
flutter --version
flutter pub get
flutter build web --release --dart-define=SURVEYOR_APP=false --base-href /app/

test -f build/web/index.html
test -f build/web/flutter_bootstrap.js
node scripts/assemble-site.mjs
node scripts/test-public-site.mjs
