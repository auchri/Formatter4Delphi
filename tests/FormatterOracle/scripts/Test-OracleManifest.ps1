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
function Resolve-Input([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
}
$text = [IO.File]::ReadAllText((Resolve-Input $Manifest))
$m = $text | ConvertFrom-Json
$inv = [IO.File]::ReadAllText((Resolve-Input $Inventory)) | ConvertFrom-Json -AsHashtable

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
    if ($p.origin -notin 'shipped', 'ide-active', 'ide-export', 'self-authored', 'derived') { Fail "$($p.id): unknown origin '$($p.origin)'." }
    if ($p.committed) {
        if ($p.origin -ne 'self-authored') { Fail "$($p.id): only self-authored profiles may be committed." }
        $full = Join-Path $root $p.path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { Fail "$($p.id): missing file $($p.path)." }
        else {
            $bytes = [IO.File]::ReadAllBytes($full)
            if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)) -ne $p.sha256) { Fail "$($p.id): sha256 does not match $($p.path)." }
            if ($bytes.Length -ne $p.sizeBytes) { Fail "$($p.id): size does not match $($p.path)." }
        }
    } elseif ($p.origin -eq 'derived') {
        if (Has $p 'path') { Fail "$($p.id): uncommitted derived profile must not declare a repository path." }
        if (-not (Has $p 'derivation') -or [string]::IsNullOrWhiteSpace($p.derivation)) { Fail "$($p.id): derived profile without derivation." }
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

# Hash of each referenceable record, for run cross-checks.
$knownHash = @{}
foreach ($t in $m.toolchains) { $knownHash[$t.id] = $t.formatter.exe.sha256 }
foreach ($p in $m.profiles) { $knownHash[$p.id] = $p.sha256 }
foreach ($f in $m.fixtures) { $knownHash[$f.id] = $f.sha256 }

# Every run record lists all fields; null marks "not applicable / not observed", absence is an error.
$runFields = 'runId', 'status', 'kind', 'toolchainId', 'environmentId', 'formatterSha256', 'profileId',
    'profileSha256', 'inputFixtureId', 'inputSha256', 'outputSha256', 'commandLine', 'workingDirectory',
    'encodingArgument', 'exitCode', 'stdoutSha256', 'stderrSha256', 'repetitions', 'repetitionsIdentical',
    'observedDifference', 'evidenceStatus', 'supportedScope'
$observationFields = 'exitCode', 'stdoutSha256', 'stderrSha256', 'outputSha256', 'observedDifference', 'repetitionsIdentical'
# Optional O2 run fields; observations too, so they may only appear on executed runs.
$runnerFields = 'processOutcome', 'runnerClassification', 'durationMs', 'killed', 'dialogClosedByRunner', 'failureClass', 'inputChanged', 'createdFiles', 'localRunId'
# (id field, hash field, referenced record kind)
$references = @(
    @('toolchainId', 'formatterSha256', 'toolchain'),
    @('profileId', 'profileSha256', 'profile'),
    @('inputFixtureId', 'inputSha256', 'fixture'),
    @('environmentId', $null, 'environment'))
$runIds = @{}
foreach ($x in $m.experiments) {
    Register 'experiment' $x.id
    if ($x.status -notin 'executed', 'planned', 'blocked', 'not-run') { Fail "$($x.id): unknown status '$($x.status)'." }
    if ($x.status -in 'blocked', 'not-run' -and -not (Has $x 'reason')) { Fail "$($x.id): $($x.status) without reason." }
    if ($x.status -eq 'planned' -and -not ((Has $x 'question') -and (Has $x 'decisionUse'))) { Fail "$($x.id): planned without question/decisionUse." }
    if (Has $x 'executedIn') {
        if ($x.status -ne 'planned') { Fail "$($x.id): executedIn is only valid on a planned record." }
        $target = Join-Path $root $x.executedIn
        $executed = (Test-Path -LiteralPath $target -PathType Leaf) ?
            @(([IO.File]::ReadAllText($target) | ConvertFrom-Json).experiments | Where-Object { $_.id -eq $x.id -and $_.status -eq 'executed' }) : @()
        if ($executed.Count -ne 1) { Fail "$($x.id): executedIn '$($x.executedIn)' holds no executed record of this experiment." }
    }
    if ($x.status -in 'blocked', 'not-run' -and @($x.runs).Count -gt 0) { Fail "$($x.id): $($x.status) experiment must not list runs." }
    if ($x.status -in 'executed', 'planned' -and @($x.runs).Count -eq 0) { Fail "$($x.id): $($x.status) experiment without runs." }
    foreach ($r in $x.runs) {
        $missing = @($runFields | Where-Object { -not (Has $r $_) })
        if ($missing) { Fail "$($r.runId ?? $x.id): run record lacks field(s) $($missing -join ', ') (use null for not applicable)."; continue }
        if ([string]::IsNullOrWhiteSpace($r.runId)) { Fail "$($x.id): run without runId."; continue }
        if ($runIds.ContainsKey($r.runId)) { Fail "Duplicate runId '$($r.runId)'." } else { $runIds[$r.runId] = $true }
        if ($r.status -ne $x.status) {
            Fail "$($r.runId): run status '$($r.status)' differs from experiment status '$($x.status)'."
        }
        if ($r.kind -notin 'formatter-cli', 'ide-export', 'ide-side-effect', 'static-analysis') { Fail "$($r.runId): unknown kind '$($r.kind)'." }
        foreach ($h in 'formatterSha256', 'profileSha256', 'inputSha256', 'outputSha256', 'stdoutSha256', 'stderrSha256') {
            if ($null -ne $r.$h -and $r.$h -notmatch $hash) { Fail "$($r.runId): $h malformed." }
        }
        foreach ($ref in $references) {
            $id = $r.($ref[0])
            $hashValue = $null -ne $ref[1] ? $r.($ref[1]) : $null
            if ($null -ne $id) {
                if (-not $ids.ContainsKey($id)) { Fail "$($r.runId): $($ref[0]) '$id' references no defined $($ref[2])." ; continue }
                if ($ids[$id] -ne $ref[2]) { Fail "$($r.runId): $($ref[0]) '$id' is a $($ids[$id]), not a $($ref[2])."; continue }
                if ($null -ne $hashValue -and $hashValue -ne $knownHash[$id]) {
                    Fail "$($r.runId): $($ref[1]) $hashValue contradicts $($ref[2]) '$id' ($($knownHash[$id]))."
                }
            } elseif ($null -ne $hashValue) {
                Fail "$($r.runId): $($ref[1]) given without $($ref[0]); the hash cannot be attributed."
            }
        }
        if ($null -eq $r.toolchainId) { Fail "$($r.runId): toolchainId is mandatory." }
        if ($r.kind -eq 'formatter-cli') {
            foreach ($required in 'formatterSha256', 'commandLine', 'workingDirectory') {
                if ($null -eq $r.$required) { Fail "$($r.runId): formatter run requires $required (also when planned)." }
            }
        }
        if ($r.kind -in 'ide-export', 'ide-side-effect' -and ($null -eq $r.profileId -or $null -eq $r.profileSha256)) {
            Fail "$($r.runId): $($r.kind) run requires profileId and profileSha256."
        }
        if ($r.status -eq 'executed') {
            if ($r.evidenceStatus -ne 'observed') { Fail "$($r.runId): executed run must have evidenceStatus 'observed'." }
            if ($null -eq $r.observedDifference -or $null -eq $r.repetitions -or $r.repetitions -lt 1) { Fail "$($r.runId): executed run lacks observation/repetitions." }
            if ([string]::IsNullOrWhiteSpace($r.supportedScope)) { Fail "$($r.runId): executed run lacks supportedScope." }
            if ($r.kind -eq 'formatter-cli' -and ($null -eq $r.exitCode -or $null -eq $r.commandLine -or $null -eq $r.workingDirectory)) {
                Fail "$($r.runId): executed formatter run lacks exitCode/commandLine/workingDirectory."
            }
            if (Has $r 'processOutcome') {
                # A run that did not end by itself with exit code 0 must never read as success.
                $expectedClass = if ($r.processOutcome -in 'dialog', 'timeout', 'start-failed') { 'aborted' }
                    elseif ($r.processOutcome -eq 'exited') { $r.exitCode -eq 0 ? 'success' : 'formatter-error' }
                    else { Fail "$($r.runId): unknown processOutcome '$($r.processOutcome)'."; $null }
                if ($null -ne $expectedClass -and $r.runnerClassification -ne $expectedClass) {
                    Fail "$($r.runId): runnerClassification '$($r.runnerClassification)' contradicts outcome '$($r.processOutcome)' with exit $($r.exitCode), expected '$expectedClass'."
                }
            }
        } else {
            foreach ($o in $observationFields) { if ($null -ne $r.$o) { Fail "$($r.runId): non-executed run carries observation '$o'." } }
            if ($null -ne $r.evidenceStatus) { Fail "$($r.runId): non-executed run carries evidenceStatus." }
            foreach ($o in $runnerFields) { if (Has $r $o) { Fail "$($r.runId): non-executed run carries runner field '$o'." } }
        }
    }
}

# No proprietary artifacts tracked under the oracle tree.
$tracked = @(git -C $root ls-files --cached --others --exclude-standard -- . 2>$null)
foreach ($file in $tracked) {
    if ($file -match '(?i)\.(exe|dll|bpl|bak)$') { Fail "Binary artifact must not be versioned: $file" }
    if ($file -match '(?i)\.config$' -and $file -notmatch '^fixtures/profiles/O1[A-Za-z0-9]+\.config$') { Fail "Original-looking profile must not be versioned: $file" }
}
$committedProfiles = @(foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'manifest') -Filter '*.json' -File) {
    ([IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json).profiles | Where-Object committed | ForEach-Object path
})
$committedProfiles += @($m.profiles | Where-Object committed | ForEach-Object path)
foreach ($file in $tracked | Where-Object { $_ -match '^fixtures/profiles/' }) {
    if ($committedProfiles -notcontains $file) { Fail "Profile fixture not described in manifest: $file" }
}

if ($errors.Count) {
    $errors | ForEach-Object { Write-Output "ERROR $_" }
    exit 1
}
Write-Output ('PASS: {0} toolchain(s), {1} profiles, {2} fixtures, {3} experiments, {4} runs, {5} files checked under tests/FormatterOracle.' -f
    @($m.toolchains).Count, @($m.profiles).Count, @($m.fixtures).Count, @($m.experiments).Count, $runIds.Count, $tracked.Count)
