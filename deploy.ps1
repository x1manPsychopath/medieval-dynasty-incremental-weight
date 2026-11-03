<#
.SYNOPSIS
  Deploys the IncrementalWeight mod into a Medieval Dynasty install (Steam or Game Pass).
.PARAMETER Target     Auto (default), Steam, or GamePass.
.PARAMETER GamePath   Explicit game root (folder containing the Medieval Dynasty binaries).
.PARAMETER DryRun     Show what would be done without changing anything.
#>
[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Steam', 'GamePass')][string]$Target = 'Auto',
    [string]$GamePath,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$ModName = 'IncrementalWeight'
$Source = Join-Path $PSScriptRoot "src\$ModName"

function Write-Log([string]$Message) { Write-Verbose $Message; Write-Host $Message }

if (-not (Test-Path -LiteralPath (Join-Path $Source 'scripts\main.lua'))) {
    throw "Source mod not found or incomplete: $Source"
}

function Find-Binaries([string]$Root, [string]$Sub) {
    # Binaries live under <root>\<Game>\Binaries\<Sub> (UE layout).
    if (-not (Test-Path -LiteralPath $Root)) { return $null }
    Get-ChildItem -LiteralPath $Root -Directory -Recurse -Depth 3 -Filter $Sub -ErrorAction SilentlyContinue |
        Where-Object { $_.Parent.Name -eq 'Binaries' } | Select-Object -First 1
}

$candidates = @()
if ($GamePath) {
    if (-not (Test-Path -LiteralPath $GamePath)) { throw "GamePath does not exist: $GamePath" }
    foreach ($pair in @(@('GamePass', 'WinGDK'), @('Steam', 'Win64'))) {
        if ($Target -in @('Auto', $pair[0])) {
            $b = Find-Binaries $GamePath $pair[1]
            if ($b) { $candidates += [pscustomobject]@{ Platform = $pair[0]; Binaries = $b.FullName } }
        }
    }
} else {
    $roots = @()
    if ($Target -in @('Auto', 'Steam')) {
        $libs = @()
        foreach ($pf in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ($pf) { $libs += Join-Path $pf 'Steam' }
        }
        # Additional Steam libraries (other drives) are listed in libraryfolders.vdf.
        foreach ($l in @($libs)) {
            $vdf = Join-Path $l 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf) {
                foreach ($m in (Select-String -LiteralPath $vdf -Pattern '"path"\s+"([^"]+)"')) {
                    $libs += ($m.Matches[0].Groups[1].Value -replace '\\\\', '\')
                }
            }
        }
        foreach ($l in ($libs | Select-Object -Unique)) {
            $roots += [pscustomobject]@{ Platform = 'Steam'; Sub = 'Win64'; Root = Join-Path $l 'steamapps\common\Medieval Dynasty' }
        }
    }
    if ($Target -in @('Auto', 'GamePass')) {
        # Store-package install (read-only ACLs; writing needs an elevated shell) and Xbox app installs.
        foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
            $wa = Join-Path $d.Root 'Program Files\WindowsApps'
            if (Test-Path -LiteralPath $wa) {
                foreach ($pkg in (Get-ChildItem -LiteralPath $wa -Directory -Filter 'ToplitzProductionsGmbH.MedievalDynasty_*' -ErrorAction SilentlyContinue)) {
                    # The package folder can be a junction to <drive>:\XboxGames\...\Content; use the real path.
                    $real = $pkg.FullName
                    if ($pkg.LinkType) { $t = $pkg.ResolveLinkTarget($true); if ($t) { $real = $t.FullName } }
                    $roots += [pscustomobject]@{ Platform = 'GamePass'; Sub = 'WinGDK'; Root = $real }
                }
            }
            $roots += [pscustomobject]@{ Platform = 'GamePass'; Sub = 'WinGDK'; Root = Join-Path $d.Root 'XboxGames\Medieval Dynasty\Content' }
        }
    }
    foreach ($r in $roots) {
        $b = Find-Binaries $r.Root $r.Sub
        if ($b) { $candidates += [pscustomobject]@{ Platform = $r.Platform; Binaries = $b.FullName } }
    }
}

if (-not $candidates) { throw 'No Medieval Dynasty installation found. Use -GamePath.' }
$candidates = @($candidates | Group-Object { $_.Binaries.TrimEnd('\').ToLowerInvariant() } | ForEach-Object { $_.Group[0] })
if (@($candidates).Count -gt 1 -and $Target -eq 'Auto') {
    Write-Log "Multiple installs detected: $(($candidates.Platform) -join ', '). Deploying to all."
}

function Resolve-ModsDir([string]$Binaries) {
    # UE4SS v3.0.1 as installed for this game: <Binaries>\ue4ss\Mods (UE4SS.dll sits in <Binaries>\ue4ss).
    # Only fall back to the legacy <Binaries>\Mods when the UE4SS folder layout is not present.
    $new = Join-Path $Binaries 'ue4ss\Mods'
    if (Test-Path -LiteralPath $new) { return $new }
    $legacy = Join-Path $Binaries 'Mods'
    if ((Test-Path -LiteralPath $legacy) -and (Test-Path -LiteralPath (Join-Path $Binaries 'UE4SS.dll'))) {
        Write-Warning "Using legacy layout $legacy (no ue4ss\Mods found)."
        return $legacy
    }
    return $null
}

$failures = 0
foreach ($c in $candidates) {
    $label = "[$($c.Platform)]"
    $modsDir = Resolve-ModsDir $c.Binaries
    if (-not $modsDir) {
        Write-Error "$label UE4SS Mods folder not found under $($c.Binaries) (expected ue4ss\Mods). Install UE4SS v3.0.1 first." -ErrorAction Continue
        $failures++; continue
    }
    $ue4ssRoot = Split-Path -Parent $modsDir
    if (-not (Test-Path -LiteralPath (Join-Path $ue4ssRoot 'UE4SS.dll')) -and -not (Test-Path -LiteralPath (Join-Path $c.Binaries 'UE4SS.dll'))) {
        Write-Warning "$label UE4SS.dll not found; mod will not load."
    }
    $dest = Join-Path $modsDir $ModName
    Write-Log "$label $Source -> $dest"
    if ($DryRun) { Write-Log '  (dry run) no changes made'; continue }

    try {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $Source '*') -Destination $dest -Recurse -Force -Verbose:$VerbosePreference
    } catch {
        Write-Error "$label Copy failed: $($_.Exception.Message). Store-installed games under WindowsApps need an elevated PowerShell." -ErrorAction Continue
        $failures++; continue
    }

    # mods.txt (explicit load order) wins over enabled.txt when present.
    $modsTxt = Join-Path $modsDir 'mods.txt'
    if ((Test-Path -LiteralPath $modsTxt) -and -not (Select-String -LiteralPath $modsTxt -Pattern "^\s*$ModName\s*:\s*1" -Quiet)) {
        Write-Warning "$label $ModName is not set to '$ModName : 1' in $modsTxt; UE4SS may not start it."
    }

    # Verification: files exist, SHA-256 of the whole file matches.
    $srcMain = Join-Path $Source 'scripts\main.lua'
    $dstMain = Join-Path $dest 'scripts\main.lua'
    if (-not (Test-Path -LiteralPath $dstMain)) {
        Write-Error "$label MISMATCH: $dstMain does not exist after copy." -ErrorAction Continue
        $failures++; continue
    }
    $hashA = (Get-FileHash -Algorithm SHA256 -LiteralPath $srcMain).Hash
    $hashB = (Get-FileHash -Algorithm SHA256 -LiteralPath $dstMain).Hash
    $stamp = (Get-Item -LiteralPath $dstMain).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    Write-Log "  source : $srcMain"
    Write-Log "  target : $dstMain"
    Write-Log "  sha256 source=$hashA"
    Write-Log "  sha256 target=$hashB"
    Write-Log "  target LastWriteTime=$stamp"
    $enabled = Test-Path -LiteralPath (Join-Path $dest 'enabled.txt')
    if ($hashA -ne $hashB) {
        Write-Error "$label MISMATCH: deployed main.lua differs from source." -ErrorAction Continue
        $failures++
    } elseif (-not $enabled) {
        Write-Error "$label enabled.txt missing in $dest." -ErrorAction Continue
        $failures++
    } else {
        Write-Log "$label SUCCESS: main.lua and enabled.txt present, hashes match."
    }
}
if ($failures -gt 0) { throw "Deployment failed for $failures install(s)." }
