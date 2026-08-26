[CmdletBinding()]
param(
    # Expected layout (all sibling folders under one parent):
    #   <parent>\keepassxc\   <- KeePassXC source checkout
    #   <parent>\vcpkg\
    #   <parent>\ruby\        <- created automatically if needed
    # Leave these blank to auto-detect based on the script's own
    # location, or override any of them to point elsewhere.
    [string]$Repo = "",
    [string]$VcpkgRoot = "",
    [string]$RubyRoot = "",

    # Left blank to auto-detect via vswhere.exe. Override to force a
    # specific Visual Studio installation's Launch-VsDevShell.ps1.
    [string]$VsDevShell = "",

    [string]$WindowsSdkRoot = "C:\Program Files (x86)\Windows Kits\10",

    # Left blank to auto-detect the newest installed SDK version.
    [string]$WindowsSdkVersion = "",

    # Preserve the existing build directory by default. Use -Clean when
    # you specifically want a completely fresh CMake configuration.
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# ============================================================
# KeePassXC Windows Debug Build
# Visual Studio + Ninja + vcpkg + Qt + Asciidoctor
# ============================================================

# ============================================================
# Resolve the script's own directory
# ============================================================
# $PSScriptRoot is not reliably populated inside a param() block's
# default value expressions (this depends on how the script was
# launched, e.g. 'powershell -File' vs '.\script.ps1'). Resolve it
# here instead, with fallbacks, after the param block has run.

$ScriptDir =
    if ($PSScriptRoot) { $PSScriptRoot }
    elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
    elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
    else { (Get-Location).Path }

$ParentDir = Split-Path -Parent $ScriptDir

if (-not $Repo)      { $Repo = Join-Path $ParentDir "keepassxc" }
if (-not $VcpkgRoot) { $VcpkgRoot = Join-Path $ParentDir "vcpkg" }
if (-not $RubyRoot)  { $RubyRoot = Join-Path $ParentDir "ruby" }

# ============================================================
# Validate paths
# ============================================================

if (-not (Test-Path $Repo -PathType Container)) {
    throw "KeePassXC repository was not found: $Repo"
}

if (-not (Test-Path $VcpkgRoot -PathType Container)) {
    throw "vcpkg directory was not found: $VcpkgRoot"
}

# ============================================================
# Locate Visual Studio Developer Shell
# ============================================================

if (-not $VsDevShell) {
    $VsWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"

    if (-not (Test-Path $VsWhere)) {
        throw "vswhere.exe was not found: $VsWhere`nPass -VsDevShell explicitly if Visual Studio is installed in a non-standard way."
    }

    # Restrict to actual Visual Studio SKUs (not "*") and require the
    # native C++ toolset component. This avoids other VS-Installer-
    # registered products that share the installer but aren't full VS
    # and don't ship Launch-VsDevShell.ps1 -- e.g. SQL Server Management
    # Studio is built on the VS shell and otherwise gets matched too.
    $VsInstallPath = & $VsWhere -latest -prerelease `
        -products Microsoft.VisualStudio.Product.Community `
                  Microsoft.VisualStudio.Product.Professional `
                  Microsoft.VisualStudio.Product.Enterprise `
                  Microsoft.VisualStudio.Product.BuildTools `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath

    if (-not $VsInstallPath) {
        throw "vswhere.exe could not find a Visual Studio installation with the C++ (VC.Tools.x86.x64) component. Install the 'Desktop development with C++' workload, or pass -VsDevShell explicitly."
    }

    $VsDevShell = Join-Path $VsInstallPath "Common7\Tools\Launch-VsDevShell.ps1"
}

# ============================================================
# Load Visual Studio environment
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Loading Visual Studio x64 environment..."
Write-Host "============================================================"

if (-not (Test-Path $VsDevShell)) {
    throw "Visual Studio Developer PowerShell script was not found: $VsDevShell"
}

Write-Host ""
Write-Host "Using:"
Write-Host $VsDevShell

& $VsDevShell -Arch amd64

if ($LASTEXITCODE -ne 0) {
    throw "Visual Studio Developer environment failed to load."
}

# Visual Studio can modify VCPKG_ROOT. Set it again after loading VS.
$env:VCPKG_ROOT = $VcpkgRoot

# ============================================================
# Check build tools
# ============================================================

Write-Host ""
Write-Host "Checking build tools..."

Write-Host ""
Write-Host "cl:"
where.exe cl

Write-Host ""
Write-Host "ninja:"
where.exe ninja

Write-Host ""
Write-Host "rc:"
where.exe rc

Write-Host ""
Write-Host "mt:"
where.exe mt

# ============================================================
# Configure Windows SDK
# ============================================================

Write-Host ""
Write-Host "Checking Windows SDK..."

if (-not $WindowsSdkVersion) {
    $DetectedSdkVersion = Get-ChildItem "$WindowsSdkRoot\bin" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1

    if (-not $DetectedSdkVersion) {
        throw "Could not auto-detect an installed Windows SDK version under $WindowsSdkRoot\bin. Pass -WindowsSdkVersion explicitly."
    }

    $WindowsSdkVersion = $DetectedSdkVersion.Name
}

Write-Host ""
Write-Host "Windows SDK version:"
Write-Host $WindowsSdkVersion

$env:WindowsSdkDir = "$WindowsSdkRoot\"
$env:WindowsSDKVersion = "$WindowsSdkVersion\"

$SdkBin = "$WindowsSdkRoot\bin\$WindowsSdkVersion\x64"
$SdkLib = "$WindowsSdkRoot\Lib\$WindowsSdkVersion\um\x64"

if (-not (Test-Path "$SdkBin\rc.exe")) {
    throw "rc.exe was not found: $SdkBin\rc.exe"
}

if (-not (Test-Path "$SdkBin\mt.exe")) {
    throw "mt.exe was not found: $SdkBin\mt.exe"
}

if (-not (Test-Path "$SdkLib\kernel32.lib")) {
    throw "kernel32.lib was not found: $SdkLib\kernel32.lib"
}

# Make sure Windows SDK tools are first in PATH.
$env:PATH = "$SdkBin;$env:PATH"

Write-Host "Windows SDK is OK."

# ============================================================
# Check vcpkg
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Checking vcpkg..."
Write-Host "============================================================"

Write-Host ""
Write-Host "VCPKG_ROOT:"
Write-Host $env:VCPKG_ROOT

$VcpkgExe = "$env:VCPKG_ROOT\vcpkg.exe"
$VcpkgToolchain = "$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake"

if (-not (Test-Path $VcpkgExe)) {
    throw "vcpkg.exe was not found: $VcpkgExe"
}

if (-not (Test-Path $VcpkgToolchain)) {
    throw "vcpkg CMake toolchain was not found: $VcpkgToolchain"
}

Write-Host "vcpkg is OK."

# ============================================================
# Check Qt
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Checking Qt..."
Write-Host "============================================================"

$QtRoot = "$env:VCPKG_ROOT\installed\x64-windows"
$QtDir = "$QtRoot\share\Qt6"
$QtConfig = "$QtDir\Qt6Config.cmake"
$QtToolsBin = "$QtRoot\tools\Qt6\bin"
$WinDeployQt = "$QtToolsBin\windeployqt.exe"

# Install Qt if Qt6Config.cmake is missing.
if (-not (Test-Path $QtConfig)) {
    Write-Host ""
    Write-Host "Qt6Config.cmake was not found."
    Write-Host "Installing Qt through vcpkg..."
    Write-Host ""

    & $VcpkgExe install qtbase:x64-windows

    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg failed to install qtbase."
    }
}

# KeePassXC requires windeployqt on Windows. vcpkg's feature may require
# rebuilding qtbase and related Qt packages, so --recurse is intentional.
if (-not (Test-Path $WinDeployQt)) {
    Write-Host ""
    Write-Host "windeployqt.exe is missing."
    Write-Host "Installing Qt windeployqt feature through vcpkg."
    Write-Host ""
    Write-Host "Qt may need to be rebuilt with the additional feature."
    Write-Host "This can take some time."
    Write-Host ""

    & $VcpkgExe install "qtbase[windeployqt]:x64-windows" --recurse

    if ($LASTEXITCODE -ne 0) {
        throw "vcpkg failed to install qtbase[windeployqt]."
    }
}

if (-not (Test-Path $QtConfig)) {
    throw "Qt6Config.cmake still cannot be found: $QtConfig"
}

if (-not (Test-Path $WinDeployQt)) {
    throw "windeployqt.exe still cannot be found: $WinDeployQt"
}

Write-Host ""
Write-Host "Qt6 found:"
Write-Host $QtConfig

Write-Host ""
Write-Host "windeployqt found:"
Write-Host $WinDeployQt

# Add Qt tools to PATH for CMake and this script.
$env:PATH = "$QtToolsBin;$env:PATH"

Write-Host ""
Write-Host "windeployqt version:"
& $WinDeployQt --version

if ($LASTEXITCODE -ne 0) {
    throw "windeployqt was found but failed to run."
}

# ============================================================
# Check Asciidoctor
# ============================================================
# KeePassXC's docs/CMakeLists.txt requires the 'asciidoctor'
# command to be available. Asciidoctor is a Ruby gem.
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Checking Asciidoctor..."
Write-Host "============================================================"

$RubyBin = "$RubyRoot\bin"
$RubyExe = "$RubyBin\ruby.exe"
$GemExe = "$RubyBin\gem.cmd"
$AsciidoctorBat = "$RubyBin\asciidoctor.bat"

$ExistingAsciidoctor = Get-Command asciidoctor -ErrorAction SilentlyContinue

if ($ExistingAsciidoctor) {
    Write-Host ""
    Write-Host "asciidoctor is already available on PATH:"
    Write-Host $ExistingAsciidoctor.Source
} else {
    # Install a private Ruby runtime only when Asciidoctor is not already
    # available. This does not modify the system-wide PATH.
    if (-not (Test-Path $RubyExe)) {
        Write-Host ""
        Write-Host "Ruby was not found: $RubyExe"
        Write-Host "Looking up the latest RubyInstaller (x64, without Devkit)..."
        Write-Host ""

        $ReleaseInfo = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/oneclick/rubyinstaller2/releases/latest" `
            -UseBasicParsing

        $RubyAsset = $ReleaseInfo.assets |
            Where-Object { $_.name -match '^rubyinstaller-\d.*-x64\.exe$' } |
            Select-Object -First 1

        if ($null -eq $RubyAsset) {
            throw "Could not find a non-Devkit x64 RubyInstaller release asset."
        }

        $InstallerPath = Join-Path $env:TEMP $RubyAsset.name

        Write-Host "Downloading:"
        Write-Host $RubyAsset.browser_download_url

        Invoke-WebRequest `
            -Uri $RubyAsset.browser_download_url `
            -OutFile $InstallerPath `
            -UseBasicParsing

        # The download carries the internet Mark-of-the-Web. Unblocking
        # it here reduces (but doesn't guarantee removal of) a Windows
        # SmartScreen prompt on first run, since it's a fresh, low-
        # reputation binary as far as Windows is concerned.
        Unblock-File -Path $InstallerPath -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "Installing Ruby to $RubyRoot ..."
        Write-Host "Private install: no file associations and no system-wide PATH change."
        Write-Host ""
        Write-Host "If this appears to hang, check for a hidden Windows SmartScreen"
        Write-Host "or User Account Control prompt (Alt+Tab) and approve it."
        Write-Host ""

        $InstallArgs = @(
            "/VERYSILENT",
            "/SUPPRESSMSGBOXES",
            "/DIR=`"$RubyRoot`"",
            "/TASKS=noassocfiles,nomodpath"
        )

        $RubyInstall = Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -PassThru

        if ($RubyInstall.ExitCode -ne 0) {
            throw "RubyInstaller failed with exit code $($RubyInstall.ExitCode)."
        }
    }

    if (-not (Test-Path $RubyExe)) {
        throw "Ruby still cannot be found: $RubyExe"
    }

    Write-Host ""
    Write-Host "Ruby found:"
    Write-Host $RubyExe

    # Add Ruby to this PowerShell process only.
    $env:PATH = "$RubyBin;$env:PATH"

    if (-not (Test-Path $AsciidoctorBat)) {
        Write-Host ""
        Write-Host "Installing the asciidoctor gem..."
        Write-Host ""

        & $GemExe install asciidoctor --no-document

        if ($LASTEXITCODE -ne 0) {
            throw "gem failed to install asciidoctor."
        }
    }

    if (-not (Test-Path $AsciidoctorBat)) {
        throw "asciidoctor still cannot be found: $AsciidoctorBat"
    }

    Write-Host ""
    Write-Host "asciidoctor found:"
    Write-Host $AsciidoctorBat
}

# If an existing system Asciidoctor was found, no PATH modification is
# necessary. Otherwise RubyBin was added above.
Write-Host ""
Write-Host "asciidoctor version:"
& asciidoctor --version

if ($LASTEXITCODE -ne 0) {
    throw "asciidoctor was found but failed to run."
}

# ============================================================
# Enter KeePassXC repository
# ============================================================

Set-Location $Repo

Write-Host ""
Write-Host "Repository:"
Write-Host (Get-Location)

# ============================================================
# Clean build (optional)
# ============================================================

if ($Clean) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Removing previous build directory..."
    Write-Host "============================================================"

    if (Test-Path ".\build") {
        Remove-Item ".\build" -Recurse -Force
    }
} else {
    Write-Host ""
    Write-Host "Keeping existing build directory."
    Write-Host "Use -Clean for a completely fresh build."
}

# ============================================================
# Configure CMake
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Configuring KeePassXC..."
Write-Host "============================================================"

cmake -S . -B build `
    -G Ninja `
    -DCMAKE_BUILD_TYPE=Debug `
    -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
    -DQt6_DIR="$QtDir"

if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed."
}

# ============================================================
# Build KeePassXC
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Building KeePassXC..."
Write-Host "============================================================"

cmake --build build --parallel

if ($LASTEXITCODE -ne 0) {
    throw "KeePassXC build failed."
}

# ============================================================
# Find KeePassXC executable
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Build completed."
Write-Host "============================================================"

$KeePassXC = Get-ChildItem ".\build" `
    -Recurse `
    -Filter "keepassxc.exe" `
    -File `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($null -eq $KeePassXC) {
    throw "Could not find keepassxc.exe."
}

# ============================================================
# Launch KeePassXC
# ============================================================

Write-Host ""
Write-Host "KeePassXC executable:"
Write-Host $KeePassXC.FullName

Write-Host ""
Write-Host "Launching KeePassXC..."

Start-Process $KeePassXC.FullName

Write-Host ""
Write-Host "KeePassXC has been launched."
