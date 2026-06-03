#!/usr/bin/env bash
# Para o daemon do Gradle antes de limpar (evita erro no Windows)
export PATH="/c/flutter/bin:$PATH"
cd "$(dirname "$0")"
./android/gradlew --stop 2>/dev/null || true
flutter clean
