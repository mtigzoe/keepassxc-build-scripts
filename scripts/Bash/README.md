# Running the KeePassXC Linux build scripts

These three scripts build and test KeePassXC on **Linux** — apt + CMake +
Ninja + system Qt6, instead of `build-debug.ps1`'s Windows/MSVC/vcpkg path.

**This is Linux-only.** It will not run in Windows PowerShell. If your
main machine is Windows, you can use **WSL2** (Ubuntu) or another
Debian-based Linux environment to use these scripts. WSL2 is useful for a
fast compile-check of a patch and for running the non-interactive unit
tests. It does **not** provide JAWS, so it is not a substitute for testing
the actual Windows build with a screen reader.

These scripts are also useful for **AI coding-agent sandboxes**. A Linux
sandbox can use them to install the build dependencies, compile KeePassXC,
and run the automated tests without needing the Windows/MSVC/vcpkg
environment.

## Files

| Script | Purpose |
|---|---|
| `install-linux-build-deps.sh` | One-time: apt-installs Qt6, Botan, zlib, and everything else needed to compile |
| `build-debug.sh` | Configures + builds KeePassXC in Debug mode, with unit and GUI tests enabled |
| `run-tests.sh` | Runs the test suite; reliable non-GUI tests by default, with optional best-effort GUI tests |

## First-time setup

Open a terminal in WSL2/Ubuntu (or any Debian-based Linux environment):

```bash
git clone https://github.com/mtigzoe/keepassxc.git
cd keepassxc
```

If you're testing a patch, apply it now, for example:

```bash
git apply /path/to/00-full-combined.patch
```

The helper scripts are in this repository's `scripts/Bash/` directory.
Make them executable if necessary (Windows downloads can sometimes strip
the execute bit):

```bash
chmod +x scripts/Bash/*.sh
```

## 1. Install dependencies (once per machine)

```bash
sudo ./scripts/Bash/install-linux-build-deps.sh
```

This needs `sudo` because it calls `apt install`. It is safe to re-run;
`apt` will report packages that are already installed as up to date.

## 2. Build

From the KeePassXC repository root:

```bash
./scripts/Bash/build-debug.sh .
```

You can also provide the repository path explicitly:

```bash
./scripts/Bash/build-debug.sh /path/to/keepassxc
```

This creates `build-debug/` inside the repo and compiles KeePassXC,
including the unit and GUI test binaries. Pass `--clean` to wipe and
reconfigure from scratch:

```bash
./scripts/Bash/build-debug.sh . --clean
```

The built application ends up at:

```text
build-debug/src/keepassxc
```

Build time depends heavily on the available CPU resources. A single-core
sandbox can take roughly 35–40 minutes; environments with more CPU cores
will normally be substantially faster.

The build disables network/update-check features and documentation by
default to keep the dependency and build requirements smaller. The
installed dependency script includes `asciidoctor` if documentation support
is needed later.

## 3. Run tests

### Reliable non-GUI tests

```bash
./scripts/Bash/run-tests.sh ./build-debug
```

This runs the non-GUI unit tests and reports the CTest pass/fail result.
These are the preferred automated tests for a headless Linux or AI-agent
sandbox.

### Optional GUI tests

```bash
./scripts/Bash/run-tests.sh ./build-debug --gui
```

This attempts the GUI test suite using a temporary Xvfb display and
Fluxbox window manager.

**Important:** GUI tests in a fresh headless sandbox are **best effort**.
Some existing KeePassXC GUI tests depend on real window-focus events and
can hang or time out under Xvfb/Fluxbox even when the source code is
correct. A GUI-test timeout in this environment is therefore inconclusive
and should not automatically be treated as a regression.

For actual accessibility validation, build and run KeePassXC on Windows
and test it with JAWS. Linux/WSL2 automated testing is complementary to,
not a replacement for, real Windows screen-reader testing.

## Typical workflow for checking a patch

```bash
git clone https://github.com/mtigzoe/keepassxc.git
cd keepassxc
git apply /path/to/some.patch

# First time on a machine/sandbox only:
sudo ./scripts/Bash/install-linux-build-deps.sh

# Build:
./scripts/Bash/build-debug.sh .

# Reliable automated tests:
./scripts/Bash/run-tests.sh ./build-debug
```

## Workflow for AI coding agents

A coding agent running in a Linux sandbox can use the scripts as a
repeatable build/test workflow:

```bash
sudo ./scripts/Bash/install-linux-build-deps.sh
./scripts/Bash/build-debug.sh .
./scripts/Bash/run-tests.sh ./build-debug
```

The agent can then inspect compiler errors, test failures, and source-code
changes without needing the Windows development environment.

For accessibility changes, the final validation should still be performed
on the Windows build with JAWS. A Linux sandbox cannot reproduce JAWS
behavior.
