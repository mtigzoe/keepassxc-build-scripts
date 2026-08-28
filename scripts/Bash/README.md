# Running the KeePassXC Linux build scripts

These three scripts build and test KeePassXC on **Linux** — apt + CMake +
Ninja + system Qt6, instead of `build-debug.ps1`'s Windows/MSVC/vcpkg path.

**This is Linux-only.** It will not run in Windows PowerShell. If your
main machine is Windows, you need [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)
(Ubuntu) to use these. WSL2 is good for a fast compile-check of a patch or
running the non-interactive unit tests — it has no JAWS, so it's not a
substitute for testing the actual Windows build with a screen reader.

## Files

| Script | Purpose |
|---|---|
| `install-linux-build-deps.sh` | One-time: apt-installs Qt6, Botan, zlib, and everything else needed to compile |
| `build-debug.sh` | Configures + builds KeePassXC (Debug, with tests) |
| `run-tests.sh` | Runs the test suite against a build |

## First-time setup

Open a terminal in WSL2/Ubuntu (or any Debian-based Linux):

```bash
git clone https://github.com/mtigzoe/keepassxc.git
cd keepassxc
```

If you're testing a patch, apply it now, e.g.:

```bash
git apply /path/to/00-full-combined.patch
```

Make the scripts executable (only needed once per download — Windows
downloads sometimes strip the execute bit):

```bash
chmod +x install-linux-build-deps.sh build-debug.sh run-tests.sh
```

## 1. Install dependencies (once per machine)

```bash
sudo ./install-linux-build-deps.sh
```

Needs `sudo` because it's calling `apt install`. Safe to re-run any time —
apt just reports already-installed packages as up to date.

## 2. Build

```bash
./build-debug.sh /path/to/keepassxc
```

Or, if you're already inside the repo:

```bash
./build-debug.sh .
```

This creates `build-debug/` inside the repo and compiles everything,
including unit and GUI test binaries. Pass `--clean` to wipe and
reconfigure from scratch:

```bash
./build-debug.sh . --clean
```

**Timing:** ~35–40 minutes on a single core; scales down with more cores
(`nproc` to check how many you have).

The built app ends up at `build-debug/src/keepassxc`.

## 3. Run tests

```bash
./run-tests.sh /path/to/keepassxc/build-debug
```

Runs the 41 non-GUI unit tests (`testgroup`, `testdatabase`, `testcli`,
etc.) and prints a pass/fail summary.

To also attempt the interactive GUI tests (`testgui` and friends):

```bash
./run-tests.sh /path/to/keepassxc/build-debug --gui
```

This spins up a throwaway virtual display (Xvfb + fluxbox) so it doesn't
need a real screen. **Caveat, from experience:** GUI tests depend on real
window-focus events, and a fresh virtual display sometimes doesn't deliver
them reliably — even unmodified, pre-existing tests can hang for the full
5-minute timeout with no code problem at all. Treat a `--gui` hang or
timeout as inconclusive, not a red flag. The non-GUI run is the reliable
signal; a Windows build tested with JAWS is the reliable signal for actual
screen-reader behavior.

## Typical workflow for checking a patch

```bash
git clone https://github.com/mtigzoe/keepassxc.git
cd keepassxc
git apply /path/to/some.patch
sudo ./install-linux-build-deps.sh      # first time only
./build-debug.sh .
./run-tests.sh ./build-debug
```
