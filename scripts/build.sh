#!/bin/sh
set -eu

plugin_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$plugin_root/bin" "$plugin_root/.build/module-cache"
CLANG_MODULE_CACHE_PATH="$plugin_root/.build/module-cache" \
  xcrun swiftc -O -module-cache-path "$plugin_root/.build/module-cache" \
  -framework AppKit -framework CoreGraphics -framework AVFoundation \
  "$plugin_root"/app/*.swift -o "$plugin_root/bin/deepseek-girl"
