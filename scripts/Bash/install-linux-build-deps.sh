#!/usr/bin/env bash
#
# install-linux-build-deps.sh
#
# Installs everything needed to build KeePassXC from source on
# Ubuntu 24.04 (noble) / Debian-based systems, using distro packages
# instead of vcpkg. This is the Linux-native equivalent of what
# build-debug.ps1 does with vcpkg on Windows: it gets you a working
# Qt6 + Botan + zlib + minizip + friends toolchain, just via apt.
#
# Tested against: Ubuntu 24.04, KeePassXC develop branch (Qt6 build).
# Run with sudo, or as root:
#   sudo ./install-linux-build-deps.sh
#
# Notes:
# - Package list was assembled incrementally by actually running
#   `cmake` and installing whatever it reported missing next, so it
#   should be the minimal set for a Qt6 desktop build with tests.
# - libpcsclite-dev / libusb-1.0-0-dev are for smart-card and
#   hardware-key (YubiKey) support; safe to keep even if you don't
#   have such hardware -- the app just reports "no reader found".
# - xvfb + fluxbox + gdb are optional; only needed if you also want
#   to run the GUI test suite (testgui, etc.) or debug a crash. See
#   the caveat about GUI tests in run-tests.sh -- they need a real
#   window manager (fluxbox) for focus events, not just a bare Xvfb.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script needs root (apt install). Re-run with sudo." >&2
    exit 1
fi


# Don't let set -e kill the whole script if some unrelated third-party
# repo (e.g. an old nodesource entry) is stale/unreachable -- as long
# as the main Ubuntu repos refreshed, we can still proceed.
if ! apt-get update; then
    echo "warning: apt-get update reported errors (see above)." >&2
    echo "         Continuing anyway -- this is usually a stale third-party" >&2
    echo "         repo, not the main Ubuntu ones. If the installs below" >&2
    echo "         fail too, fix/remove the failing repo first." >&2
fi

apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    git \
    \
    qt6-base-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-l10n-tools \
    libqt6svg6-dev \
    \
    libbotan-2-dev \
    zlib1g-dev \
    libminizip-dev \
    libargon2-dev \
    libqrencode-dev \
    libreadline-dev \
    \
    libpcsclite-dev \
    libusb-1.0-0-dev \
    libkeyutils-dev \
    \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxi-dev \
    libxtst-dev \
    libx11-dev \
    \
    asciidoctor \
    \
    gdb \
    xvfb \
    fluxbox

echo
echo "Done. Versions installed:"
echo "  cmake:  $(cmake --version | head -1)"
echo "  qmake:  $(qmake6 --version 2>/dev/null | tail -1 || echo 'not on PATH, but library is installed')"
echo "  g++:    $(g++ --version | head -1)"
