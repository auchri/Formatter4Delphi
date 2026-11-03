#requires -Version 7.0
<#
.SYNOPSIS
Read-only consistency check for tests/FormatterOracle manifests (format formatter4delphi.oracle-manifest/1).
.DESCRIPTION
Checks required fields, ID uniqueness and references, status/evidence separation (executed runs carry
observations, planned/blocked ones carry none), committed fixture hashes/sizes, absence of absolute
personal paths, agreement of original-profile hashes with the inventory JSON, and that no proprietary
binaries or original profiles are tracked under tests/FormatterOracle. Exit 0 = pass, 1 = errors.
#>
[CmdletBinding()]
param(
    [string]$OracleRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Manifest = 'manifest/o1-manifest.json',
    [string]$Inventory = 'inventory/rad-studio-23.0_29.0.51961.7529.inventory.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$errors = [Collections.Generic.List[string]]::new()
function Fail([string]$Message) { $errors.Add($Message) }
function Has($Object, [string]$Name) { $null -ne $Object.PSObject.Properties[$Name] }

$root = [IO.Path]::GetFullPath($OracleRoot)
$text = [IO.File]::ReadAllText((Join-Path $root $Manifest))
$m = $text | ConvertFrom-Json
$inv = [IO.File]::ReadAllText((Join-Path $root $Inventory)) | ConvertFrom-Json -AsHashtable

if ($m.manifestFormat -ne 'formatter4delphi.oracle-manifest/1') { Fail "Unknown manifestFormat '$($m.manifestFormat)'." }
foreach ($key in 'milestone', 'repositoryBase', 'toolchains', 'environments', 'profiles', 'fixtures', 'experiments') {
    if (-not (Has $m $key)) { Fail "Missing top-level key '$key'." }
}
if ($text -match '(?i)\b[A-Z]:[\\/]{1,2}(Users|Documents and Settings)\b' -or $text -match '(?i)/(home|Users)/[^/<]+/') {
    Fail 'Manifest contains a personal absolute path.'
}

$hash = '^[0-9A-F]{64}$'
$ids = @{}
function Register([string]$Kind, [string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id)) { Fail "$Kind without id."; return }
    if ($ids.ContainsKey($Id)) { Fail "Duplicate id '$Id'." } else { $ids[$Id] = $Kind }
}
foreach ($t in $m.toolchains) {
    Register 'toolchain' $t.id
    if ($t.formatter.exe.sha256 -notmatch $hash) { Fail "$($t.id): formatter sha256 malformed." }
    if (-not (Has $t 'matchesTarget12_3')) { Fail "$($t.id): matchesTarget12_3 must be stated explicitly." }
}
foreach ($e in $m.environments) { Register 'environment' $e.id }

$inventoryHashes = @{}
foreach ($p in $inv.profiles) { $inventoryHashes[$p.label] = $p.sha256 }
foreach ($p in $m.profiles) {
    Register 'profile' $p.id
    if ($p.sha256 -notmatch $hash) { Fail "$($p.id): sha256 malformed." }
    if ($p.origin -notin 'shipped', 'ide-active', 'ide-export', 'self-authored') { Fail "$($p.id): unknown origin '$($p.origin)'." }
    if ($p.committed) {
        if ($p.origin -ne 'self-authored') { Fail "$($p.id): only self-authored profiles may be committed." }
        $full = Join-Path $root $p.path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Fail "$($p.id): missing file $($p.path)." }
        else {
            $bytes = [IO.File]::ReadAllBytes($full)
            if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ne $p.sha256) { Fail "$($p.id): sha256 does not match $($p.path)." }
            if ($bytes.Length -ne $p.sizeBytes) { Fail "$($p.id): size does not match $($p.path)." }
        }
    } else {
        if (Has $p 'path') { Fail "$($p.id): uncommitted original profile must not declare a repository path." }
        if (-not $inventoryHashes.ContainsKey($p.inventoryLabel)) { Fail "$($p.id): inventory label '$($p.inventoryLabel)' not found." }
        elseif ($inventoryHashes[$p.inventoryLabel] -ne $p.sha256) { Fail "$($p.id): sha256 differs from inventory." }
    }
}
foreach ($f in $m.fixtures) {
    Register 'fixture' $f.id
    if ($f.compileStatus -notin 'designed-not-compiled', 'compiled') { Fail "$($f.id): unknown compileStatus." }
    if ($f.compileStatus -eq 'compiled' -and -not (Has $f 'compileEvidence')) { Fail "$($f.id): compiled without compileEvidence." }
    $full = Join-Path $root $f.path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Fail "$($f.id): missing file $($f.path)."; continue }
    $bytes = [IO.File]::ReadAllBytes($full)
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ne $f.sha256) { Fail "$($f.id): sha256 does not match $($f.path)." }
    if ($bytes.Length -ne $f.sizeBytes) { Fail "$($f.id): size does not match $($f.path)." }
}

$observationFields = 'exitCode', 'stdoutSha256', 'stderrSha256', 'outputSha256', 'observedDifference', 'repetitionsIdentical'
$runIds = @{}
foreach ($x in $m.experiments) {
    Register 'experiment' $x.id
    if ($x.status -notin 'executed', 'planned', 'blocked', 'not-run') { Fail "$($x.id): unknown status '$($x.status)'." }
    if ($x.status -in 'blocked', 'not-run' -and -not (Has $x 'reason')) { Fail "$($x.id): $($x.status) without reason." }
    if ($x.status -eq 'planned' -and -not ((Has $x 'question') -and (Has $x 'decisionUse'))) { Fail "$($x.id): planned without question/decisionUse." }
    foreach ($r in $x.runs) {
        if ($runIds.ContainsKey($r.runId)) { Fail "Duplicate runId '$($r.runId)'." } else { $runIds[$r.runId] = $true }
        if ($r.status -ne $x.status -and -not ($x.status -eq 'executed' -and $r.status -eq 'executed')) {
            Fail "$($r.runId): run status '$($r.status)' differs from experiment status '$($x.status)'."
        }
        foreach ($ref in @(@($r.toolchainId, 'toolchain'), @($r.environmentId, 'environment'), @($r.profileId, 'profile'), @($r.inputFixtureId, 'fixture'))) {
            if ($null -ne $ref[0] -and $ids[$ref[0]] -ne $ref[1]) { Fail "$($r.runId): unknown $($ref[1]) '$($ref[0])'." }
        }
        foreach ($h in 'formatterSha256', 'profileSha256', 'inputSha256', 'outputSha256', 'stdoutSha256', 'stderrSha256') {
            if ($null -ne $r.$h -and $r.$h -notmatch $hash) { Fail "$($r.runId): $h malformed." }
        }
        if ($r.status -eq 'executed') {
            if ($r.evidenceStatus -ne 'observed') { Fail "$($r.runId): executed run must have evidenceStatus 'observed'." }
            if ($null -eq $r.observedDifference -or $null -eq $r.repetitions -or $r.repetitions -lt 1) { Fail "$($r.runId): executed run lacks observation/repetitions." }
            if ([string]::IsNullOrWhiteSpace($r.supportedScope)) { Fail "$($r.runId): executed run lacks supportedScope." }
            if ($r.kind -eq 'formatter-cli' -and ($null -eq $r.exitCode -or $null -eq $r.commandLine -or $null -eq $r.workingDirectory)) {
                Fail "$($r.runId): executed formatter run lacks exitCode/commandLine/workingDirectory."
            }
        } else {
            foreach ($o in $observationFields) { if ($null -ne $r.$o) { Fail "$($r.runId): non-executed run carries observation '$o'." } }
            if ($null -ne $r.evidenceStatus) { Fail "$($r.runId): non-executed run carries evidenceStatus." }
        }
    }
}

# No proprietary artifacts tracked under the oracle tree.
$tracked = @(git -C $root ls-files --cached --others --exclude-standard -- . 2>$null)
foreach ($file in $tracked) {
    if ($file -match '(?i)\.(exe|dll|bpl|bak)$') { Fail "Binary artifact must not be versioned: $file" }
    if ($file -match '(?i)\.config$' -and $file -notmatch '^fixtures/profiles/O1[A-Za-z0-9]+\.config$') { Fail "Original-looking profile must not be versioned: $file" }
}
$committedProfiles = @($m.profiles | Where-Object committed | ForEach-Object path)
foreach ($file in $tracked | Where-Object { $_ -match '^fixtures/profiles/' }) {
    if ($committedProfiles -notcontains $file) { Fail "Profile fixture not described in manifest: $file" }
}

if ($errors.Count) {
    $errors | ForEach-Object { Write-Output "ERROR $_" }
    exit 1
}
Write-Output ('PASS: {0} toolchain(s), {1} profiles, {2} fixtures, {3} experiments, {4} runs, {5} files checked under tests/FormatterOracle.' -f
    @($m.toolchains).Count, @($m.profiles).Count, @($m.fixtures).Count, @($m.experiments).Count, $runIds.Count, $tracked.Count)
