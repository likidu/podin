<#
.SYNOPSIS
    Builds the Qt Simulator target using qmake and mingw32-make.
.USAGE
    pwsh scripts/build-simulator.ps1 -Config Debug
    pwsh scripts/build-simulator.ps1 -Config Release -Clean -UseDepDlls
.NOTES
    Override -QtBin and -MakeBin when the Qt SDK is installed elsewhere.
#>
param(
    [string]$QtBin = 'C:\Symbian\QtSDK\Simulator\Qt\mingw\bin',
    [string]$MakeBin = 'C:\Symbian\QtSDK\mingw\bin',
    [ValidateSet('Debug','Release')][string]$Config = 'Debug',
    [switch]$Clean,
    # When set, stage patched DLLs from deps/win32 instead of relying on the simulator runtime.
    [switch]$UseDepDlls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERR ] $msg" -ForegroundColor Red }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')
$buildRoot = Join-Path $root 'build-simulator'
$cfgLower = $Config.ToLower()
$buildDir = Join-Path $buildRoot $cfgLower
$proFile = Join-Path $root 'Podin.pro'

Write-Info "Root: $root"
Write-Info "Build: $buildDir"
Write-Info "QtBin: $QtBin"
Write-Info "MakeBin: $MakeBin"
Write-Info "Config: $Config"

if (-not (Test-Path $proFile)) {
    Write-Err "Missing .pro file at $proFile"
    exit 2
}

$qmake = Join-Path $QtBin 'qmake.exe'
if (-not (Test-Path $qmake)) {
    Write-Err ("qmake not found at {0}. Pass -QtBin to point to your Qt Simulator bin directory." -f $qmake)
    exit 3
}

$make = Join-Path $MakeBin 'mingw32-make.exe'
if (-not (Test-Path $make)) {
    Write-Err ("mingw32-make.exe not found at {0}. Pass -MakeBin to point to your MinGW bin." -f $make)
    exit 4
}

if ($Clean) {
    if (Test-Path $buildRoot) {
        Write-Info "Cleaning $buildRoot"
        Remove-Item -Recurse -Force -LiteralPath $buildRoot -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
}

# Ensure tools are on PATH (useful if DLLs are colocated)
$env:PATH = "$QtBin;$MakeBin;$env:PATH"

Push-Location $buildDir
try {
    Write-Info "Running qmake..."
    & $qmake $proFile -spec win32-g++ "CONFIG+=$Config" | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "qmake failed with exit code $LASTEXITCODE" }

    Write-Info "Building with mingw32-make..."
    & $make -j $env:NUMBER_OF_PROCESSORS | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "mingw32-make failed with exit code $LASTEXITCODE" }

    if (-not $UseDepDlls) {
        Write-Info ("Using simulator runtime from {0}; no DLL staging" -f $QtBin)

        $launcher = Join-Path $buildDir 'Podin.run.ps1'
        $legacyLauncher = Join-Path $buildDir 'Podin.run.cmd'
        if (Test-Path $legacyLauncher) {
            Remove-Item -LiteralPath $legacyLauncher -Force
        }

        $qtPluginsDir = Join-Path (Split-Path (Split-Path $QtBin -Parent) -Parent) 'plugins'

        $launcherLines = @(
            'param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ExtraArgs = @())'
            'Set-StrictMode -Version Latest'
            '$ErrorActionPreference = ''Stop'''
            '$exe = Join-Path $PSScriptRoot ''Podin.exe'''
            'if (-not (Test-Path -LiteralPath $exe)) {'
            '    Write-Error "Podin.exe not found next to this launcher."'
            '    exit 1'
            '}'
            ('$env:PATH = ''{0};'' + $env:PATH' -f $QtBin)
            ('[Environment]::SetEnvironmentVariable(''Path'', $env:PATH, ''Process'')')
        )

        if (Test-Path $qtPluginsDir) {
            $launcherLines += @(
                ('if (Test-Path -LiteralPath ''{0}'') {{' -f $qtPluginsDir)
                ('    $env:QT_PLUGIN_PATH = ''{0}''' -f $qtPluginsDir)
                ('    [Environment]::SetEnvironmentVariable(''QT_PLUGIN_PATH'', $env:QT_PLUGIN_PATH, ''Process'')')
                '}'
            )
        }

        $launcherLines += @(
            '$argsToPass = if ($ExtraArgs) { $ExtraArgs } else { @() }'
            '& $exe @argsToPass'
            'if ($LASTEXITCODE -ne 0) {'
            '    exit $LASTEXITCODE'
            '}'
        )

        Set-Content -LiteralPath $launcher -Value ($launcherLines -join "`r`n") -Encoding ASCII
        Write-Info ("Launcher created at {0}. Run it with pwsh to launch using the simulator runtime." -f $launcher)
    } else {
        Write-Info "Staging patched Qt/OpenSSL DLLs into build output"

        $depsRoot = Join-Path $root 'deps\win32\qt4-openssl'
        $cfgDir = if ($Config -ieq 'Release') { 'release' } else { 'debug' }
        $deps = Join-Path $depsRoot $cfgDir
        if (Test-Path $deps) {
            Write-Info ("Using dependencies from {0}" -f $deps)
            $qtDbgBase = @('QtCored4.dll','QtNetworkd4.dll')
            $qtRelBase = @('QtCore4.dll','QtNetwork4.dll')
            $openssl = @('libeay32.dll','ssleay32.dll')
            $names = if ($Config -ieq 'Release') { $qtRelBase + $openssl } else { $qtDbgBase + $openssl }
            foreach ($n in $names) {
                $src = Join-Path $deps $n
                if (Test-Path $src) {
                    Copy-Item -LiteralPath $src -Destination $buildDir -Force
                    Write-Info "  + $n"
                } else {
                    Write-Warn "  - Missing in deps: $n"
                }
            }
        } else {
            Write-Warn ("Deps folder not found at {0}. Place your patched Qt 4.7.4 + OpenSSL 1.0.2u DLLs there." -f $deps)
            $fallback = if ($Config -ieq 'Release') { @('QtCore4.dll','QtNetwork4.dll') } else { @('QtCored4.dll','QtNetworkd4.dll') }
            foreach ($dll in $fallback) {
                $srcDll = Join-Path $QtBin $dll
                if (Test-Path $srcDll) {
                    Copy-Item -LiteralPath $srcDll -Destination $buildDir -Force
                }
            }
        }
    }

    $exe = Join-Path $buildDir 'Podin.exe'
    if (Test-Path $exe) {
        Write-Info "Build succeeded: $exe"
    } else {
        Write-Warn ("Build completed but Podin.exe not found in {0}. Check qmake DESTDIR in .pro." -f $buildDir)
    }
}
finally {
    Pop-Location
}
