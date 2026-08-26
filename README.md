# keepassxc-ps1

PowerShell scripts for building and testing the [KeePassXC](https://github.com/keepassxreboot/keepassxc) source repository on Windows.

## What this repository is for

This repository contains PowerShell automation scripts that are intended to be used **with a local KeePassXC source checkout**. The scripts are not a replacement for the KeePassXC source repository; they make the Windows build and test process easier to run.

KeePassXC source repository:

- [KeePassXC on GitHub](https://github.com/keepassxreboot/keepassxc)

If you are working from a fork, the script can be used with your local fork as well.

## Requirements

- Windows 10 or Windows 11
- Visual Studio with C++ build tools
- Windows SDK
- CMake
- Ninja
- Git
- vcpkg
- Qt 6 through vcpkg
- Asciidoctor for documentation generation

The build scripts are designed to use the Qt installation managed by vcpkg. The Qt Online Installer is not required for this workflow.

## Recommended directory layout

Keep the KeePassXC source repository and this repository in the same parent directory. For example:

```text
keepassxc-repo/
├── keepassxc/
│   └── ... KeePassXC source files ...
├── vcpkg/
│   └── ... vcpkg files ...
└── keepassxc-ps1/
    ├── build-debug.ps1
    └── README.md
```

The exact layout can depend on the configuration used by the PowerShell script.

## Usage

First, clone or otherwise obtain the [KeePassXC repository](https://github.com/keepassxreboot/keepassxc) and prepare its dependencies.

Then open PowerShell and run the appropriate script from this repository.

For example:

```powershell
cd C:\path\to\keepassxc-ps1
powershell -ExecutionPolicy Bypass -File .\build-debug.ps1
.\build-debug.ps1
```

The script is intended to configure, build, and test the KeePassXC source checkout. It can automate tasks such as:

1. Loading the Visual Studio x64 development environment.
2. Checking the MSVC, Ninja, and Windows SDK tools.
3. Configuring vcpkg.
4. Installing or checking the required Qt packages.
5. Installing or checking `windeployqt`.
6. Configuring KeePassXC with CMake.
7. Building the Debug version.
8. Finding and launching `keepassxc.exe`.

## KeePassXC fork

If you are developing on a fork, make your changes in your fork and use the local checkout with the PowerShell scripts. For example, a `develop` branch can be built without changing the scripts' purpose: the scripts operate on the KeePassXC source tree that they are configured to use.

## Qt

The build workflow uses Qt provided by vcpkg. In a typical vcpkg installation, the Qt files are under:

```text
vcpkg\installed\x64-windows\
```

The deployment tool is expected at a location similar to:

```text
vcpkg\installed\x64-windows\tools\Qt6\bin\windeployqt.exe
```

The Qt Online Installer is not required when the necessary Qt packages are available through vcpkg.

## Build output

A Debug build normally creates a build directory inside the KeePassXC source tree:

```text
keepassxc\build\
```

The resulting executable is `keepassxc.exe`.

## Two ways to get it cleanly:

**Rerun single-threaded** so nothing interleaves and the failure is right at the bottom:
```powershell
cmake --build build --parallel 1
```

**Or capture everything to a file and grep for the error**, keeping full parallelism:
```powershell
cmake --build build --parallel *> build-log.txt
Select-String -Path build-log.txt -Pattern "error"
```

```
cmake --build build --parallel 1 *> build-log.txt
Select-String -Path build-log.txt -Pattern "error" -Context 0,3
```

## Purpose

The goal of this repository is to make repeated KeePassXC Windows development builds easier: instead of entering many PowerShell commands manually, run the appropriate script and let it check and configure the build environment.

## License

This repository is provided under the MIT License.
