<#
.SYNOPSIS
    Builds Symbian binaries via qmake + make using RVCT 4.0.
.USAGE
    pwsh scripts/build-symbian.ps1 -Config Debug -Arch armv5 -Clean
    pwsh scripts/build-symbian.ps1 -Config Release -Arch armv6 -SymbianSdkRoot "C:\Symbian\QtSDK\Symbian\SDKs\SymbianSR1Qt474"
.NOTES
    Always uses the RVCT 4.0 toolchain provided by the selected SDK.
#>
param(
    [ValidateNotNullOrEmpty()][string]$QtSdkRoot = 'C:\Symbian\QtSDK',
    [string]$SymbianSdkRoot,
    [ValidateSet('Debug','Release')][string]$Config = 'Debug',
    [ValidateSet('armv5','armv6')][string]$Arch = 'armv5',
    [string]$QmakePath,
    [string]$MakePath,
    [switch]$Clean,
    [switch]$VerboseMake
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$message)
{ Write-Host "[INFO] $message" -ForegroundColor Cyan
}
function Write-Warn([string]$message)
{ Write-Host "[WARN] $message" -ForegroundColor Yellow
}
function Write-Err([string]$message)
{ Write-Host "[ERR ] $message" -ForegroundColor Red
}

function Get-EpocRoot([string]$sdkRoot)
{
    $fullPath = [System.IO.Path]::GetFullPath($sdkRoot)
    if ($fullPath.Length -lt 3 -or $fullPath[1] -ne ':')
    {
        throw 'Symbian SDK must live on a drive-rooted path such as C:\Symbian\QtSDK\Symbian\SDKs\SymbianSR1Qt474'
    }
    $tail = $fullPath.Substring(2)
    if (-not $tail.StartsWith('\'))
    { $tail = '\\' + $tail
    }
    if (-not $tail.EndsWith('\'))
    { $tail += '\\'
    }
    return $tail
}

function Add-ToPathFront([string[]]$paths)
{
    $valid = @()
    foreach ($path in $paths)
    {
        if ([string]::IsNullOrWhiteSpace($path))
        { continue
        }
        if (Test-Path -LiteralPath $path)
        { $valid += $path
        }
    }
    if ($valid.Count -gt 0)
    {
        $env:PATH = ([string]::Join(';', $valid) + ';' + $env:PATH)
    }
}

try
{
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
    $proFile = Join-Path $repoRoot 'Podin.pro'
    if (-not (Test-Path -LiteralPath $proFile))
    {
        throw ("Project file not found at {0}" -f $proFile)
    }

    if (-not $SymbianSdkRoot)
    {
        $SymbianSdkRoot = Join-Path $QtSdkRoot 'Symbian\SDKs\SymbianSR1Qt474'
    }
    $SymbianSdkRoot = [System.IO.Path]::GetFullPath($SymbianSdkRoot)
    if (-not (Test-Path -LiteralPath $SymbianSdkRoot))
    {
        throw ("Symbian SDK root not found at {0}" -f $SymbianSdkRoot)
    }

    $symbianBase = Split-Path -Parent (Split-Path -Parent $SymbianSdkRoot)
    $epocRoot = Get-EpocRoot $SymbianSdkRoot
    [Environment]::SetEnvironmentVariable('EPOCROOT', $epocRoot, 'Process')
    [Environment]::SetEnvironmentVariable('QTDIR', $SymbianSdkRoot, 'Process')

    $sbsHome = Join-Path $symbianBase 'tools\sbs'
    [Environment]::SetEnvironmentVariable('SBS_HOME', $sbsHome, 'Process')

    $sbsBat = Join-Path $sbsHome 'bin\sbs.bat'
    if (-not (Test-Path -LiteralPath $sbsBat))
    {
        throw ("sbs.bat not found at {0}" -f $sbsBat)
    }

    $localPython = Join-Path $sbsHome 'win32\python27\python.exe'
    if (Test-Path -LiteralPath $localPython)
    {
        [Environment]::SetEnvironmentVariable('SBS_PYTHON', $localPython, 'Process')
        Write-Info ("Using Raptor Python at {0}" -f $localPython)
    } else
    {
        Write-Warn ("Bundled Raptor Python missing at {0}; relying on python.exe on PATH" -f $localPython)
    }

    $pathsToPrepend = @(
        (Join-Path $SymbianSdkRoot 'bin')
        (Join-Path $SymbianSdkRoot 'epoc32\tools')
        (Join-Path $SymbianSdkRoot 'epoc32\gcc\bin')
        (Join-Path $symbianBase 'tools')
        (Join-Path $symbianBase 'tools\perl\bin')
        (Join-Path $symbianBase 'tools\sbs\bin')
        (Join-Path $symbianBase 'tools\gcce4')
        (Join-Path $symbianBase 'tools\gcce4\bin')
        (Join-Path $symbianBase 'tools\gcce4\arm-none-symbianelf\bin')
    )
    if ($env:RVCT40BIN)
    { $pathsToPrepend += $env:RVCT40BIN
    }

    Add-ToPathFront $pathsToPrepend

    if (-not $QmakePath)
    {
        $QmakePath = Join-Path $SymbianSdkRoot 'bin\qmake.exe'
    }
    if (-not (Test-Path -LiteralPath $QmakePath))
    {
        throw ("qmake.exe not found at {0}" -f $QmakePath)
    }

    if (-not $MakePath)
    {
        $MakePath = Join-Path $SymbianSdkRoot 'epoc32\tools\make.exe'
        if (-not (Test-Path -LiteralPath $MakePath))
        {
            $makeCmd = Get-Command 'make.exe' -ErrorAction SilentlyContinue
            if ($makeCmd)
            { $MakePath = $makeCmd.Source
            }
        }
    }
    if (-not $MakePath -or -not (Test-Path -LiteralPath $MakePath))
    {
        throw 'Unable to locate make.exe; pass -MakePath to point at your Symbian make tool.'
    }

    Add-ToPathFront @((Split-Path -Parent $MakePath))

    Write-Info ("Repo root: {0}" -f $repoRoot)
    Write-Info ("Symbian SDK root: {0}" -f $SymbianSdkRoot)
    Write-Info ("EPOCROOT: {0}" -f $epocRoot)
    Write-Info ("qmake: {0}" -f $QmakePath)
    Write-Info ("make: {0}" -f $MakePath)

    $configToken = if ($Config -ieq 'Debug')
    { 'CONFIG+=debug'
    } else
    { 'CONFIG+=release'
    }
    $variantDir = if ($Config -ieq 'Debug')
    { 'udeb'
    } else
    { 'urel'
    }
    $configLower = if ($Config -ieq 'Debug')
    { 'debug'
    } else
    { 'release'
    }
    $toolchainLabel = 'rvct4.0'
    $makeTarget = "{0}-{1}-{2}" -f $configLower, $Arch, $toolchainLabel
    $cleanTarget = "clean-{0}" -f $makeTarget
    $localOutRoot = Join-Path $repoRoot 'build-symbian'
    $localOutDir = Join-Path $localOutRoot ("{0}-{1}" -f $Arch, $configLower)

    if ($Clean -and (Test-Path -LiteralPath $localOutDir))
    {
        Write-Info ("Removing local output directory {0}" -f $localOutDir)
        Remove-Item -LiteralPath $localOutDir -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $localOutRoot))
    {
        New-Item -ItemType Directory -Path $localOutRoot -Force | Out-Null
    }

    Push-Location $repoRoot
    try
    {
        $mkspec = Join-Path $SymbianSdkRoot 'mkspecs\symbian-sbsv2'
        if (-not (Test-Path -LiteralPath $mkspec))
        {
            throw ("mkspec not found at {0}" -f $mkspec)
        }

        $qmakeArgs = @($proFile, '-r', '-spec', $mkspec, $configToken, '-after', 'OBJECTS_DIR=obj', 'MOC_DIR=moc', 'UI_DIR=ui', 'RCC_DIR=rcc')
        Write-Info ("Running qmake: {0}" -f ([string]::Join(' ', $qmakeArgs)))
        & $QmakePath @qmakeArgs
        if ($LASTEXITCODE -ne 0)
        {
            throw ("qmake failed with exit code {0}" -f $LASTEXITCODE)
        }

        # Point SBS at the .bat launcher so make can find Raptor
        $makeOverrides = @("SBS=$sbsBat")

        if ($Clean)
        {
            Write-Info ("Running make {0}..." -f $cleanTarget)
            & $MakePath $cleanTarget '-w' @makeOverrides
            if ($LASTEXITCODE -ne 0)
            {
                throw ("make {0} failed with exit code {1}" -f $cleanTarget, $LASTEXITCODE)
            }
        }

        $makeArgs = @($makeTarget)
        if ($VerboseMake)
        { $makeArgs += '-d'
        }
        $makeArgs += '-w'
        $makeArgs += $makeOverrides
        Write-Info ("Running make: {0}" -f ([string]::Join(' ', $makeArgs)))
        & $MakePath @makeArgs
        if ($LASTEXITCODE -ne 0)
        {
            throw ("make {0} failed with exit code {1}" -f $makeTarget, $LASTEXITCODE)
        }
    } finally
    {
        Pop-Location
    }

    $releaseDir = Join-Path (Join-Path (Join-Path $SymbianSdkRoot 'epoc32\release') $Arch) $variantDir
    $exePath = Join-Path $releaseDir 'Podin.exe'

    if (-not (Test-Path -LiteralPath $localOutDir))
    {
        New-Item -ItemType Directory -Path $localOutDir -Force | Out-Null
    }

    $artifacts = Get-ChildItem -LiteralPath $releaseDir -Filter 'Podin*' -ErrorAction SilentlyContinue
    if ($artifacts)
    {
        foreach ($item in $artifacts)
        {
            Copy-Item -LiteralPath $item.FullName -Destination $localOutDir -Force
        }
        Write-Info ("Copied {0} artifact(s) into {1}" -f $artifacts.Count, $localOutDir)
    } else
    {
        Write-Warn ("No Podin* artifacts found under {0} to copy" -f $releaseDir)
    }

    $localExePath = Join-Path $localOutDir 'Podin.exe'
    if (Test-Path -LiteralPath $localExePath)
    {
        Write-Info ("Build succeeded. Executable staged at {0}" -f $localExePath)
    } elseif (Test-Path -LiteralPath $exePath)
    {
        Write-Warn ("Executable remained at SDK release path {0}; check copy step" -f $exePath)
    } else
    {
        Write-Warn ("Build completed but Podin.exe not found under {0}" -f $releaseDir)
    }

    exit 0
} catch
{
    Write-Error $_
    exit 1
}
