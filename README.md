# keepassxc-ps1

Yes. That would be a useful small repository: **`keepassxc-ps1`** containing the automated Windows build script and clear instructions.

I would structure it like this:

```text
keepassxc-ps1/
├── build-debug.ps1
├── README.md
└── LICENSE
```

### `build-debug.ps1`

The script we just created would be the main file. I would make two small improvements before publishing it:

* Don't hard-code your username/path.
* Automatically locate the KeePassXC repository and vcpkg when possible.
* Keep the Visual Studio 2026 and Windows SDK paths configurable.
* Check for `windeployqt` before rebuilding anything.
* Give clear error messages if a prerequisite is missing.

### `README.md`

Something like:

```markdown
# KeePassXC Windows Build Script

PowerShell automation for building KeePassXC from source on Windows using:

- Visual Studio
- MSVC
- Ninja
- CMake
- vcpkg
- Qt 6
- windeployqt

## Requirements

- Windows 10/11
- Visual Studio 2026 Community or compatible Visual Studio installation
- CMake
- Ninja
- Git
- vcpkg
- Windows SDK

The script installs the required Qt packages through vcpkg.

You do not need to install the Qt Online Installer.

## Repository layout

The script expects:

    keepassxc-repo/
    ├── keepassxc/
    ├── vcpkg/
    └── build-debug.ps1

## Usage

Open PowerShell and run:

    cd C:\Users\<username>\Personal_Coding\keepassxc-repo

Then:

    .\build-debug.ps1

The script will:

1. Load the Visual Studio x64 build environment.
2. Check MSVC, Ninja, RC, and MT.
3. Check the Windows SDK.
4. Configure vcpkg.
5. Install Qt through vcpkg if necessary.
6. Install the Qt `windeployqt` feature if necessary.
7. Configure KeePassXC with CMake.
8. Build the Debug version.
9. Locate `keepassxc.exe`.
10. Launch KeePassXC.

## Qt

The script uses the Qt installation managed by vcpkg:

    vcpkg\installed\x64-windows\

It does not require the Qt Online Installer.

## Build directory

The script creates:

    keepassxc\build\

The existing build directory is removed before configuring a clean Debug build.

## License

This script is provided under the MIT License.
```

One important point: **don't publish your current script unchanged**, because it contains your personal path:

```text
C:\Users\<user>\keepassxc
```

For a public GitHub repository, I would change that to automatically determine the repository location, e.g. based on `$PSScriptRoot`.

That would make `keepassxc-ps1` usable by other KeePassXC developers without editing the script.
