# keepassxc-ps1

PowerShell automation for building and testing the [KeePassXC](https://github.com/keepassxreboot/keepassxc) source repository on Windows.

## What this repository is for

This repository provides PowerShell scripts that simplify a repeatable Windows Debug build of KeePassXC. The scripts operate on a separate local KeePassXC source checkout; they do not replace the KeePassXC source repository.

The workflow is designed for development and accessibility testing of a local KeePassXC checkout or fork.

## Requirements

- Windows 10 or Windows 11
- Visual Studio 2022 with the C++ build tools
- Windows SDK
- CMake
- Ninja
- Git
- vcpkg
- Qt 6 provided by vcpkg
- Internet access when vcpkg or the script needs to install dependencies

**The Qt Online Installer is not required.** Qt is obtained and managed through vcpkg.

Asciidoctor is also required by the KeePassXC documentation build. `build-debug.ps1` checks for it and can install a private Ruby runtime and the Asciidoctor gem when necessary.

## Recommended directory layout

The default configuration expects the repositories and tools as sibling directories:

```text
keepassxc-repo/
├── keepassxc/
│   └── ... KeePassXC source checkout ...
├── vcpkg/
│   └── ... vcpkg files ...
└── keepassxc-ps1/
    ├── build-debug.ps1
    └── README.md
```

The script can also be pointed at different locations with its path parameters.

## Build the Debug version

Open PowerShell and run:

```powershell
cd C:\path\to\keepassxc-ps1
.\build-debug.ps1
```

The script automatically:

1. Locates and loads the Visual Studio x64 development environment.
2. Checks MSVC, Ninja, `rc.exe`, and `mt.exe`.
3. Detects the newest installed Windows SDK and makes its libraries available to the linker.
4. Checks `vcpkg` and configures `VCPKG_ROOT`.
5. Installs/checks the Qt packages and `windeployqt` through vcpkg when necessary.
6. Checks or installs Asciidoctor using a private Ruby installation when necessary.
7. Configures KeePassXC with CMake and Ninja.
8. Builds KeePassXC as a Debug build.
9. Deploys the Debug Qt DLLs required by the executable.
10. Finds and launches `KeePassXC.exe`.

The Windows SDK library path is explicitly added to the linker environment. This includes `uuid.lib`, which is required by the Windows build.

## Clean build

By default, the script preserves the existing `build` directory so incremental builds are fast. To remove it and configure a completely fresh build, use:

```powershell
.\build-debug.ps1 -Clean
```

## Qt and Debug deployment

Qt is installed through vcpkg rather than the Qt Online Installer. A typical installation is under:

```text
vcpkg\installed\x64-windows\
```

vcpkg keeps Debug Qt DLLs separately under:

```text
vcpkg\installed\x64-windows\debug\bin\
```

The Debug build uses the vcpkg-provided Debug `windeployqt` wrapper so that dependencies such as `Qt6Cored.dll`, `Qt6Svgd.dll`, and `Qt6SvgWidgetsd.dll` are deployed correctly.

**You do not need to install or maintain a separate Qt installation.**

**You do not need a repository-specific `.bat` file.** The required `windeployqt` wrapper is supplied by vcpkg and is used by the PowerShell build script.

## Build output

The Debug build is normally created under:

```text
keepassxc\build\
```

The resulting executable is:

```text
keepassxc\build\src\KeePassXC.exe
```

`build-debug.ps1` launches the executable automatically after a successful build.

## Useful parameters

The script supports parameters for non-standard installations:

```powershell
.\build-debug.ps1 `
    -Repo "C:\path\to\keepassxc" `
    -VcpkgRoot "C:\path\to\vcpkg" `
    -RubyRoot "C:\path\to\ruby" `
    -VsWhere "C:\path\to\vswhere.exe" `
    -VsDevShell "C:\path\to\Launch-VsDevShell.ps1" `
    -WindowsSdkRoot "C:\path\to\Windows Kits\10" `
    -WindowsSdkVersion "10.0.28000.0"
```

All of these can normally be left blank for automatic detection:

- `Repo`, `VcpkgRoot`, `RubyRoot` are found as sibling directories of `keepassxc-ps1` (see [Recommended directory layout](#recommended-directory-layout)).
- `VsWhere` is found on `PATH`, then in the standard Visual Studio Installer location, and used to locate `VsDevShell`.
- `WindowsSdkRoot` is found via the registry, falling back to the standard install location.
- `WindowsSdkVersion` is the newest version installed under `WindowsSdkRoot`.

Pass any of them explicitly only if your machine has a non-standard install layout. `-VsDevShell` and `-WindowsSdkRoot`/`-WindowsSdkVersion` can also be used together to skip auto-detection entirely.

## KeePassXC fork

If you are developing an accessibility fix or another change in a KeePassXC fork, point `-Repo` at your local fork or use the expected sibling-directory layout. The script builds whichever KeePassXC source tree it is configured to use.

## Troubleshooting

For a clean reconfiguration, use:

```powershell
.\build-debug.ps1 -Clean
```

For build failures, the underlying CMake/Ninja output identifies the failing compilation, linking, or deployment step. A successful run ends with:

```text
Build completed.
KeePassXC has been launched.
```

Warnings emitted by Qt or optional KeePassXC components at application startup do not necessarily indicate a failed build.

## License

This repository is provided under the MIT License.
