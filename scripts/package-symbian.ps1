<#
.SYNOPSIS
    Packages the locally staged Symbian build output into a self-signed SIS file.
.USAGE
    pwsh scripts/package-symbian.ps1 -Config Release -Arch armv5
    pwsh scripts/package-symbian.ps1 -Config Debug -Arch armv6 -SymbianSdkRoot "C:\Symbian\QtSDK\Symbian\SDKs\SymbianSR1Qt474"
.NOTES
    Expects build-symbian/<arch>-<config> to contain Podin.exe and related artifacts.
#>
param(
    [ValidateNotNullOrEmpty()][string]$QtSdkRoot = 'C:\Symbian\QtSDK',
    [string]$SymbianSdkRoot,
    [ValidateSet('Debug','Release')][string]$Config = 'Debug',
    [ValidateSet('armv5','armv6')][string]$Arch = 'armv5',
    [string]$CertPath,
    [string]$KeyPath,
    [string]$CertPassword = 'podinpass',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$message) { Write-Host "[INFO] $message" -ForegroundColor Cyan }
function Write-Warn([string]$message) { Write-Host "[WARN] $message" -ForegroundColor Yellow }
function Write-Err([string]$message)  { Write-Host "[ERR ] $message" -ForegroundColor Red }

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path

    if (-not $SymbianSdkRoot) {
        $SymbianSdkRoot = Join-Path $QtSdkRoot 'Symbian\SDKs\SymbianSR1Qt474'
    }
    $SymbianSdkRoot = [System.IO.Path]::GetFullPath($SymbianSdkRoot)

    if (-not (Test-Path -LiteralPath $SymbianSdkRoot)) {
        throw ("Symbian SDK root not found at {0}" -f $SymbianSdkRoot)
    }

    $variantDir = if ($Config -ieq 'Debug') { 'udeb' } else { 'urel' }
    $configLower = $Config.ToLowerInvariant()
    $localOutRoot = Join-Path $repoRoot 'build-symbian'
    $localOutDir = Join-Path $localOutRoot ("{0}-{1}" -f $Arch, $configLower)

    if (-not (Test-Path -LiteralPath $localOutDir)) {
        throw ("Local build output not found at {0}. Run build-symbian.ps1 first." -f $localOutDir)
    }

    $exePath = Join-Path $localOutDir 'Podin.exe'
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw ("Executable not found at {0}. Build output missing." -f $exePath)
    }

    $sdkReleaseDir = Join-Path (Join-Path (Join-Path $SymbianSdkRoot 'epoc32\release') $Arch) $variantDir
    $sdkResource = Join-Path $SymbianSdkRoot 'epoc32\data\z\resource\apps\Podin.rsc'
    $sdkReg = Join-Path $SymbianSdkRoot 'epoc32\data\z\private\10003a3f\import\apps\Podin_reg.rsc'

    # Copy additional artifacts from SDK release if present
    if (Test-Path -LiteralPath $sdkReleaseDir) {
        $sdkArtifacts = Get-ChildItem -LiteralPath $sdkReleaseDir -Filter 'Podin*' -ErrorAction SilentlyContinue
        if ($sdkArtifacts) {
            foreach ($item in $sdkArtifacts) {
                Copy-Item -LiteralPath $item.FullName -Destination $localOutDir -Force
            }
            Write-Info ("Synced {0} artifact(s) from SDK release dir" -f $sdkArtifacts.Count)
        }
    }

    foreach ($resourcePath in @($sdkResource, $sdkReg)) {
        if (Test-Path -LiteralPath $resourcePath) {
            Copy-Item -LiteralPath $resourcePath -Destination $localOutDir -Force
        } else {
            Write-Warn ("Resource file missing: {0}" -f $resourcePath)
        }
    }

    $localPkg = Join-Path $localOutDir 'Podin_local.pkg'
    $pkgTemplatePath = Join-Path $repoRoot 'Podin_template.pkg'
    if (-not (Test-Path -LiteralPath $pkgTemplatePath)) {
        throw ("Package template not found at {0}" -f $pkgTemplatePath)
    }

    $pkgContent = Get-Content -Raw -LiteralPath $pkgTemplatePath
    $pkgContent = $pkgContent.Replace('$(PLATFORM)', $Arch).Replace('$(TARGET)', $variantDir)

    $sdkForward = ($SymbianSdkRoot -replace '\\','/').TrimEnd('/')
    $localForward = ($localOutDir -replace '\\','/').TrimEnd('/')

    $pkgContent = $pkgContent.Replace("$sdkForward/epoc32/release/$Arch/$variantDir/Podin.exe", "$localForward/Podin.exe")
    $pkgContent = $pkgContent.Replace("$sdkForward/epoc32/data/z/resource/apps/Podin.rsc", "$localForward/Podin.rsc")
    $pkgContent = $pkgContent.Replace("$sdkForward/epoc32/data/z/private/10003a3f/import/apps/Podin_reg.rsc", "$localForward/Podin_reg.rsc")

    Set-Content -LiteralPath $localPkg -Value $pkgContent -Encoding UTF8

    $makesis = Join-Path $SymbianSdkRoot 'epoc32\tools\makesis.exe'
    if (-not (Test-Path -LiteralPath $makesis)) {
        throw ("makesis.exe not found at {0}" -f $makesis)
    }

    $unsignedSis = Join-Path $localOutDir 'Podin_unsigned.sis'
    & $makesis $localPkg $unsignedSis
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $unsignedSis)) {
        throw "makesis failed with exit code $LASTEXITCODE"
    }
    Write-Info ("Unsigned SIS created at {0}" -f $unsignedSis)

    $signsis = Join-Path $SymbianSdkRoot 'epoc32\tools\signsis.exe'
    $makekeys = Join-Path $SymbianSdkRoot 'epoc32\tools\makekeys.exe'
    if (-not (Test-Path -LiteralPath $signsis)) {
        throw ("signsis.exe not found at {0}" -f $signsis)
    }
    if (-not (Test-Path -LiteralPath $makekeys)) {
        throw ("makekeys.exe not found at {0}" -f $makekeys)
    }

    if (-not $CertPath -or -not $KeyPath) {
        $certRoot = Join-Path $localOutRoot 'certs'
        if (-not (Test-Path -LiteralPath $certRoot)) {
            New-Item -ItemType Directory -Path $certRoot -Force | Out-Null
        }
        if (-not $CertPath) { $CertPath = Join-Path $certRoot 'PodinSelfSigned.cer' }
        if (-not $KeyPath)  { $KeyPath  = Join-Path $certRoot 'PodinSelfSigned.key' }
    }

    if ($Force -or -not (Test-Path -LiteralPath $CertPath) -or -not (Test-Path -LiteralPath $KeyPath)) {
        Write-Info ("Generating self-signed certificate at {0}" -f $CertPath)
        & $makekeys '-cert' '-password' $CertPassword '-len' 2048 '-dname' 'CN=PodinSelfSigned' $KeyPath $CertPath
        if ($LASTEXITCODE -ne 0) {
            throw "makekeys failed with exit code $LASTEXITCODE"
        }
    }

    $finalSis = Join-Path $localOutDir 'Podin_selfsigned.sis'
    & $signsis $unsignedSis $finalSis $CertPath $KeyPath $CertPassword
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $finalSis)) {
        throw "signsis failed with exit code $LASTEXITCODE"
    }

    Write-Info ("Self-signed SIS created at {0}" -f $finalSis)
    Write-Info "Packaging complete."
}
catch {
    Write-Error $_
    exit 1
}
