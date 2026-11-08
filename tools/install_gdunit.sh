#!/bin/bash
# Installs gdUnit4 (test framework for Truss's own tests) into addons/gdUnit4.
# Usage: tools/install_gdunit.sh [version]   (default v6.2.3, which supports Godot 4.5 to 4.7)
set -euo pipefail
VERSION="${1:-v6.2.3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
curl -sSL -o "$TMP/gdunit.zip" "https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/${VERSION}.zip"
unzip -q "$TMP/gdunit.zip" -d "$TMP"
rm -rf "$ROOT/addons/gdUnit4"
cp -r "$TMP"/gdUnit4-*/addons/gdUnit4 "$ROOT/addons/gdUnit4"
rm -rf "$TMP"
echo "gdUnit4 ${VERSION} installed in addons/gdUnit4"
