#!/usr/bin/env bash
#
# run-tests.sh
#
# Runs KeePassXC's test suite against a build produced by
# build-debug.sh.
#
# Usage:
#   ./run-tests.sh [path-to-build-dir] [--gui]
#
# By default this only runs the non-GUI unit tests (testgroup,
# testdatabase, testcli, etc. -- 41 of the 46 registered tests). Pass
# --gui to also attempt the interactive GUI suite (testgui,
# testguiattachments, testguibrowser, testguifdosecrets), which needs
# a real, focused X window manager.
#
# HONEST CAVEAT about --gui, from actually hitting this:
# The GUI tests spin up a real QApplication and drive real widgets
# with QTest::keyClick / QTRY_COMPARE(qApp->focusWidget(), ...), so
# they need actual window-manager focus events, not just a display.
# In a throwaway/headless Xvfb + fluxbox session (no prior config,
# no real user session) I found even pre-existing, unmodified tests
# (e.g. testCreateDatabase) can hang for the full 300s QTest timeout
# waiting on a focus change that fluxbox never delivers. That's a
# sandbox/environment issue, not a sign your patch is broken -- the
# same hang happens on an unpatched checkout. A real X session (your
# own desktop, or a properly pre-configured CI display) is much more
# reliable for this than a fresh Xvfb. Treat --gui here as "best
# effort local sanity check", not a substitute for running JAWS
# against a real KeePassXC.exe build.

set -uo pipefail  # no -e: we want to keep going and report ctest's exit code ourselves

BUILD_DIR="${1:-./build-debug}"
RUN_GUI=0
for arg in "$@"; do
    [[ "$arg" == "--gui" ]] && RUN_GUI=1
done

if [[ ! -f "$BUILD_DIR/CTestTestfile.cmake" ]]; then
    echo "error: $BUILD_DIR doesn't look like a configured build dir (run build-debug.sh first)" >&2
    exit 1
fi

cd "$BUILD_DIR"
export QT_QPA_PLATFORM=offscreen
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

echo "== Non-GUI unit tests =="
ctest -E '^testgui' -j"$(nproc)" --timeout 60 --output-on-failure

NON_GUI_STATUS=$?

if [[ $RUN_GUI -eq 0 ]]; then
    echo
    echo "Skipping GUI tests (pass --gui to attempt them; see caveat in this script's header)."
    exit $NON_GUI_STATUS
fi

echo
echo "== GUI tests (best effort; see caveat above) =="

DISPLAY_NUM=99
Xvfb ":$DISPLAY_NUM" -screen 0 1280x1024x24 -nolisten tcp &
XVFB_PID=$!
sleep 1
DISPLAY=":$DISPLAY_NUM" fluxbox >/dev/null 2>&1 &
FLUXBOX_PID=$!
sleep 1

DISPLAY=":$DISPLAY_NUM" ctest -R '^testgui' -j1 --timeout 300 --output-on-failure
GUI_STATUS=$?

kill "$FLUXBOX_PID" "$XVFB_PID" 2>/dev/null || true

echo
if [[ $NON_GUI_STATUS -eq 0 && $GUI_STATUS -eq 0 ]]; then
    echo "All tests passed."
elif [[ $GUI_STATUS -ne 0 ]]; then
    echo "Non-GUI: $([[ $NON_GUI_STATUS -eq 0 ]] && echo PASSED || echo FAILED). GUI: FAILED or timed out -- see caveat at the top of this script before assuming a regression."
fi

exit $(( NON_GUI_STATUS != 0 || GUI_STATUS != 0 ))
