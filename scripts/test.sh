#!/bin/sh
set -eu

plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test -s "$plugin_root/assets/deepseek-sticker.png"
for sound in rubble-duck1.mp3 rubble-duck2.mp3 cute-cat-meow-loud.mp3; do
  test -s "$plugin_root/assets/$sound"
done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$plugin_root/tests" -v
mkdir -p "$plugin_root/.build/module-cache"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit -framework CoreGraphics \
  "$plugin_root/app/WindowPlacement.swift" \
  "$plugin_root/tests/WindowPlacementTests.swift" \
  -o "$plugin_root/.build/test-window-placement"
"$plugin_root/.build/test-window-placement"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -parse-as-library -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit \
  "$plugin_root/app/PetGesture.swift" \
  "$plugin_root/tests/PetGestureTests.swift" \
  -o "$plugin_root/.build/test-pet-gesture"
"$plugin_root/.build/test-pet-gesture"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  "$plugin_root/app/BubbleSequence.swift" \
  "$plugin_root/tests/BubbleSequenceTests.swift" \
  -o "$plugin_root/.build/test-bubble-sequence"
"$plugin_root/.build/test-bubble-sequence"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  "$plugin_root/app/PetSettings.swift" \
  "$plugin_root/tests/PetSettingsTests.swift" \
  -o "$plugin_root/.build/test-pet-settings"
"$plugin_root/.build/test-pet-settings"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -parse-as-library -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit \
  "$plugin_root/tests/WhaleHitTests.swift" \
  -o "$plugin_root/.build/test-whale-hit"
"$plugin_root/.build/test-whale-hit" "$plugin_root/assets/deepseek-sticker.png"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AVFoundation \
  "$plugin_root/app/PetSoundPlayer.swift" \
  "$plugin_root/tests/PetSoundTests.swift" \
  -o "$plugin_root/.build/test-pet-sound"
"$plugin_root/.build/test-pet-sound" "$plugin_root/assets/deepseek-sticker.png"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  "$plugin_root/app/QuotaSnapshot.swift" \
  "$plugin_root/tests/QuotaSnapshotTests.swift" \
  -o "$plugin_root/.build/test-quota-snapshot"
"$plugin_root/.build/test-quota-snapshot"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  "$plugin_root/app/QuotaMonitor.swift" \
  "$plugin_root/app/QuotaSnapshot.swift" \
  "$plugin_root/tests/QuotaMonitorTests.swift" \
  -o "$plugin_root/.build/test-quota-monitor"
"$plugin_root/.build/test-quota-monitor"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit \
  "$plugin_root/app/QuotaBubblePlacement.swift" \
  "$plugin_root/tests/QuotaBubblePlacementTests.swift" \
  -o "$plugin_root/.build/test-quota-bubble-placement"
"$plugin_root/.build/test-quota-bubble-placement"
