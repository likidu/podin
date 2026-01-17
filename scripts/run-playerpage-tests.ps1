<#
.SYNOPSIS
    Builds and runs the PlayerPage QtTest harness.
.USAGE
    pwsh scripts/run-playerpage-tests.ps1
    pwsh scripts/run-playerpage-tests.ps1 -QtSdkRoot "C:\Symbian\QtSDK" -Clean
.NOTES
    Relies on the Qt Simulator toolchain (MinGW) shipped with the Symbian Qt SDK.
#>
param(
    [ValidateNotNullOrEmpty()][string]$QtSdkRoot = 'C:\Symbian\QtSDK',
    [string]$QmakePath,
    [string]$MakePath,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$message) { Write-Host "[INFO] $message" -ForegroundColor Cyan }
function Write-Warn([string]$message) { Write-Host "[WARN] $message" -ForegroundColor Yellow }
function Write-Err([string]$message)  { Write-Host "[ERR ] $message" -ForegroundColor Red }

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
    $testDir = Join-Path $repoRoot 'tests'
    $playerTestDir = Join-Path $testDir 'playerpage'
    if (-not (Test-Path -LiteralPath $playerTestDir)) {
        throw ("PlayerPage test directory not found at {0}" -f $playerTestDir)
    }

    $proFile = Join-Path $playerTestDir 'playerpage.pro'
    if (-not (Test-Path -LiteralPath $proFile)) {
        throw ("qmake project file missing at {0}" -f $proFile)
    }

    $qtSdkRootFull = [System.IO.Path]::GetFullPath($QtSdkRoot)
    if (-not (Test-Path -LiteralPath $qtSdkRootFull)) {
        throw ("Qt SDK root not found at {0}" -f $qtSdkRootFull)
    }

    if (-not $QmakePath) {
        $QmakePath = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\bin\qmake.exe'
    }
    if (-not (Test-Path -LiteralPath $QmakePath)) {
        throw ("qmake.exe not found at {0}. Pass -QmakePath to override." -f $QmakePath)
    }

    if (-not $MakePath) {
        $MakePath = Join-Path $qtSdkRootFull 'mingw\bin\mingw32-make.exe'
        if (-not (Test-Path -LiteralPath $MakePath)) {
            $makeCmd = Get-Command 'mingw32-make.exe' -ErrorAction SilentlyContinue
            if ($makeCmd) {
                $MakePath = $makeCmd.Source
            }
        }
    }
    if (-not $MakePath -or -not (Test-Path -LiteralPath $MakePath)) {
        throw 'mingw32-make.exe not found. Pass -MakePath to point at your MinGW make.'
    }

    $simRoot = Join-Path $qtSdkRootFull 'Simulator'
    if (Test-Path -LiteralPath $simRoot) {
        $env:QTSIMULATOR_ROOT = (Resolve-Path $simRoot).Path
    } else {
        Write-Warn ("Simulator root not found at {0}; ensure com/nokia imports are discoverable." -f $simRoot)
    }

    $pathPrefixes = New-Object System.Collections.Generic.List[string]
    $qmakeBin = Split-Path -Parent $QmakePath
    $makeBin = Split-Path -Parent $MakePath
    if ($qmakeBin) { $pathPrefixes.Add($qmakeBin) }
    if ($makeBin) { $pathPrefixes.Add($makeBin) }
    $qtBin = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\bin'
    if (Test-Path -LiteralPath $qtBin) { $pathPrefixes.Add($qtBin) }
    $mobilityBin = Join-Path $qtSdkRootFull 'Simulator\QtMobility\mingw\bin'
    if (Test-Path -LiteralPath $mobilityBin) { $pathPrefixes.Add($mobilityBin) }
    $qtPhononBin = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\plugins\phonon_backend'
    if (Test-Path -LiteralPath $qtPhononBin) { $pathPrefixes.Add($qtPhononBin) }
    $qtImportMultimedia = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\imports\QtMultimediaKit'
    if (Test-Path -LiteralPath $qtImportMultimedia) { $pathPrefixes.Add($qtImportMultimedia) }
    $mingwBin = Join-Path $qtSdkRootFull 'mingw\bin'
    if (Test-Path -LiteralPath $mingwBin) { $pathPrefixes.Add($mingwBin) }
    $uniquePrefixes = $pathPrefixes | Select-Object -Unique
    if ($uniquePrefixes.Count -gt 0) {
        $env:PATH = ([string]::Join(';', $uniquePrefixes) + ';' + $env:PATH)
    }

    $qmlImportRoots = New-Object System.Collections.Generic.List[string]
    $qmlImportRoots.Add((Join-Path $repoRoot 'qml'))
    $qtImports = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\imports'
    if (Test-Path -LiteralPath $qtImports) { $qmlImportRoots.Add($qtImports) }
    $mobilityImports = Join-Path $qtSdkRootFull 'Simulator\QtMobility\mingw\imports'
    if (Test-Path -LiteralPath $mobilityImports) { $qmlImportRoots.Add($mobilityImports) }
    $env:QML_IMPORT_PATH = [string]::Join(';', ($qmlImportRoots | Select-Object -Unique))

    $qtPluginDirs = @()
    $qtPluginDir = Join-Path $qtSdkRootFull 'Simulator\Qt\mingw\plugins'
    if (Test-Path -LiteralPath $qtPluginDir) { $qtPluginDirs += $qtPluginDir }
    $mobilityPluginDir = Join-Path $qtSdkRootFull 'Simulator\QtMobility\mingw\plugins'
    if (Test-Path -LiteralPath $mobilityPluginDir) { $qtPluginDirs += $mobilityPluginDir }
    if ($qtPluginDirs.Count -gt 0) {
        $env:QT_PLUGIN_PATH = [string]::Join(';', $qtPluginDirs)
    }

    $buildRoot = Join-Path $repoRoot 'build-tests'
    if (-not (Test-Path -LiteralPath $buildRoot)) {
        New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
    }
    $buildDir = Join-Path $buildRoot 'playerpage'
    if ($Clean -and (Test-Path -LiteralPath $buildDir)) {
        Write-Info ("Cleaning build directory {0}" -f $buildDir)
        Remove-Item -LiteralPath $buildDir -Recurse -Force
    }
    if (-not (Test-Path -LiteralPath $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    }

    Push-Location $buildDir
    try {
        $qmakeArgs = @($proFile)
        Write-Info ("Running qmake: {0} {1}" -f $QmakePath, [string]::Join(' ', $qmakeArgs))
        & $QmakePath @qmakeArgs
        if ($LASTEXITCODE -ne 0) {
            throw ("qmake failed with exit code {0}" -f $LASTEXITCODE)
        }

        $makeArgs = @()
        if ($Clean) { $makeArgs += 'clean' }
        $makeArgs += 'all'
        Write-Info ("Running mingw32-make: {0} {1}" -f $MakePath, [string]::Join(' ', $makeArgs))
        & $MakePath @makeArgs
        if ($LASTEXITCODE -ne 0) {
            throw ("mingw32-make failed with exit code {0}" -f $LASTEXITCODE)
        }
    }
    finally {
        Pop-Location
    }

    $exeCandidates = @(
        (Join-Path $buildDir 'playerpage-test.exe'),
        (Join-Path $buildDir 'release\playerpage-test.exe'),
        (Join-Path $buildDir 'debug\playerpage-test.exe')
    )
    $testExe = $exeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $testExe) {
        throw ("Test executable not found. Looked in: {0}" -f ([string]::Join(', ', $exeCandidates)))
    }

    Write-Info ("Running tests via {0}" -f $testExe)
    & $testExe
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        throw ("playerpage-test reported failures (exit code {0})." -f $exit)
    }
    Write-Info 'PlayerPage tests passed.'
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
