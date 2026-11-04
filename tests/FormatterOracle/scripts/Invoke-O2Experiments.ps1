#requires -Version 7.0
<#
.SYNOPSIS
Runs the O2 oracle experiments P01 (AssignSpaces) and/or P11 (invocation/failure behavior) and checks their expectations.
.DESCRIPTION
All work happens in a new experiment directory below tests/FormatterOracle/local/runs (git-ignored).
P01 derives two complete profiles from one original profile (default: the shipped
Formatter_Default.config next to Formatter.exe, hash-checked against the reference manifest), changes
only DelphiFormatter.AssignSpaces (A=BeforeAndAfter, B=None), proves by parsing that this is the only
option difference, runs both variants with -Repetitions copies of O1AssignSpacing.pas and writes
analysis.json plus unified line diffs (input->A, input->B, A->B).
P11 runs a fixed set of normal and faulty invocations and writes p11-summary.json.

Both result files keep the raw observations and add an evaluation. Three levels stay separate:
  executionStatus    was the experiment executed (executed, partial, not-executed),
  assertionStatus    did the observations meet the fixed expectations (see below),
  compatibilityClaim always "none": passing says nothing about Formatter4Delphi.
A runner classification describes one formatter call. An expected failing call can pass here.

Reference hashes come from the executed run records of -ReferenceManifest. A recorded hash is only
applied when formatter hash, profile hash, input hash, argument list and culture settings all match
that record. Otherwise the run is new-unconfirmed and never counts as passed. This script never
writes to a manifest; a new reference needs a manual review (see README).

Exit codes (worst experiment wins): 0 passed; 1 failed; 2 blocked (precondition, not executed);
3 unconfirmed (expectations met, but no matching reference evidence).
Nothing outside the experiment directory is written; %APPDATA% profiles are guarded by the runner.
-ArgumentPrefix, -HelpArgument, -FixturePath and -ProtectedPath exist for the self-tests.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FormatterPath,
    [ValidateSet('P01', 'P11')][string[]]$Experiment = @('P01', 'P11'),
    [string]$BaseProfilePath,
    [int]$Repetitions = 3,
    [int]$TimeoutSeconds = 60,
    [string]$ExperimentRoot,
    [string]$ReferenceManifest,
    [string]$FixturePath,
    [switch]$AcceptUnknownFormatter,
    [string[]]$ArgumentPrefix = @(),
    [string]$HelpArgument = '-?',
    [string[]]$ProtectedPath = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$oracle = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'RunFormatterOracle.ps1'
if (-not $ExperimentRoot) { $ExperimentRoot = Join-Path $oracle 'local/runs' }
if (-not $ReferenceManifest) { $ReferenceManifest = Join-Path $oracle 'manifest/o2-manifest.json' }
if (-not $FixturePath) { $FixturePath = Join-Path $oracle 'fixtures/delphi/O1AssignSpacing.pas' }
if (-not $BaseProfilePath) { $BaseProfilePath = Join-Path (Split-Path -Parent $FormatterPath) 'config/Formatter_Default.config' }
$fixture = $FixturePath
$inputName = 'O1AssignSpacing.pas'
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
    # Result is $null when the runner refused a precondition (exit 2); nothing was executed then.
    $launch = $ArgumentPrefix + @($Template | ForEach-Object { $_ -ceq '-?' ? $HelpArgument : $_ })
    $params = @{ FormatterPath = $FormatterPath; ArgumentTemplate = $launch; RunName = $Name; RunRoot = $RunRoot; Repetitions = $Reps
        TimeoutSeconds = $TimeoutSeconds; Manifest = $ReferenceManifest }
    if ($Inputs) { $params.InputPath = $Inputs }
    if ($Profile) { $params.ProfilePath = $Profile }
    if ($AllowInvalid) { $params.AllowInvalidProfile = $true }
    if ($ProtectedPath) { $params.ProtectedPath = $ProtectedPath }
    if ($AcceptUnknownFormatter) { $params.ExpectedFormatterSha256 = $formatterHash }
    $out = & $runner @params
    $code = $LASTEXITCODE
    $out | ForEach-Object { Write-Host "  $_" }
    if ($code -eq 2) { return [pscustomobject]@{ ExitCode = 2; Dir = $null; Result = $null; Output = ($out -join ' ') } }
    $dir = Get-ChildItem -LiteralPath $RunRoot -Directory | Where-Object Name -match "^$([regex]::Escape($Name))-\d{8}T\d{9}Z$" | Sort-Object Name | Select-Object -Last 1
    if (-not $dir -or -not (Test-Path (Join-Path $dir.FullName 'run-result.json'))) { throw "Runner produced no result for $Name (exit $code)." }
    [pscustomobject]@{ ExitCode = $code; Dir = $dir.FullName; Result = ([IO.File]::ReadAllText((Join-Path $dir.FullName 'run-result.json')) | ConvertFrom-Json -AsHashtable); Output = ($out -join ' ') }
}

# ---- Evaluation ------------------------------------------------------------------------------
function New-Evaluation {
    [ordered]@{
        executionStatus = 'not-executed'; assertionStatus = 'blocked'; compatibilityClaim = 'none'
        reference = [ordered]@{ status = 'not-evaluated'; variants = [ordered]@{} }
        assertions = [Collections.Generic.List[object]]::new()
        failureReasons = [Collections.Generic.List[string]]::new()
        blockedReasons = [Collections.Generic.List[string]]::new()
    }
}

function ConvertTo-Comparable($Value) { ConvertTo-Json -InputObject $Value -Compress -Depth 6 }

function Add-Assertion($Evaluation, [string]$Id, [string]$Description, $Expected, $Actual, [string]$Variant = $null) {
    $ok = (ConvertTo-Comparable $Expected) -ceq (ConvertTo-Comparable $Actual)
    $Evaluation.assertions.Add([ordered]@{
        id = $Id; variant = $Variant; description = $Description
        result = $ok ? 'passed' : 'failed'; expected = $Expected; actual = $Actual
    })
    if (-not $ok) {
        $where = $Variant ? "$Variant/" : ''
        $Evaluation.failureReasons.Add("$where$($Id): expected $(ConvertTo-Comparable $Expected), actual $(ConvertTo-Comparable $Actual)")
    }
}

function Add-Blocked($Evaluation, [string]$Id, [string]$Reason) {
    $Evaluation.assertions.Add([ordered]@{ id = $Id; variant = $null; description = $Reason; result = 'blocked'; expected = $null; actual = $null })
    $Evaluation.blockedReasons.Add("$($Id): $Reason")
}

function Complete-Evaluation($Evaluation) {
    $Evaluation.assertionStatus = if ($Evaluation.failureReasons.Count) { 'failed' }
        elseif ($Evaluation.blockedReasons.Count -or -not $Evaluation.assertions.Count) { 'blocked' }
        elseif ($Evaluation.reference.status -eq 'regression') { 'passed' }
        else { 'unconfirmed' }
}

function Find-ReferenceRun([string]$RunId) {
    foreach ($x in $reference.experiments) {
        if ($x.status -ne 'executed') { continue }
        foreach ($r in $x.runs) { if ($r.runId -ceq $RunId) { return $r } }
    }
    $null
}

function Get-ReferenceBinding([string]$RunId, [string[]]$Template, [string]$ProfileHash, [string]$InputHash, $RunResult) {
    # A recorded output hash is a golden only for the exact artifact combination that produced it.
    $record = Find-ReferenceRun $RunId
    $mismatches = [Collections.Generic.List[object]]::new()
    if ($null -eq $record) { $mismatches.Add([ordered]@{ field = 'record'; expected = $RunId; actual = $null }) }
    else {
        $envRecord = $reference.environments | Where-Object id -eq $record.environmentId | Select-Object -First 1
        $actualEnv = $RunResult.environment
        $pairs = @(
            @('formatterSha256', $record.formatterSha256, $RunResult.formatter.sha256),
            @('profileSha256', $record.profileSha256, ($ProfileHash ? $ProfileHash : $null)),
            @('inputSha256', $record.inputSha256, ($InputHash ? $InputHash : $null)),
            @('arguments', (ConvertTo-Comparable @($record.commandLine | Select-Object -Skip 1)), (ConvertTo-Comparable @($Template))),
            @('culture', $envRecord.culture, $actualEnv.culture),
            @('uiCulture', $envRecord.uiCulture, $actualEnv.uiCulture),
            @('ansiCodePage', $envRecord.ansiCodePage, $actualEnv.ansiCodePage))
        foreach ($p in $pairs) {
            if ([string]$p[1] -cne [string]$p[2]) { $mismatches.Add([ordered]@{ field = $p[0]; expected = $p[1]; actual = $p[2] }) }
        }
    }
    [ordered]@{ bound = $mismatches.Count -eq 0; expectedOutputSha256 = ($mismatches.Count -eq 0) ? $record.outputSha256 : $null; mismatches = $mismatches }
}

function Get-RepHash($Rep, [string]$Name) {
    $Rep.filesAfter.Contains($Name) ? $Rep.filesAfter[$Name].sha256 : $null
}

function Add-CommonAssertions($Evaluation, [string]$Prefix, [string]$Variant, $Run, [int]$Reps, [string]$State, $Exit, [string]$Class, [string]$InputHash, [string[]]$ChangedExpected, [string[]]$CreatedExpected) {
    $repsResult = @($Run.Result.repetitionResults)
    Add-Assertion $Evaluation "$Prefix-REPETITIONS" 'All requested repetitions ran' $Reps $repsResult.Count $Variant
    Add-Assertion $Evaluation "$Prefix-STATE" 'Process state in every repetition' @($repsResult | ForEach-Object { $State }) @($repsResult | ForEach-Object state) $Variant
    Add-Assertion $Evaluation "$Prefix-EXIT" 'Exit code in every repetition' @($repsResult | ForEach-Object { $Exit }) @($repsResult | ForEach-Object exitCode) $Variant
    Add-Assertion $Evaluation "$Prefix-CLASSIFICATION" 'Runner classification' $Class $Run.Result.classification $Variant
    Add-Assertion $Evaluation "$Prefix-KILLED" 'No repetition needed a kill' $false (@($repsResult | Where-Object killed).Count -gt 0) $Variant
    Add-Assertion $Evaluation "$Prefix-GUARD" 'No guarded file changed' @() @($Run.Result.guardIssues) $Variant
    Add-Assertion $Evaluation "$Prefix-DETERMINISTIC" 'State, exit code and file hashes equal over repetitions' $true ([bool]$Run.Result.determinism.deterministic) $Variant
    foreach ($rep in $repsResult) {
        $tag = "$Variant/$($rep.directory)"
        if ($InputHash) { Add-Assertion $Evaluation "$Prefix-INPUT-COPY" 'Input copy equals the fixture before the run' $InputHash ($rep.filesBefore.Contains($inputName) ? $rep.filesBefore[$inputName].sha256 : $null) $tag }
        Add-Assertion $Evaluation "$Prefix-FILES-CHANGED" 'Exactly the expected files changed' @($ChangedExpected | Where-Object { $_ }) @($rep.changed | Sort-Object) $tag
        Add-Assertion $Evaluation "$Prefix-FILES-CREATED" 'Exactly the expected files were created' @($CreatedExpected | Where-Object { $_ }) @($rep.created | Sort-Object) $tag
        Add-Assertion $Evaluation "$Prefix-FILES-DELETED" 'No file was deleted' @() @($rep.deleted) $tag
    }
}

function Test-OnlyAssignSpacing([string]$PathA, [string]$PathB) {
    # True when B equals A after removing the blanks around := outside string literals.
    $a = [IO.File]::ReadAllText($PathA) -split "`r`n"
    $b = [IO.File]::ReadAllText($PathB) -split "`r`n"
    if ($a.Count -ne $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) {
        $normal = (([regex]::Split($a[$i], "('(?:[^']|'')*')") | ForEach-Object { $_.StartsWith("'") ? $_ : $_.Replace(' := ', ':=') }) -join '')
        $isComment = $a[$i].TrimStart().StartsWith('//') -or $a[$i].TrimStart().StartsWith('{')
        if ($a[$i] -cne $b[$i] -and ($isComment -or $normal -cne $b[$i])) { return $false }
    }
    $true
}

function Test-Preconditions($Evaluation) {
    # Fills the reference data; any finding blocks the experiment before anything runs.
    if (-not (Test-Path -LiteralPath $FormatterPath -PathType Leaf)) { Add-Blocked $Evaluation 'PRE-FORMATTER' 'Formatter executable not found.'; return }
    $script:formatterHash = Get-Sha256File $FormatterPath
    if (-not (Test-Path -LiteralPath $ReferenceManifest -PathType Leaf)) { Add-Blocked $Evaluation 'PRE-MANIFEST' 'Reference manifest not found.'; return }
    $script:reference = [IO.File]::ReadAllText($ReferenceManifest) | ConvertFrom-Json
    if (-not $AcceptUnknownFormatter -and @($reference.toolchains | Where-Object { $_.formatter.exe.sha256 -eq $formatterHash }).Count -eq 0) {
        Add-Blocked $Evaluation 'PRE-FORMATTER-HASH' "Formatter hash $formatterHash is in no reference toolchain; use -AcceptUnknownFormatter for an unconfirmed run."
    }
    $record = $reference.fixtures | Where-Object id -eq 'FX-ASSIGN' | Select-Object -First 1
    if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { Add-Blocked $Evaluation 'PRE-INPUT' 'Input fixture not found.' }
    elseif ($null -eq $record -or (Get-Sha256File $fixture) -ne $record.sha256) { Add-Blocked $Evaluation 'PRE-INPUT-HASH' 'Input fixture hash does not match the reference record FX-ASSIGN.' }
    if (-not (Test-Path -LiteralPath $BaseProfilePath -PathType Leaf)) { Add-Blocked $Evaluation 'PRE-BASE-PROFILE' 'Base profile not found.'; return }
    $hash = Get-Sha256File $BaseProfilePath
    $script:baseRecord = $reference.profiles | Where-Object sha256 -eq $hash | Where-Object origin -eq 'shipped' | Select-Object -First 1
    if ($null -eq $baseRecord) { Add-Blocked $Evaluation 'PRE-BASE-PROFILE-HASH' "Base profile hash $hash is not a shipped profile in the reference manifest." }
}

# ---- O2-P01 ----------------------------------------------------------------------------------
function Invoke-P01($Evaluation, [string]$Exp, $Data) {
    Test-Preconditions $Evaluation
    if ($Evaluation.blockedReasons.Count) { return }
    New-Item -ItemType Directory -Path (Join-Path $Exp 'profiles') -Force | Out-Null
    $baseHash = Get-Sha256File $BaseProfilePath
    $inputHash = Get-Sha256File $fixture
    $baseText = [IO.File]::ReadAllText($BaseProfilePath)
    $pattern = '(<Option Name="DelphiFormatter\.AssignSpaces"[^>]*?\sValue=")([^"]*)(")'
    if ([regex]::Matches($baseText, $pattern).Count -ne 1) { Add-Blocked $Evaluation 'PRE-BASE-OPTION' 'Base profile must contain exactly one DelphiFormatter.AssignSpaces option.'; return }
    $profiles = [ordered]@{}
    foreach ($v in @(@('A', 'BeforeAndAfter'), @('B', 'None'))) {
        $p = Join-Path $Exp "profiles/P01-$($v[0])-AssignSpaces-$($v[1]).config"
        $text = [regex]::Replace($baseText, $pattern, { param($mm) $mm.Groups[1].Value + $v[1] + $mm.Groups[3].Value })
        [IO.File]::WriteAllBytes($p, [Text.Encoding]::Latin1.GetBytes($text)) # base is ASCII without BOM; keep bytes 1:1
        $profiles[$v[0]] = $p
    }
    $optA = Read-Options $profiles.A; $optB = Read-Options $profiles.B; $optBase = Read-Options $BaseProfilePath
    $diffAB = @($optA.Keys | Where-Object { $optA[$_] -cne $optB[$_] }) + @($optB.Keys | Where-Object { -not $optA.Contains($_) })
    $Data.baseProfile = [ordered]@{ manifestId = $baseRecord.id; sha256 = $baseHash }
    $Data.profiles = [ordered]@{
        A = [ordered]@{ value = 'BeforeAndAfter'; sha256 = Get-Sha256File $profiles.A; optionCount = $optA.Count }
        B = [ordered]@{ value = 'None'; sha256 = Get-Sha256File $profiles.B; optionCount = $optB.Count }
        parsedOptionDifferencesAB = $diffAB
        parsedOptionDifferencesBaseA = @($optA.Keys | Where-Object { $optA[$_] -cne $optBase[$_] })
    }
    $Data.input = [ordered]@{ fixtureId = 'FX-ASSIGN'; sha256 = $inputHash }
    $template = @('-delphi', '-config', '{profile}', '-log', '{log}', '{input}')
    $Data.argumentTemplate = $template
    Add-Assertion $Evaluation 'P01-PROFILE-DELTA' 'A and B differ only in DelphiFormatter.AssignSpaces' @('DelphiFormatter.AssignSpaces') $diffAB
    Add-Assertion $Evaluation 'P01-PROFILE-COUNT' 'A and B keep all options of the base profile' @($optBase.Count, $optBase.Count) @($optA.Count, $optB.Count)
    Add-Assertion $Evaluation 'P01-MIN-REPETITIONS' 'At least three repetitions per variant' $true ($Repetitions -ge 3)

    $runs = [ordered]@{}
    foreach ($k in 'A', 'B') {
        $run = Invoke-Runner (Join-Path $Exp 'runs') "P01-$k" $template @($fixture) $profiles[$k] $Repetitions
        if ($null -eq $run.Result) { Add-Blocked $Evaluation 'PRE-RUNNER' "Runner refused P01-$($k): $($run.Output)"; return }
        $Evaluation.executionStatus = $k -eq 'A' ? 'partial' : 'executed'
        $runs[$k] = $run
    }

    $outputs = [ordered]@{}
    $Data.outputs = $outputs
    $Data.environment = $runs.A.Result.environment
    foreach ($k in 'A', 'B') {
        $r = $runs[$k].Result
        $hashes = @($r.repetitionResults | ForEach-Object { Get-RepHash $_ $inputName })
        $outputs[$k] = [ordered]@{
            runId = $r.runId; classification = $r.classification
            states = @($r.repetitionResults | ForEach-Object state)
            exitCodes = @($r.repetitionResults | ForEach-Object exitCode)
            outputSha256 = $hashes; distinctOutputs = @($hashes | Sort-Object -Unique).Count
            createdFiles = @($r.repetitionResults | ForEach-Object { $_.created } | Sort-Object -Unique)
        }
        Add-CommonAssertions $Evaluation 'P01' $k $runs[$k] $Repetitions 'exited' 0 'success' $inputHash @($inputName) @('formatter.log')
        Add-Assertion $Evaluation 'P01-OUTPUT-PRESENT' 'Every repetition left an output file' @($hashes | ForEach-Object { $true }) @($hashes | ForEach-Object { $null -ne $_ }) $k
        Add-Assertion $Evaluation 'P01-OUTPUT-IDENTICAL' 'One output hash over all repetitions' 1 $outputs[$k].distinctOutputs $k
        $binding = Get-ReferenceBinding "O2-P01-$k" $template $Data.profiles[$k].sha256 $inputHash $r
        $binding.actualOutputSha256 = @($hashes | Sort-Object -Unique)
        $Evaluation.reference.variants[$k] = $binding
        if ($binding.bound) {
            Add-Assertion $Evaluation 'P01-GOLDEN' 'Output equals the reference hash of this exact combination' @($binding.expectedOutputSha256) $binding.actualOutputSha256 $k
        }
    }
    $Evaluation.reference.status = @($Evaluation.reference.variants.Values | Where-Object { -not $_.bound }).Count -eq 0 ? 'regression' : 'new-unconfirmed'

    $pathA = Join-Path $runs.A.Dir "rep-01/$inputName"; $pathB = Join-Path $runs.B.Dir "rep-01/$inputName"
    if ((Test-Path -LiteralPath $pathA) -and (Test-Path -LiteralPath $pathB)) {
        $in = Split-Lines $fixture
        $outA = Split-Lines $pathA; $outB = Split-Lines $pathB
        $dInA = Get-LineDiff $in $outA; $dInB = Get-LineDiff $in $outB; $dAB = Get-LineDiff $outA $outB
        Write-Diff (Join-Path $Exp 'diff-input-A.txt') 'input -> A (BeforeAndAfter)' $dInA
        Write-Diff (Join-Path $Exp 'diff-input-B.txt') 'input -> B (None)' $dInB
        Write-Diff (Join-Path $Exp 'diff-A-B.txt') 'A (BeforeAndAfter) -> B (None)' $dAB
        $Data.diffs = [ordered]@{ inputToA = $dInA; inputToB = $dInB; aToB = $dAB }
        Add-Assertion $Evaluation 'P01-AB-DIFFER' 'AssignSpaces changes the output' $true ((Get-Sha256File $pathA) -ne (Get-Sha256File $pathB))
        Add-Assertion $Evaluation 'P01-AB-ONLY-ASSIGN' 'A and B differ only in blanks around := outside strings and comments' $true (Test-OnlyAssignSpacing $pathA $pathB)
        foreach ($line in @("  S := 'x:=y';", '  { comment with A:=B inside }', '  // line comment with C  :=  D')) {
            Add-Assertion $Evaluation 'P01-DECOY-A' 'String and comment decoy stays byte-identical in A' $true (@(([IO.File]::ReadAllText($pathA) -split "`r`n") | Where-Object { $_ -ceq $line }).Count -eq 1) $line
        }
    }
    Add-Assertion $Evaluation 'P01-FIXTURE-UNCHANGED' 'Original fixture unchanged' $inputHash (Get-Sha256File $fixture)
    Add-Assertion $Evaluation 'P01-BASE-UNCHANGED' 'Original profile unchanged' $baseHash (Get-Sha256File $BaseProfilePath)
}

# ---- O2-P11 ----------------------------------------------------------------------------------
function Invoke-P11($Evaluation, [string]$Exp, $Data) {
    Test-Preconditions $Evaluation
    if ($Evaluation.blockedReasons.Count) { return }
    $malformed = Join-Path $Exp 'malformed-profile.config'
    [IO.File]::WriteAllText($malformed, "<?xml version=`"1.0`"?>`r`n<TgConfig Version=`"3`">`r`n  <Option Name=`"DelphiFormatter.AssignSpaces`"`r`n", $utf8)
    $inputHash = Get-Sha256File $fixture
    $baseHash = Get-Sha256File $BaseProfilePath
    $normal = @('-delphi', '-config', '{profile}', '-log', '{log}', '{input}')
    $missing = '{repDir}\does-not-exist.pas'
    $missingConfig = '{repDir}\missing.config'
    # D=dialog, Exit, Changed=input formatted ($null: no input), Log=formatter.log created, Pattern and Channel of the message.
    $variants = [ordered]@{
        'success'                 = @{ T = $normal; I = @($fixture); P = $BaseProfilePath; D = $false; Exit = 0; Changed = $true; Log = $true; Pattern = 'Formatting file'; Channel = 'log' }
        'success-no-log'          = @{ T = @('-delphi', '-config', '{profile}', '{input}'); I = @($fixture); P = $BaseProfilePath; D = $false; Exit = 0; Changed = $true; Log = $false; Pattern = 'Formatting file'; Channel = 'stdout' }
        'missing-input'           = @{ T = @('-delphi', '-config', '{profile}', '-log', '{log}', $missing); I = @(); P = $BaseProfilePath; D = $true; Exit = 1; Changed = $null; Log = $true; Pattern = "doesn't exist"; Channel = 'log' }
        'missing-input-silent'    = @{ T = @('-delphi', '-silent', '-config', '{profile}', '-log', '{log}', $missing); I = @(); P = $BaseProfilePath; D = $false; Exit = 1; Changed = $null; Log = $true; Pattern = "doesn't exist"; Channel = 'log' }
        'missing-config'          = @{ T = @('-delphi', '-config', $missingConfig, '-log', '{log}', '{input}'); I = @($fixture); P = $null; D = $true; Exit = 1; Changed = $false; Log = $true; Pattern = 'Cannot load config file'; Channel = 'log' }
        'missing-config-silent'   = @{ T = @('-delphi', '-silent', '-config', $missingConfig, '-log', '{log}', '{input}'); I = @($fixture); P = $null; D = $false; Exit = 1; Changed = $false; Log = $true; Pattern = 'Cannot load config file'; Channel = 'log' }
        'malformed-config'        = @{ T = $normal; I = @($fixture); P = $malformed; Invalid = $true; D = $true; Exit = 1; Changed = $false; Log = $true; Pattern = 'Unable to load config options'; Channel = 'log' }
        'malformed-config-silent' = @{ T = @('-delphi', '-silent', '-config', '{profile}', '-log', '{log}', '{input}'); I = @($fixture); P = $malformed; Invalid = $true; D = $false; Exit = 1; Changed = $false; Log = $true; Pattern = 'Unable to load config options'; Channel = 'log' }
        'unknown-option'          = @{ T = @('-o2unknown', '{input}'); I = @($fixture); P = $null; D = $true; Exit = 1; Changed = $false; Log = $false; Pattern = "-o2unknown doesn't exist"; Channel = 'stdout' }
        'unknown-option-silent'   = @{ T = @('-silent', '-o2unknown', '{input}'); I = @($fixture); P = $null; D = $false; Exit = 1; Changed = $false; Log = $false; Pattern = "-o2unknown doesn't exist"; Channel = 'stdout' }
        'help'                    = @{ T = @('-?'); I = @(); P = $null; D = $true; Exit = 1; Changed = $null; Log = $false; Pattern = 'Syntax:'; Channel = 'dialog' }
    }
    $Data.repetitionsPerVariant = 2
    $Data.variants = [ordered]@{}
    $allBound = $true
    foreach ($k in $variants.Keys) {
        $v = $variants[$k]
        Write-Host "- $k"
        $r = Invoke-Runner (Join-Path $Exp 'runs') "P11-$k" $v.T $v.I $v.P 2 -AllowInvalid:([bool]$v['Invalid'])
        if ($null -eq $r.Result) { Add-Blocked $Evaluation 'PRE-RUNNER' "Runner refused P11-$($k): $($r.Output)"; return }
        $Evaluation.executionStatus = 'partial'
        $reps = @($r.Result.repetitionResults)
        $logs = @($reps | ForEach-Object { $f = Join-Path $r.Dir "$($_.directory)/formatter.log"; (Test-Path $f) ? [IO.File]::ReadAllText($f) : $null })
        $Data.variants[$k] = [ordered]@{
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
        $Data.environment = $r.Result.environment
        $class = $v.D ? 'aborted' : ($v.Exit -eq 0 ? 'success' : 'formatter-error')
        $hasInput = $v.I.Count -gt 0
        Add-CommonAssertions $Evaluation 'P11' $k $r 2 ($v.D ? 'dialog' : 'exited') $v.Exit $class ($hasInput ? $inputHash : $null) @(($v.Changed -eq $true) ? $inputName : $null) @($v.Log ? 'formatter.log' : $null)
        Add-Assertion $Evaluation 'P11-DIALOG' 'Dialog appears exactly when expected' @($reps | ForEach-Object { $v.D }) @($reps | ForEach-Object { @($_.dialogTexts).Count -gt 0 }) $k
        foreach ($i in 0..($reps.Count - 1)) {
            $text = switch ($v.Channel) {
                'log' { $logs[$i] }
                'stdout' { $reps[$i].stdout }
                'dialog' { @($reps[$i].dialogTexts) -join "`n" }
            }
            Add-Assertion $Evaluation 'P11-MESSAGE' "Message '$($v.Pattern)' on $($v.Channel)" $true ([string]$text -match [regex]::Escape($v.Pattern)) "$k/$($reps[$i].directory)"
            if ($v.D) { Add-Assertion $Evaluation 'P11-DIALOG-MESSAGE' "Dialog shows '$($v.Pattern)'" $true ((@($reps[$i].dialogTexts) -join "`n") -match [regex]::Escape($v.Pattern)) "$k/$($reps[$i].directory)" }
            if ($hasInput -and $v.Changed -eq $false) {
                Add-Assertion $Evaluation 'P11-INPUT-UNCHANGED' 'Failed call leaves the input copy unchanged' $inputHash (Get-RepHash $reps[$i] $inputName) "$k/$($reps[$i].directory)"
            }
        }
        $profileHash = $v.P ? (Get-Sha256File $v.P) : $null
        $binding = Get-ReferenceBinding "O2-P11-$k" $v.T $profileHash ($hasInput ? $inputHash : $null) $r.Result
        $hashes = $hasInput ? @($reps | ForEach-Object { Get-RepHash $_ $inputName } | Sort-Object -Unique) : @()
        $binding.actualOutputSha256 = $hashes
        $Evaluation.reference.variants[$k] = $binding
        if (-not $binding.bound) { $allBound = $false }
        elseif ($hasInput) { Add-Assertion $Evaluation 'P11-GOLDEN' 'Output equals the reference hash of this exact combination' @($binding.expectedOutputSha256) $hashes $k }
    }
    $Evaluation.executionStatus = 'executed'
    $Evaluation.reference.status = $allBound ? 'regression' : 'new-unconfirmed'
    Add-Assertion $Evaluation 'P11-FIXTURE-UNCHANGED' 'Original fixture unchanged' $inputHash (Get-Sha256File $fixture)
    Add-Assertion $Evaluation 'P11-BASE-UNCHANGED' 'Original profile unchanged' $baseHash (Get-Sha256File $BaseProfilePath)
}

# ---- Series ----------------------------------------------------------------------------------
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$formatterHash = $null; $reference = $null; $baseRecord = $null
$statuses = [Collections.Generic.List[string]]::new()
foreach ($name in $Experiment) {
    $exp = Join-Path $ExperimentRoot "O2-$name-$stamp"
    New-Item -ItemType Directory -Path $exp -Force | Out-Null
    Write-Output "O2-$name -> $exp"
    $evaluation = New-Evaluation
    $data = [ordered]@{ experiment = "O2-$name" }
    try {
        if ($name -eq 'P01') { Invoke-P01 $evaluation $exp $data } else { Invoke-P11 $evaluation $exp $data }
    } catch {
        # An exception must not look like success or lose what was measured so far.
        $evaluation.failureReasons.Add("EXCEPTION: $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)")
    }
    Complete-Evaluation $evaluation
    foreach ($key in $evaluation.Keys) { $data[$key] = $evaluation[$key] }
    $data.evaluatedAgainst = [IO.Path]::GetFileName($ReferenceManifest)
    $resultPath = Join-Path $exp ($name -eq 'P01' ? 'analysis.json' : 'p11-summary.json')
    [IO.File]::WriteAllText($resultPath, ($data | ConvertTo-Json -Depth 12).Replace("`r`n", "`n") + "`n", $utf8)
    $statuses.Add($evaluation.assertionStatus)
    $counts = $evaluation.assertions | Group-Object { $_.result } | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Output ('O2-{0}: assertionStatus={1}; executionStatus={2}; reference={3}; assertions {4}; result {5}' -f $name, $evaluation.assertionStatus,
        $evaluation.executionStatus, $evaluation.reference.status, ($counts -join ' '), $resultPath)
    foreach ($reason in @($evaluation.failureReasons) + @($evaluation.blockedReasons)) { Write-Output "  $reason" }
}
$exitCode = if ($statuses -contains 'failed') { 1 } elseif ($statuses -contains 'blocked') { 2 } elseif ($statuses -contains 'unconfirmed') { 3 } else { 0 }
exit $exitCode
