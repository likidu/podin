<#
Inspects the simulator runtime directory for DLL/EXE compatibility:
- Detects PE machine (x86/x64) from headers
- Guesses toolchain (MinGW vs MSVC) from imported runtime DLLs
- Verifies Qt Debug/Release naming matches the selected -Config

Usage examples:
  # Check default build-simulator\debug
  ./scripts/inspect-sim-runtime.ps1 -Config Debug

  # Check an explicit output directory
  ./scripts/inspect-sim-runtime.ps1 -Config Release -Dir 'build-simulator\release'

Exit codes:
  0 = OK (no mismatches found)
  2 = Mismatch detected (bitness/toolchain/config)
  3 = Error (missing dir/files)
#>

Param(
    [ValidateSet('Debug','Release')]
    [string]$Config = 'Debug',
    [string]$Dir,
    # Expect the MinGW-built binaries used by the Qt Simulator
    [switch]$ExpectMinGW,
    # If set, prefer MSVC expectation over MinGW
    [switch]$ExpectMSVC,
    # When set, only enforce checks for QtNetwork + OpenSSL
    [switch]$OnlyNetSsl
)

$ErrorActionPreference = 'Stop'

function Get-PEInfo([string]$path)
{
    $fs = $null
    try
    {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $br = New-Object System.IO.BinaryReader($fs)
        # e_lfanew offset
        $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peOffset = $br.ReadInt32()
        $fs.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $sig = $br.ReadBytes(4)
        if (-not ($sig[0] -eq 0x50 -and $sig[1] -eq 0x45 -and $sig[2] -eq 0x00 -and $sig[3] -eq 0x00))
        {
            return [pscustomobject]@{ Path = $path; Machine = 'Unknown'; Bitness = 'Unknown'; }
        }
        # IMAGE_FILE_HEADER.Machine (WORD)
        $machine = $br.ReadUInt16()
        $bitness = switch ($machine)
        {
            0x014C
            { 'x86' 
            }
            0x8664
            { 'x64' 
            }
            default
            { 'Unknown' 
            }
        }
        return [pscustomobject]@{ Path = $path; Machine = ('0x{0:X4}' -f $machine); Bitness = $bitness }
    } finally
    {
        if ($fs)
        { $fs.Dispose() 
        }
    }
}

function Try-Run([string]$exe, [string[]]$args)
{
    try
    {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = ($args -join ' ')
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $p = [System.Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        $p.WaitForExit()
        return [pscustomobject]@{ Success = $true; ExitCode = $p.ExitCode; StdOut = $out; StdErr = $err }
    } catch
    {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; StdOut = ''; StdErr = $_.Exception.Message }
    }
}

function Get-ImportsGuess([string]$path, [string]$qtSdkRoot)
{
    # Prefer dumpbin/objdump if available, otherwise do a light heuristic on raw strings.
    $imports = ''
    $used = ''
    $dumpbin = (Get-Command dumpbin.exe -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($dumpbin)
    {
        $res = Try-Run $dumpbin.Path @('/imports', '"' + $path + '"')
        if ($res.Success -and $res.ExitCode -eq 0)
        { $imports = $res.StdOut; $used = 'dumpbin' 
        }
    }
    if (-not $imports)
    {
        $objdump = $null
        if ($qtSdkRoot)
        {
            $cand = Join-Path $qtSdkRoot 'mingw\bin\objdump.exe'
            if (Test-Path $cand)
            { $objdump = $cand 
            }
        }
        if (-not $objdump)
        { $objdump = (Get-Command objdump.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Path 
        }
        if ($objdump)
        {
            $res = Try-Run $objdump @('-p', '"' + $path + '"')
            if ($res.Success -and $res.ExitCode -eq 0)
            { $imports = $res.StdOut; $used = 'objdump' 
            }
        }
    }
    if (-not $imports)
    {
        # Heuristic: scan file bytes for import-like substrings
        try
        {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $text = [System.Text.Encoding]::ASCII.GetString($bytes)
            $imports = $text
            $used = 'strings'
        } catch
        {
            $imports = ''
        }
    }

    $tool = 'Unknown'
    if ($imports)
    {
        if ($imports -match '(?i)libgcc_s|libstdc\+\+-6\.dll|mingwm10\.dll')
        { $tool = 'MinGW' 
        }
        if ($imports -match '(?i)msvcr\d+\.dll|vcruntime\d+\.dll|api-ms-win-crt')
        { $tool = 'MSVC' 
        }
    }
    return [pscustomobject]@{ ImportsSource = $used; Toolchain = $tool }
}

function Get-FileVer([string]$path)
{
    try
    {
        $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        return @($vi.ProductVersion, $vi.FileVersion) -join ' / '
    } catch
    { return '' 
    }
}

try
{
    $repoRoot = Split-Path -Parent $PSScriptRoot
    if (-not $Dir)
    { $Dir = Join-Path $repoRoot (Join-Path 'build-simulator' $Config) 
    }
    if (-not (Test-Path $Dir))
    { throw "Directory not found: $Dir" 
    }

    if (-not $ExpectMinGW -and -not $ExpectMSVC)
    { $ExpectMinGW = $true 
    }

    $expects = @()
    if ($ExpectMinGW)
    { $expects += 'MinGW' 
    }
    if ($ExpectMSVC)
    { $expects += 'MSVC' 
    }
    $expectStr = if ($expects.Count -gt 0)
    { [string]::Join('/', $expects) 
    } else
    { 'Unknown' 
    }
    Write-Host "Inspecting: $Dir (Config=$Config, Expect=$expectStr)"

    $exe = Get-ChildItem -Path $Dir -File -Filter *.exe -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Podin\.exe' } | Select-Object -First 1
    if (-not $exe)
    { $exe = Get-ChildItem -Path $Dir -File -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1 
    }
    if (-not $exe)
    { throw "No .exe found in $Dir" 
    }

    $targets = @(
        'QtNetwork4.dll','QtNetworkd4.dll','QtNetwork4d.dll',
        'ssleay32.dll','libeay32.dll'
    )
    if (-not $OnlyNetSsl)
    {
        $targets += @('QtCore4.dll','QtCored4.dll','QtGui4.dll','QtGuid4.dll','QtDeclarative4.dll','QtDeclaratived4.dll')
    }
    $files = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $files.Add($exe)
    foreach ($n in $targets)
    {
        $p = Join-Path $Dir $n
        if (Test-Path $p)
        { $files.Add((Get-Item $p)) 
        }
    }

    $qtPairs = @()
    if (-not $OnlyNetSsl)
    {
        $qtPairs += @(
            @{ Base = 'QtCore'; Debug = @('QtCored4.dll'); Release = @('QtCore4.dll') },
            @{ Base = 'QtGui'; Debug = @('QtGuid4.dll'); Release = @('QtGui4.dll') },
            @{ Base = 'QtDeclarative'; Debug = @('QtDeclaratived4.dll'); Release = @('QtDeclarative4.dll') }
        )
    }
    $qtPairs += @(
        @{ Base = 'QtNetwork'; Debug = @('QtNetworkd4.dll','QtNetwork4d.dll'); Release = @('QtNetwork4.dll') }
    )

    $mismatches = New-Object System.Collections.Generic.List[string]

    # Determine exe bitness/toolchain
    $exeInfo = Get-PEInfo $exe.FullName
    $exeImp = Get-ImportsGuess $exe.FullName $null
    $exeVer = Get-FileVer $exe.FullName
    Write-Host ("App:   {0,-20} Bitness={1,-4} Toolchain={2,-6} Ver={3}" -f $exe.Name, $exeInfo.Bitness, $exeImp.Toolchain, $exeVer)

    # Expected toolchain
    $expectedTool = if ($ExpectMSVC)
    { 'MSVC' 
    } else
    { 'MinGW' 
    }

    foreach ($fi in $files)
    {
        if ($fi.FullName -eq $exe.FullName)
        { continue 
        }
        $pi = Get-PEInfo $fi.FullName
        $imp = Get-ImportsGuess $fi.FullName $null
        $ver = Get-FileVer $fi.FullName
        Write-Host ("DLL:   {0,-20} Bitness={1,-4} Toolchain={2,-6} Ver={3}" -f $fi.Name, $pi.Bitness, $imp.Toolchain, $ver)

        if ($pi.Bitness -ne $exeInfo.Bitness -and $pi.Bitness -ne 'Unknown' -and $exeInfo.Bitness -ne 'Unknown')
        {
            $mismatches.Add("Bitness mismatch: $($fi.Name) is $($pi.Bitness) but app is $($exeInfo.Bitness)")
        }
        if ($imp.Toolchain -ne 'Unknown' -and $exeImp.Toolchain -ne 'Unknown' -and $imp.Toolchain -ne $exeImp.Toolchain)
        {
            $mismatches.Add("Toolchain mismatch: $($fi.Name) is $($imp.Toolchain) but app is $($exeImp.Toolchain)")
        }
        if ($imp.Toolchain -ne 'Unknown' -and $imp.Toolchain -ne $expectedTool)
        {
            $mismatches.Add("Toolchain expectation: $($fi.Name) is $($imp.Toolchain), expected $expectedTool")
        }
    }

    # Check Qt Debug/Release presence matches -Config
    foreach ($pair in $qtPairs)
    {
        $haveDbg = $false; $haveRel = $false
        foreach ($n in $pair['Debug'])
        { if (Test-Path (Join-Path $Dir $n))
            { $haveDbg = $true 
            } 
        }
        foreach ($n in $pair['Release'])
        { if (Test-Path (Join-Path $Dir $n))
            { $haveRel = $true 
            } 
        }
        # If neither variant is staged locally, skip (likely using SDK PATH)
        if (-not $haveDbg -and -not $haveRel)
        { continue 
        }
        if ($Config -ieq 'Debug')
        {
            if (-not $haveDbg)
            { $mismatches.Add("Debug config: ${($pair['Base'])} has only release DLL staged, missing debug variant") 
            }
        } else
        {
            if (-not $haveRel)
            { $mismatches.Add("Release config: ${($pair['Base'])} has only debug DLL staged, missing release variant") 
            }
        }
    }

    if ($mismatches.Count -gt 0)
    {
        Write-Host "\nMismatches detected:" -ForegroundColor Yellow
        $mismatches | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
        exit 2
    } else
    {
        Write-Host "\nOK: No mismatches detected." -ForegroundColor Green
        exit 0
    }
} catch
{
    Write-Error $_
    exit 3
}
