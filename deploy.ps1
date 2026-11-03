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
        foreach ($pf in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ($pf) { $roots += [pscustomobject]@{ Platform = 'Steam'; Sub = 'Win64'; Root = Join-Path $pf 'Steam\steamapps\common\Medieval Dynasty' } }
        }
    }
    if ($Target -in @('Auto', 'GamePass')) {
        foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
            $roots += [pscustomobject]@{ Platform = 'GamePass'; Sub = 'WinGDK'; Root = Join-Path $d.Root 'XboxGames\Medieval Dynasty\Content' }
        }
    }
    foreach ($r in $roots) {
        $b = Find-Binaries $r.Root $r.Sub
        if ($b) { $candidates += [pscustomobject]@{ Platform = $r.Platform; Binaries = $b.FullName } }
    }
}

if (-not $candidates) { throw 'No Medieval Dynasty installation found. Use -GamePath.' }
if (@($candidates).Count -gt 1 -and $Target -eq 'Auto') {
    Write-Log "Multiple installs detected: $(($candidates.Platform) -join ', '). Deploying to all."
}

foreach ($c in $candidates) {
    $modsDir = Join-Path $c.Binaries 'Mods'
    if (-not (Test-Path -LiteralPath (Join-Path $c.Binaries 'UE4SS.dll'))) {
        Write-Warning "[$($c.Platform)] UE4SS.dll not found in $($c.Binaries); install UE4SS v3.0.1 first."
    }
    if (-not (Test-Path -LiteralPath $modsDir)) { throw "[$($c.Platform)] Mods folder missing: $modsDir" }
    # Guard against the nested-extraction problem (Mods\Mods\...).
    $dest = Join-Path $modsDir $ModName
    Write-Log "[$($c.Platform)] $Source -> $dest"
    if ($DryRun) { Write-Log '  (dry run) no changes made'; continue }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $dest -Recurse -Force -Verbose:$VerbosePreference

    $modsTxt = Join-Path $modsDir 'mods.txt'
    if ((Test-Path -LiteralPath $modsTxt) -and -not (Select-String -LiteralPath $modsTxt -Pattern "^\s*$ModName\s*:" -Quiet)) {
        Write-Log "  NOTE: $ModName is not listed in mods.txt; enabled.txt is used instead."
    }

    # Verification
    $ok = (Test-Path -LiteralPath (Join-Path $dest 'scripts\main.lua')) -and (Test-Path -LiteralPath (Join-Path $dest 'enabled.txt'))
    $hashA = (Get-FileHash (Join-Path $Source 'scripts\main.lua')).Hash
    $hashB = (Get-FileHash (Join-Path $dest 'scripts\main.lua')).Hash
    if (-not $ok -or $hashA -ne $hashB) { throw "[$($c.Platform)] Deployment verification failed." }
    Write-Log "  Verified: main.lua and enabled.txt present, hashes match."
}
