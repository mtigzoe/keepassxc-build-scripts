#!/usr/bin/env bash
#
# build-debug.sh
#
# Linux equivalent of build-debug.ps1: configures and builds
# KeePassXC in Debug mode using CMake + Ninja + apt-installed Qt6,
# with unit tests enabled.
#
# Usage:
#   ./build-debug.sh [path-to-keepassxc-repo] [--clean]
#
# Defaults to the current directory if no path is given, matching
# build-debug.ps1's "sibling folder auto-detect" spirit but simpler,
# since there's no vcpkg/VS-dev-shell dance needed here -- apt already
# put everything on the standard system include/lib paths.
#
# What this does NOT do (unlike build-debug.ps1):
# - No vcpkg toolchain file (dependencies come from apt instead)
# - No Visual Studio dev shell detection
# - Docs/network/update-check features are disabled by default below
#   to keep the dependency list small; drop those two -D flags if you
#   want them built too (needs asciidoctor, already installed by
#   install-linux-build-deps.sh, for docs).

set -euo pipefail

REPO="${1:-.}"
CLEAN=0
for arg in "$@"; do
    [[ "$arg" == "--clean" ]] && CLEAN=1
done

if [[ ! -f "$REPO/CMakeLists.txt" ]]; then
    echo "error: $REPO doesn't look like a KeePassXC checkout (no CMakeLists.txt)" >&2
    exit 1
fi

BUILD_DIR="$REPO/build-debug"

if [[ $CLEAN -eq 1 && -d "$BUILD_DIR" ]]; then
    echo "Removing existing build directory ($BUILD_DIR)..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "== Configuring =="
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWITH_TESTS=ON \
    -DWITH_GUI_TESTS=ON \
    -DKPXC_FEATURE_NETWORK=OFF \
    -DKPXC_FEATURE_UPDATES=OFF \
    -DKPXC_FEATURE_DOCS=OFF \
    ..

echo
echo "== Building (this took ~35-40 min on a single-core sandbox; scales with cores) =="
ninja

echo
echo "Build finished. Binary: $BUILD_DIR/src/keepassxc"
echo "Unit test binaries:     $BUILD_DIR/tests/"
echo "Run ./run-tests.sh \"$BUILD_DIR\" to execute the test suite."
