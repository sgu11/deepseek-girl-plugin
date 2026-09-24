#!/bin/sh
set -eu

plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output=${1:-"$plugin_root/.build/quota-bubble-preview.png"}
mkdir -p "$plugin_root/.build/module-cache"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -parse-as-library -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit \
  "$plugin_root/app/QuotaSnapshot.swift" \
  "$plugin_root/app/QuotaBubblePlacement.swift" \
  "$plugin_root/app/QuotaBubblePanel.swift" \
  "$plugin_root/tests/QuotaBubblePreview.swift" \
  -o "$plugin_root/.build/preview-bubble"
"$plugin_root/.build/preview-bubble" "$plugin_root/assets/deepseek-sticker.png" "$output"
printf '%s\n' "$output"
