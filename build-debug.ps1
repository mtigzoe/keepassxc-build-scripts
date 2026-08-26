[CmdletBinding()]
param(
    # Expected layout (all sibling folders under one parent):
    #   <parent>\keepassxc\   <- this script's default location
    #   <parent>\vcpkg\
    #   <parent>\ruby\        <- created automatically if needed
    # Override any of these to point elsewhere.
    [string]$Repo = (Join-Path (Split-Path -Parent $PSScriptRoot) "keepassxc"),
    [string]$VcpkgRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "vcpkg"),
    [string]$RubyRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "ruby"),

    # Left blank to auto-detect via vswhere.exe. Override to force a
    # specific Visual Studio installation's Launch-VsDevShell.ps1.
    [string]$VsDevShell = "",

    [string]$WindowsSdkRoot = "C:\Program Files (x86)\Windows Kits\10",

    # Left blank to auto-detect the newest installed SDK version.
    [string]$WindowsSdkVersion = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# KeePassXC Windows Debug Build
# Visual Studio + Ninja + vcpkg + Qt + Asciidoctor
# ============================================================


# ============================================================
# Locate Visual Studio Developer Shell
# ============================================================

if (-not $VsDevShell) {

    $VsWhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"

    if (-not (Test-Path $VsWhere)) {
        throw "vswhere.exe was not found: $VsWhere`nPass -VsDevShell explicitly if Visual Studio is installed in a non-standard way."
    }

    $VsInstallPath = & $VsWhere -latest -prerelease -products * -property installationPath

    if (-not $VsInstallPath) {
        throw "vswhere.exe could not find any Visual Studio installation."
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

# Visual Studio can modify VCPKG_ROOT.
# Set it again after loading the VS environment.
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


# ------------------------------------------------------------
# Install Qt if Qt6Config.cmake is missing
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Install windeployqt feature if missing
# ------------------------------------------------------------

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


# ============================================================
# Verify Qt
# ============================================================

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


# Add Qt tools to PATH.
$env:PATH = "$QtToolsBin;$env:PATH"


Write-Host ""
Write-Host "windeployqt version:"

& $WinDeployQt --version


# ============================================================
# Check Asciidoctor
# ============================================================
#
# KeePassXC's docs/CMakeLists.txt requires the 'asciidoctor'
# command to be on PATH (KPXC_FEATURE_DOCS, default ON).
# Asciidoctor is a Ruby gem, so this needs a Ruby interpreter.
#
# The official KeePassXC Windows build wiki recommends:
#   1. Install Ruby *without* Devkit (RubyInstaller for Windows)
#   2. gem install asciidoctor
# The Devkit/MSYS2 toolchain is not needed because asciidoctor
# is pure Ruby with no native C extensions to compile.
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Checking Asciidoctor..."
Write-Host "============================================================"

$RubyBin        = "$RubyRoot\bin"
$RubyExe        = "$RubyBin\ruby.exe"
$GemExe         = "$RubyBin\gem.cmd"
$AsciidoctorBat = "$RubyBin\asciidoctor.bat"

$ExistingAsciidoctor = Get-Command asciidoctor -ErrorAction SilentlyContinue

if ($ExistingAsciidoctor) {

    Write-Host ""
    Write-Host "asciidoctor is already available on PATH:"
    Write-Host $ExistingAsciidoctor.Source

} else {

    # ------------------------------------------------------------
    # Install Ruby (without Devkit) if not already present
    # ------------------------------------------------------------

    if (-not (Test-Path $RubyExe)) {

        Write-Host ""
        Write-Host "Ruby was not found: $RubyExe"
        Write-Host "Looking up the latest RubyInstaller (without Devkit, x64)..."
        Write-Host ""

        $ReleaseInfo = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/oneclick/rubyinstaller2/releases/latest" `
            -UseBasicParsing

        # Devkit installer assets are named "rubyinstaller-devkit-...-x64.exe".
        # Requiring a digit right after "rubyinstaller-" excludes those,
        # and requiring the "-x64.exe" suffix excludes the arm/x86 builds
        # and the .7z / .asc assets.
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

        Write-Host ""
        Write-Host "Installing Ruby to $RubyRoot ..."
        Write-Host "(Private install: no file associations, no system-wide PATH change.)"
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

    # Add Ruby's bin directory to PATH for this session, so 'gem'
    # works below and so CMake's find_program(asciidoctor) can
    # locate it during configuration later in this script.
    $env:PATH = "$RubyBin;$env:PATH"


    # ------------------------------------------------------------
    # Install the asciidoctor gem if missing
    # ------------------------------------------------------------

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


# ============================================================
# Verify Asciidoctor
# ============================================================

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
# Remove previous build
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Removing previous build directory..."
Write-Host "============================================================"

if (Test-Path ".\build") {
    Remove-Item ".\build" -Recurse -Force
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
