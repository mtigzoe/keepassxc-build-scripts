# KeePassXC Build & Test Scripts

PowerShell and Bash scripts for building and testing [KeePassXC](https://github.com/keepassxreboot/keepassxc) on Windows and Linux.

This repository is a collection of development helper scripts. It is **not** the KeePassXC source repository.

## What this repository provides

- **Windows / PowerShell** scripts for configuring and building KeePassXC with the Windows development toolchain.
- **Linux / Bash** scripts for installing build dependencies, configuring a Debug build, compiling KeePassXC, and running tests.
- A repeatable workflow that can also be used by **AI coding agents running in Linux sandboxes**.

## Bash scripts

The Linux scripts are in [`scripts/Bash/`](scripts/Bash/).

| Script | Purpose |
|---|---|
| `install-linux-build-deps.sh` | Installs the Linux build dependencies with `apt`. |
| `build-debug.sh` | Configures and builds KeePassXC in Debug mode with Ninja/CMake. |
| `run-tests.sh` | Runs the reliable non-GUI tests, with optional best-effort GUI tests. |

For complete Linux/WSL2 and AI-agent instructions, see [`scripts/Bash/README.md`](scripts/Bash/README.md).

## Windows scripts

The PowerShell scripts are intended for the Windows development environment and can be used to configure and build KeePassXC with the Windows toolchain.

## AI coding-agent workflow

A Linux-based coding agent can use the Bash scripts to establish a consistent build/test environment:

```bash
sudo ./scripts/Bash/install-linux-build-deps.sh
./scripts/Bash/build-debug.sh .
./scripts/Bash/run-tests.sh ./build-debug
```

This allows an agent to make source changes, compile KeePassXC, inspect compiler errors, and run automated tests without requiring the Windows/MSVC environment.

GUI tests under Xvfb are optional and best effort. A headless Linux environment cannot reproduce Windows screen-reader behavior.

## Accessibility testing

Automated Linux testing is useful for catching build problems, compiler errors, regressions, and many functional test failures.

For accessibility work, the final validation should be performed on the Windows build with the intended screen reader. In particular, Linux/WSL2 testing does not replace real Windows + JAWS testing.

## Repository relationship

The KeePassXC source code lives in the upstream project:

https://github.com/keepassxreboot/keepassxc

This repository contains scripts and documentation intended to make development, testing, and AI-assisted development easier.
