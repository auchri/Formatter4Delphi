#requires -Version 7.0
<#
.SYNOPSIS
Self-tests for the O1 oracle scripts; needs no RAD Studio installation.
.DESCRIPTION
1. Test-OracleManifest.ps1 accepts the committed manifest and rejects manipulated copies (wrong
   references, contradicting hashes, missing fields, observations on planned runs). The committed
   manifest is only read; manipulated copies live in a temporary directory.
2. Get-NativeArtifactInventory.ps1 decodes UTF-8 (with/without BOM) and UTF-16 LE/BE, counts
   CRLF/LF/CR on decoded text, reports final newlines, handles empty and undecodable files, and
   produces byte-identical output for identical input.
Exit 0 = all passed, 1 = failures.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$oracle = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $oracle 'manifest/o1-manifest.json'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('f4d-oracle-selftest-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$failures = [Collections.Generic.List[string]]::new()
$passed = 0

function Check([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++ } else { $script:failures.Add($Name) }
}

function Invoke-ManifestCheck([string]$Path) {
    $output = & (Join-Path $PSScriptRoot 'Test-OracleManifest.ps1') -OracleRoot $oracle -Manifest $Path
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Test-Mutation([string]$Name, [scriptblock]$Mutate, [string]$ExpectedError) {
    $m = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -AsHashtable
    & $Mutate $m
    $path = Join-Path $temp ($Name + '.json')
    [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    $r = Invoke-ManifestCheck $path
    if ($ExpectedError) {
        Check ($r.ExitCode -eq 1 -and $r.Output -like "*$ExpectedError*") "manifest/$Name expected error '$ExpectedError', got exit $($r.ExitCode): $($r.Output)"
    } else {
        Check ($r.ExitCode -eq 0) "manifest/$Name expected pass, got: $($r.Output)"
    }
}

function Get-Run($m, [string]$RunId) {
    foreach ($x in $m.experiments) { foreach ($r in $x.runs) { if ($r.runId -eq $RunId) { return $r } } }
    throw "run $RunId not found"
}

$wrong = 'A' * 64
try {
    # ---- 1. Manifest validator ------------------------------------------------------------
    $before = (Get-FileHash $manifestPath).Hash
    $r = Invoke-ManifestCheck 'manifest/o1-manifest.json'
    Check ($r.ExitCode -eq 0) "manifest/committed must pass: $($r.Output)"

    Test-Mutation 'reserialized-unchanged' { param($m) } $null
    Test-Mutation 'input-hash-matches-fixture' { param($m) (Get-Run $m 'O2-P01-R1').inputSha256 = ($m.fixtures | Where-Object id -eq 'FX-ASSIGN').sha256 } $null
    Test-Mutation 'formatter-hash-contradicts-toolchain' { param($m) (Get-Run $m 'O2-P01-R1').formatterSha256 = $wrong } 'formatterSha256 AAAA'
    Test-Mutation 'profile-hash-contradicts-profile' { param($m) (Get-Run $m 'O1-X02-R1').profileSha256 = $wrong } 'contradicts profile'
    Test-Mutation 'input-hash-contradicts-fixture' { param($m) (Get-Run $m 'O2-P01-R1').inputSha256 = $wrong } 'contradicts fixture'
    Test-Mutation 'unknown-profile' { param($m) (Get-Run $m 'O2-P01-R1').profileId = 'PR-DOES-NOT-EXIST' } "references no defined profile"
    Test-Mutation 'unknown-toolchain' { param($m) (Get-Run $m 'O1-X01-R1').toolchainId = 'TC-NOPE' } 'references no defined toolchain'
    Test-Mutation 'unknown-environment' { param($m) (Get-Run $m 'O1-X01-R1').environmentId = 'ENV-NOPE' } 'references no defined environment'
    Test-Mutation 'fixture-used-as-profile' { param($m) (Get-Run $m 'O2-P01-R1').profileId = 'FX-ASSIGN' } 'is a fixture, not a profile'
    Test-Mutation 'hash-without-reference' { param($m) (Get-Run $m 'O1-X01-R1').profileSha256 = $wrong } 'given without profileId'
    Test-Mutation 'missing-run-field' { param($m) (Get-Run $m 'O2-P02-R1').Remove('exitCode') } 'lacks field(s) exitCode'
    Test-Mutation 'missing-toolchain' { param($m) (Get-Run $m 'O1-X03-R1').toolchainId = $null } 'toolchainId is mandatory'
    Test-Mutation 'planned-with-observation' { param($m) (Get-Run $m 'O2-P03-R1').exitCode = 0 } "carries observation 'exitCode'"
    Test-Mutation 'planned-without-command' { param($m) (Get-Run $m 'O2-P04-R1').commandLine = $null } 'requires commandLine'
    Test-Mutation 'executed-without-evidence' { param($m) (Get-Run $m 'O1-X01-R1').evidenceStatus = $null } "evidenceStatus 'observed'"
    Test-Mutation 'executed-formatter-without-exit' { param($m) (Get-Run $m 'O1-X01-R1').exitCode = $null } 'lacks exitCode'
    Test-Mutation 'run-status-mismatch' { param($m) (Get-Run $m 'O2-P05-R1').status = 'executed' } 'differs from experiment status'
    Test-Mutation 'blocked-with-runs' { param($m)
        $blocked = $m.experiments | Where-Object id -eq 'O1-B01'
        $blocked.runs = @((Get-Run $m 'O2-P06-R1').Clone()); $blocked.runs[0].runId = 'O1-B01-R1'; $blocked.runs[0].status = 'blocked'
    } 'must not list runs'
    Test-Mutation 'committed-fixture-hash' { param($m) ($m.fixtures | Where-Object id -eq 'FX-TABS').sha256 = $wrong } 'sha256 does not match'
    Test-Mutation 'original-profile-hash' { param($m) ($m.profiles | Where-Object id -eq 'PR-SHIP-WIDE').sha256 = $wrong } 'sha256 differs from inventory'
    Test-Mutation 'personal-path' { param($m) (Get-Run $m 'O2-P07-R1').workingDirectory = 'C:\Users\someone\run' } 'personal absolute path'
    Check ((Get-FileHash $manifestPath).Hash -eq $before) 'manifest/committed file must stay unchanged'

    # ---- 2. Inventory encoding / line ends ------------------------------------------------
    $bds = Join-Path $temp 'bds'
    $config = Join-Path $bds 'bin\config'
    New-Item -ItemType Directory -Path $config | Out-Null
    $lines = @('<?xml version="1.0"?>', '<TgConfig Version="3">',
        '  <!-- Grüße -->', '  <Option Name="DelphiFormatter.AssignSpaces" Type="System.String" Value="None" Levels="Formatter" />', '</TgConfig>')
    function Join-Lines([string[]]$Separators, [string]$Final) {
        $text = ''
        for ($i = 0; $i -lt $lines.Count; $i++) { $text += $lines[$i] + ($i -lt $lines.Count - 1 ? $Separators[$i % $Separators.Count] : $Final) }
        $text
    }
    function Write-Case([string]$Name, [byte[]]$Bytes) { [IO.File]::WriteAllBytes((Join-Path $config "Formatter_$Name.config"), $Bytes) }
    $utf8 = [Text.UTF8Encoding]::new($false)
    Write-Case 'U8' $utf8.GetBytes((Join-Lines @("`r`n") "`r`n"))
    Write-Case 'U8Bom' ([byte[]](0xEF, 0xBB, 0xBF) + $utf8.GetBytes((Join-Lines @("`n") '')))
    Write-Case 'U16LE' ([byte[]](0xFF, 0xFE) + [Text.Encoding]::Unicode.GetBytes((Join-Lines @("`r`n", "`n", "`r") '')))
    Write-Case 'U16BE' ([byte[]](0xFE, 0xFF) + [Text.Encoding]::BigEndianUnicode.GetBytes((Join-Lines @("`r`n") "`r`n")))
    Write-Case 'U8Mixed' $utf8.GetBytes((Join-Lines @("`r`n", "`r", "`n") "`r"))
    Write-Case 'Empty' ([byte[]]@())
    Write-Case 'BadUtf8' ($utf8.GetBytes('<?xml version="1.0"?><TgConfig>') + [byte[]](0xC3, 0x28) + $utf8.GetBytes('</TgConfig>'))
    Write-Case 'OddU16' ([byte[]](0xFF, 0xFE, 0x3C, 0x00, 0x3F))

    $outs = foreach ($i in 1, 2) {
        $out = Join-Path $temp "inventory$i.json"
        & (Join-Path $PSScriptRoot 'Get-NativeArtifactInventory.ps1') -BdsRoot $bds -OutFile $out | Out-Null
        $out
    }
    Check ((Get-FileHash $outs[0]).Hash -eq (Get-FileHash $outs[1]).Hash) 'inventory/deterministic output'
    $inv = [IO.File]::ReadAllText($outs[0]) | ConvertFrom-Json -AsHashtable
    $byName = @{}
    foreach ($p in $inv.profiles) { $byName[$p.label.Substring('shipped:Formatter_'.Length).Replace('.config', '')] = $p }

    function Check-Case([string]$Name, [string]$Bom, $Valid, [int[]]$Eol, $EndsWithNewline, [int]$Options) {
        $p = $byName[$Name]; $e = $p.encoding
        Check ($e.bom -eq $Bom) "inventory/$Name bom=$($e.bom)"
        Check ($e.validUtf8WithoutBom -eq $Valid) "inventory/$Name validUtf8WithoutBom=$($e.validUtf8WithoutBom)"
        Check ($null -ne $e.eol -and $e.eol.crlf -eq $Eol[0] -and $e.eol.lf -eq $Eol[1] -and $e.eol.cr -eq $Eol[2]) "inventory/$Name eol=$($e.eol | ConvertTo-Json -Compress)"
        Check ($e.endsWithNewline -eq $EndsWithNewline) "inventory/$Name endsWithNewline=$($e.endsWithNewline)"
        Check ($p.optionCount -eq $Options) "inventory/$Name optionCount=$($p.optionCount)"
        Check (-not $e.Contains('decodeError')) "inventory/$Name unexpected decodeError"
    }
    Check-Case 'U8' 'none' $true @(5, 0, 0) $true 1
    Check-Case 'U8Bom' 'utf-8' $true @(0, 4, 0) $false 1
    Check-Case 'U16LE' 'utf-16le' $null @(2, 1, 1) $false 1
    Check-Case 'U16BE' 'utf-16be' $null @(5, 0, 0) $true 1
    Check-Case 'U8Mixed' 'none' $true @(2, 1, 2) $true 1
    Check ($byName['U8'].encoding.nonAsciiBytes -eq 4) "inventory/U8 nonAsciiBytes=$($byName['U8'].encoding.nonAsciiBytes)"

    $empty = $byName['Empty']
    Check ($empty.encoding.eol.crlf -eq 0 -and $empty.encoding.eol.lf -eq 0 -and $empty.encoding.eol.cr -eq 0 -and $empty.encoding.endsWithNewline -eq $false) 'inventory/Empty eol'
    Check ($empty.Contains('parseError') -and $null -eq $empty.xml -and $empty.optionCount -eq 0) 'inventory/Empty parseError'
    foreach ($name in 'BadUtf8', 'OddU16') {
        $p = $byName[$name]
        Check ($p.encoding.Contains('decodeError') -and $null -eq $p.encoding.eol -and $null -eq $p.encoding.endsWithNewline) "inventory/$name decodeError"
        Check ($p.Contains('parseError') -and $p.optionCount -eq 0) "inventory/$name parseError"
    }
    Check ($byName['BadUtf8'].encoding.validUtf8WithoutBom -eq $false) 'inventory/BadUtf8 validUtf8WithoutBom'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Output "FAIL $_" }
    Write-Output "$passed passed, $($failures.Count) failed."
    exit 1
}
Write-Output "PASS: $passed oracle script checks."
