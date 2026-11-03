#requires -Version 7.0
<#
.SYNOPSIS
Runs the O2 oracle experiments P01 (AssignSpaces) and/or P11 (invocation/failure behavior) via RunFormatterOracle.ps1.
.DESCRIPTION
All work happens in a new experiment directory below tests/FormatterOracle/local/runs (git-ignored).
P01 derives two complete profiles from one original profile (default: the shipped
Formatter_Default.config next to Formatter.exe, hash-checked against the manifest), changes only
DelphiFormatter.AssignSpaces (A=BeforeAndAfter, B=None), proves by parsing that this is the only
option difference, runs both variants with -Repetitions copies of O1AssignSpacing.pas and writes
analysis.json plus unified line diffs (input->A, input->B, A->B).
P11 runs a fixed set of normal and faulty invocations and writes p11-summary.json.
Nothing outside the experiment directory is written; %APPDATA% profiles are guarded by the runner.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FormatterPath,
    [ValidateSet('P01', 'P11')][string[]]$Experiment = @('P01', 'P11'),
    [string]$BaseProfilePath,
    [int]$Repetitions = 3,
    [int]$TimeoutSeconds = 60,
    [string]$ExperimentRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$oracle = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'RunFormatterOracle.ps1'
if (-not $ExperimentRoot) { $ExperimentRoot = Join-Path $oracle 'local/runs' }
$fixture = Join-Path $oracle 'fixtures/delphi/O1AssignSpacing.pas'
$manifest = [IO.File]::ReadAllText((Join-Path $oracle 'manifest/o1-manifest.json')) | ConvertFrom-Json
if (-not $BaseProfilePath) { $BaseProfilePath = Join-Path (Split-Path -Parent $FormatterPath) 'config/Formatter_Default.config' }
$utf8 = [Text.UTF8Encoding]::new($false)

function Get-Sha256File([string]$Path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path))) }

function Read-Options([string]$Path) {
    # Ordered option map (Name -> attribute string) using the same safe XML settings as the inventory.
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $doc = [Xml.XmlDocument]::new(); $doc.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create($Path, $settings)
    try { $doc.Load($reader) } finally { $reader.Dispose() }
    $map = [ordered]@{}
    foreach ($node in $doc.DocumentElement.get_ChildNodes()) {
        if ($node.get_NodeType() -ne 'Element' -or $node.get_LocalName() -ne 'Option') { continue }
        $name = $node.GetAttribute('Name')
        if ($map.Contains($name)) { throw "Duplicate option $name in $Path" }
        $map[$name] = (@($node.get_Attributes()) | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join ';'
    }
    $map
}

function Get-LineDiff([string[]]$A, [string[]]$B) {
    # LCS line diff; returns a list of hunks with 1-based line numbers. Inputs are small fixtures.
    $n = $A.Count; $m = $B.Count
    $dp = [int[,]]::new($n + 1, $m + 1)
    for ($i = $n - 1; $i -ge 0; $i--) { for ($j = $m - 1; $j -ge 0; $j--) {
        $dp[$i, $j] = $A[$i] -ceq $B[$j] ? $dp[($i + 1), ($j + 1)] + 1 : [Math]::Max($dp[($i + 1), $j], $dp[$i, ($j + 1)]) } }
    $ops = [Collections.Generic.List[object]]::new(); $i = 0; $j = 0
    while ($i -lt $n -or $j -lt $m) {
        if ($i -lt $n -and $j -lt $m -and $A[$i] -ceq $B[$j]) { $ops.Add(@('=', $i, $j)); $i++; $j++ }
        elseif ($j -lt $m -and ($i -ge $n -or $dp[$i, ($j + 1)] -ge $dp[($i + 1), $j])) { $ops.Add(@('+', $i, $j)); $j++ }
        else { $ops.Add(@('-', $i, $j)); $i++ }
    }
    $changes = [Collections.Generic.List[object]]::new()
    foreach ($op in $ops) {
        if ($op[0] -eq '-') { $changes.Add([ordered]@{ op = '-'; line = $op[1] + 1; text = $A[$op[1]] }) }
        elseif ($op[0] -eq '+') { $changes.Add([ordered]@{ op = '+'; line = $op[2] + 1; text = $B[$op[2]] }) }
    }
    , $changes
}

function Split-Lines([string]$Path) {
    # Lines without terminators plus the terminator kinds, so EOL changes stay visible.
    $text = [IO.File]::ReadAllText($Path)
    $parts = [regex]::Split($text, '(\r\n|\n|\r)')
    $lines = [Collections.Generic.List[string]]::new()
    for ($k = 0; $k -lt $parts.Count; $k += 2) {
        $eol = $k + 1 -lt $parts.Count ? ($parts[$k + 1] -replace "`r", '\r' -replace "`n", '\n') : ''
        if ($k -eq $parts.Count - 1 -and $parts[$k] -eq '') { break }
        $lines.Add($parts[$k] + ($eol ? "⏎$eol" : ''))
    }
    , $lines.ToArray()
}

function Write-Diff([string]$Path, [string]$Title, $Changes) {
    $text = "# $Title`n" + (($Changes | ForEach-Object { '{0}{1,4}: {2}' -f $_.op, $_.line, ($_.text -replace "`t", '→') }) -join "`n") + "`n"
    [IO.File]::WriteAllText($Path, $text, $utf8)
}

function Invoke-Runner([string]$RunRoot, [string]$Name, [string[]]$Template, [string[]]$Inputs, [string]$Profile, [int]$Reps, [switch]$AllowInvalid) {
    $params = @{ FormatterPath = $FormatterPath; ArgumentTemplate = $Template; RunName = $Name; RunRoot = $RunRoot; Repetitions = $Reps; TimeoutSeconds = $TimeoutSeconds }
    if ($Inputs) { $params.InputPath = $Inputs }
    if ($Profile) { $params.ProfilePath = $Profile }
    if ($AllowInvalid) { $params.AllowInvalidProfile = $true }
    $out = & $runner @params
    $code = $LASTEXITCODE
    $out | ForEach-Object { Write-Host "  $_" }
    $dir = Get-ChildItem -LiteralPath $RunRoot -Directory -Filter "$Name-*" | Sort-Object Name | Select-Object -Last 1
    if ($code -eq 2 -or -not $dir -or -not (Test-Path (Join-Path $dir.FullName 'run-result.json'))) { throw "Runner precondition failure for $Name (exit $code)." }
    [pscustomobject]@{ ExitCode = $code; Dir = $dir.FullName; Result = ([IO.File]::ReadAllText((Join-Path $dir.FullName 'run-result.json')) | ConvertFrom-Json -AsHashtable) }
}

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$fixtureHashBefore = Get-Sha256File $fixture

if ('P01' -in $Experiment) {
    $exp = Join-Path $ExperimentRoot "O2-P01-$stamp"
    New-Item -ItemType Directory -Path (Join-Path $exp 'profiles') -Force | Out-Null
    Write-Output "O2-P01 -> $exp"
    $baseHash = Get-Sha256File $BaseProfilePath
    $baseRecord = $manifest.profiles | Where-Object sha256 -eq $baseHash | Select-Object -First 1
    if (-not $baseRecord -or $baseRecord.origin -ne 'shipped') { throw "Base profile hash $baseHash is not a shipped profile in the manifest." }
    $baseText = [IO.File]::ReadAllText($BaseProfilePath)
    $pattern = '(<Option Name="DelphiFormatter\.AssignSpaces"[^>]*?\sValue=")([^"]*)(")'
    if ([regex]::Matches($baseText, $pattern).Count -ne 1) { throw 'Base profile must contain exactly one DelphiFormatter.AssignSpaces option.' }
    $profiles = [ordered]@{}
    foreach ($v in @(@('A', 'BeforeAndAfter'), @('B', 'None'))) {
        $p = Join-Path $exp "profiles/P01-$($v[0])-AssignSpaces-$($v[1]).config"
        $text = [regex]::Replace($baseText, $pattern, { param($mm) $mm.Groups[1].Value + $v[1] + $mm.Groups[3].Value })
        [IO.File]::WriteAllBytes($p, [Text.Encoding]::Latin1.GetBytes($text)) # base is ASCII without BOM; keep bytes 1:1
        $profiles[$v[0]] = $p
    }
    $optA = Read-Options $profiles.A; $optB = Read-Options $profiles.B; $optBase = Read-Options $BaseProfilePath
    $diffAB = @($optA.Keys | Where-Object { $optA[$_] -cne $optB[$_] }) + @($optB.Keys | Where-Object { -not $optA.Contains($_) })
    if ($optA.Count -ne $optBase.Count -or $optB.Count -ne $optBase.Count -or ($diffAB -join ',') -ne 'DelphiFormatter.AssignSpaces') {
        throw "Profile check failed: A/B differ in [$($diffAB -join ', ')]."
    }
    $diffBaseA = @($optA.Keys | Where-Object { $optA[$_] -cne $optBase[$_] })
    $template = @('-delphi', '-config', '{profile}', '-log', '{log}', '{input}')
    $runs = [ordered]@{}
    foreach ($k in 'A', 'B') { $runs[$k] = Invoke-Runner (Join-Path $exp 'runs') "P01-$k" $template @($fixture) $profiles[$k] $Repetitions }

    $outputs = [ordered]@{}
    foreach ($k in 'A', 'B') {
        $hashes = @($runs[$k].Result.repetitionResults | ForEach-Object { $_.filesAfter['O1AssignSpacing.pas'].sha256 })
        $outputs[$k] = [ordered]@{
            runId = $runs[$k].Result.runId; classification = $runs[$k].Result.classification
            states = @($runs[$k].Result.repetitionResults | ForEach-Object state)
            exitCodes = @($runs[$k].Result.repetitionResults | ForEach-Object exitCode)
            outputSha256 = $hashes; distinctOutputs = @($hashes | Sort-Object -Unique).Count
            outputSizeBytes = $runs[$k].Result.repetitionResults[0].filesAfter['O1AssignSpacing.pas'].sizeBytes
            profileUnchanged = @($runs[$k].Result.repetitionResults | Where-Object { $_.changed -match '^profile-' }).Count -eq 0
            createdFiles = @($runs[$k].Result.repetitionResults | ForEach-Object { $_.created } | Sort-Object -Unique)
        }
    }
    $in = Split-Lines $fixture
    $outA = Split-Lines (Join-Path $runs.A.Dir 'rep-01/O1AssignSpacing.pas')
    $outB = Split-Lines (Join-Path $runs.B.Dir 'rep-01/O1AssignSpacing.pas')
    $dInA = Get-LineDiff $in $outA; $dInB = Get-LineDiff $in $outB; $dAB = Get-LineDiff $outA $outB
    Write-Diff (Join-Path $exp 'diff-input-A.txt') 'input -> A (BeforeAndAfter)' $dInA
    Write-Diff (Join-Path $exp 'diff-input-B.txt') 'input -> B (None)' $dInB
    Write-Diff (Join-Path $exp 'diff-A-B.txt') 'A (BeforeAndAfter) -> B (None)' $dAB
    $assignLines = [ordered]@{}
    for ($i = 0; $i -lt $outA.Count; $i++) { if ($outA[$i] -match ':=' ) { $assignLines["A:$($i + 1)"] = $outA[$i] } }
    for ($i = 0; $i -lt $outB.Count; $i++) { if ($outB[$i] -match ':=' ) { $assignLines["B:$($i + 1)"] = $outB[$i] } }
    $analysis = [ordered]@{
        experiment = 'O2-P01'
        baseProfile = [ordered]@{ manifestId = $baseRecord.id; sha256 = $baseHash }
        profiles = [ordered]@{
            A = [ordered]@{ value = 'BeforeAndAfter'; sha256 = Get-Sha256File $profiles.A; optionCount = $optA.Count }
            B = [ordered]@{ value = 'None'; sha256 = Get-Sha256File $profiles.B; optionCount = $optB.Count }
            parsedOptionDifferencesAB = $diffAB
            parsedOptionDifferencesBaseA = $diffBaseA
        }
        input = [ordered]@{ fixtureId = 'FX-ASSIGN'; sha256 = $fixtureHashBefore; lines = $in.Count }
        argumentTemplate = $template
        outputs = $outputs
        diffs = [ordered]@{ inputToA = $dInA; inputToB = $dInB; aToB = $dAB }
        linesWithAssignOperator = $assignLines
        fixtureUnchanged = (Get-Sha256File $fixture) -eq $fixtureHashBefore
        baseProfileUnchanged = (Get-Sha256File $BaseProfilePath) -eq $baseHash
    }
    [IO.File]::WriteAllText((Join-Path $exp 'analysis.json'), ($analysis | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n", $utf8)
    Write-Output ('O2-P01: A {0} distinct={1}; B {2} distinct={3}; A->B changed lines={4}; input->A={5}; input->B={6}' -f
        $outputs.A.classification, $outputs.A.distinctOutputs, $outputs.B.classification, $outputs.B.distinctOutputs,
        $dAB.Count, $dInA.Count, $dInB.Count)
}

if ('P11' -in $Experiment) {
    $exp = Join-Path $ExperimentRoot "O2-P11-$stamp"
    New-Item -ItemType Directory -Path $exp -Force | Out-Null
    Write-Output "O2-P11 -> $exp"
    $malformed = Join-Path $exp 'malformed-profile.config'
    [IO.File]::WriteAllText($malformed, "<?xml version=`"1.0`"?>`r`n<TgConfig Version=`"3`">`r`n  <Option Name=`"DelphiFormatter.AssignSpaces`"`r`n", $utf8)
    $variants = [ordered]@{
        'success'                   = @{ T = @('-delphi', '-config', '{profile}', '-log', '{log}', '{input}'); I = @($fixture); P = $BaseProfilePath }
        'success-no-log'            = @{ T = @('-delphi', '-config', '{profile}', '{input}'); I = @($fixture); P = $BaseProfilePath }
        'missing-input'             = @{ T = @('-delphi', '-config', '{profile}', '-log', '{log}', '{repDir}\does-not-exist.pas'); I = @(); P = $BaseProfilePath }
        'missing-input-silent'      = @{ T = @('-delphi', '-silent', '-config', '{profile}', '-log', '{log}', '{repDir}\does-not-exist.pas'); I = @(); P = $BaseProfilePath }
        'missing-config'            = @{ T = @('-delphi', '-config', '{repDir}\missing.config', '-log', '{log}', '{input}'); I = @($fixture); P = $null }
        'missing-config-silent'     = @{ T = @('-delphi', '-silent', '-config', '{repDir}\missing.config', '-log', '{log}', '{input}'); I = @($fixture); P = $null }
        'malformed-config'          = @{ T = @('-delphi', '-config', '{profile}', '-log', '{log}', '{input}'); I = @($fixture); P = $malformed; Invalid = $true }
        'malformed-config-silent'   = @{ T = @('-delphi', '-silent', '-config', '{profile}', '-log', '{log}', '{input}'); I = @($fixture); P = $malformed; Invalid = $true }
        'unknown-option'            = @{ T = @('-o2unknown', '{input}'); I = @($fixture); P = $null }
        'unknown-option-silent'     = @{ T = @('-silent', '-o2unknown', '{input}'); I = @($fixture); P = $null }
        'help'                      = @{ T = @('-?'); I = @(); P = $null }
    }
    $summary = [ordered]@{ experiment = 'O2-P11'; repetitionsPerVariant = 2; variants = [ordered]@{} }
    foreach ($k in $variants.Keys) {
        $v = $variants[$k]
        Write-Output "- $k"
        $r = Invoke-Runner (Join-Path $exp 'runs') "P11-$k" $v.T $v.I $v.P 2 -AllowInvalid:([bool]$v['Invalid'])
        $reps = $r.Result.repetitionResults
        $logs = @($reps | ForEach-Object { $f = Join-Path $r.Dir "$($_.directory)/formatter.log"; (Test-Path $f) ? [IO.File]::ReadAllText($f) : $null })
        $summary.variants[$k] = [ordered]@{
            runId = $r.Result.runId; argumentTemplate = $v.T; runnerClassification = $r.Result.classification
            states = @($reps | ForEach-Object state); exitCodes = @($reps | ForEach-Object exitCode)
            killed = @($reps | ForEach-Object killed); dialogClosedByRunner = @($reps | ForEach-Object dialogClosedByRunner)
            durationMs = @($reps | ForEach-Object durationMs)
            stdout = @($reps | ForEach-Object stdout); stderr = @($reps | ForEach-Object stderr)
            logs = $logs
            dialogTexts = @($reps | ForEach-Object { $_.dialogTexts })
            inputChanged = @($reps | ForEach-Object { @($_.changed | Where-Object { $_ -like '*.pas' }).Count -gt 0 })
            createdFiles = @($reps | ForEach-Object { $_.created } | Sort-Object -Unique)
            deterministic = $r.Result.determinism.deterministic
            guardIssues = $r.Result.guardIssues
        }
    }
    $summary.fixtureUnchanged = (Get-Sha256File $fixture) -eq $fixtureHashBefore
    [IO.File]::WriteAllText((Join-Path $exp 'p11-summary.json'), ($summary | ConvertTo-Json -Depth 8).Replace("`r`n", "`n") + "`n", $utf8)
    Write-Output "O2-P11 summary: $(Join-Path $exp 'p11-summary.json')"
}
