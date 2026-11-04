#requires -Version 7.0
<#
.SYNOPSIS
Self-tests for RunFormatterOracle.ps1 and Invoke-O2Experiments.ps1 with the controlled stand-in FakeFormatter.ps1; needs no RAD Studio.
.DESCRIPTION
The stand-in is started as "pwsh -File FakeFormatter.ps1 <mode> {input}" through the runner, with the
pwsh executable's own hash as expected formatter hash. Results are asserted from run-result.json and
the files on disk, not only from exit codes. Runs go to a temporary directory outside the repository.
Exit 0 = all passed, 1 = failures.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$oracle = Split-Path -Parent $PSScriptRoot
$repo = [IO.Path]::GetFullPath((Join-Path $oracle '../..'))
$runner = Join-Path $PSScriptRoot 'RunFormatterOracle.ps1'
$fake = Join-Path $PSScriptRoot 'FakeFormatter.ps1'
# The stand-in host: pwsh.exe, or dotnet.exe + pwsh.dll when PowerShell runs as a dotnet global tool.
$pwsh = [Environment]::ProcessPath
$hostArgs = @()
if ([IO.Path]::GetFileNameWithoutExtension($pwsh) -ne 'pwsh') { $hostArgs = @((Join-Path $PSHOME 'pwsh.dll')) }
$pwshHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($pwsh)))
$fixture = Join-Path $oracle 'fixtures/delphi/O1AssignSpacing.pas'
$profile = Join-Path $oracle 'fixtures/profiles/O1MinimalAssignNone.config'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('f4d-oracle-runner-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$failures = [Collections.Generic.List[string]]::new()
$passed = 0

function Check([bool]$Condition, [string]$Name) {
    if ($Condition) { $script:passed++ } else { $script:failures.Add($Name) }
}
function Get-Sha([string]$Path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path))) }

function Invoke-Fake([string]$Name, [string]$Mode, [hashtable]$Extra = @{}, [string[]]$Tail = @()) {
    $params = @{
        FormatterPath = $pwsh; ExpectedFormatterSha256 = $pwshHash
        ArgumentTemplate = $hostArgs + @('-NoProfile', '-NonInteractive', '-File', $fake, $Mode, '{input}') + $Tail
        InputPath = @($fixture); RunName = $Name; RunRoot = (Join-Path $temp 'runs'); Repetitions = 1; TimeoutSeconds = 30
    }
    foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
    $output = & $runner @params
    $code = $LASTEXITCODE
    $dir = Get-ChildItem -LiteralPath (Join-Path $temp 'runs') -Directory -Filter "$Name-*" -ErrorAction SilentlyContinue | Select-Object -First 1
    $result = ($dir -and (Test-Path (Join-Path $dir.FullName 'run-result.json'))) ?
        ([IO.File]::ReadAllText((Join-Path $dir.FullName 'run-result.json')) | ConvertFrom-Json -AsHashtable) : $null
    [pscustomobject]@{ ExitCode = $code; Output = ($output -join "`n"); Dir = $dir ? $dir.FullName : $null; Result = $result }
}

$fixtureHash = Get-Sha $fixture
$profileHash = Get-Sha $profile
try {
    # 1. Successful run, output files and in-place change captured, profile copy untouched.
    $r = Invoke-Fake 'ok' 'format' @{ Repetitions = 3; ProfilePath = $profile }
    Check ($r.ExitCode -eq 0) "ok: exit $($r.ExitCode) $($r.Output)"
    $reps = $r.Result.repetitionResults
    Check ($reps.Count -eq 3 -and @($reps | Where-Object { $_.state -ne 'exited' -or $_.exitCode -ne 0 }).Count -eq 0) 'ok: three exited repetitions with exit 0'
    Check (@($reps[0].created) -contains 'fake-output.txt') 'ok: created output file recorded'
    Check (@($reps[0].changed) -contains 'O1AssignSpacing.pas' -and @($reps[0].changed) -notcontains 'profile-O1MinimalAssignNone.config') 'ok: changed files recorded'
    Check ($reps[0].filesBefore['O1AssignSpacing.pas'].sha256 -eq $fixtureHash) 'ok: before-hash equals fixture'
    $out = Join-Path $r.Dir 'rep-01/O1AssignSpacing.pas'
    Check ((Get-Sha $out) -eq $reps[0].filesAfter['O1AssignSpacing.pas'].sha256) 'ok: after-hash matches file on disk'
    Check ([IO.File]::ReadAllText($out) -match 'A := 1;' -and [IO.File]::ReadAllText($out) -notmatch 'A:=1') 'ok: output content transformed'
    Check ($reps[0].stdout -match 'fake: formatted O1AssignSpacing.pas') 'ok: stdout captured'
    Check ((Get-Content -Raw (Join-Path $r.Dir 'rep-01.process/stdout.txt')) -match 'fake: formatted') 'ok: stdout file written'
    Check ($r.Result.determinism.deterministic -eq $true -and $r.Result.classification -eq 'success') 'ok: deterministic and success'
    Check ($r.Result.formatter.hashCheck -eq 'explicit' -and $r.Result.formatter.sha256 -eq $pwshHash) 'ok: formatter hash recorded'
    Check (@($reps[0].arguments | Where-Object { $_ -like "*$temp*" }).Count -eq 0 -and $reps[0].arguments[-1] -like '<run-dir>*') 'ok: recorded arguments are run-dir relative'
    Check (-not (Test-Path (Join-Path $r.Dir '.lock'))) 'ok: lock file released'
    Check ($reps[0].durationMs -gt 0) 'ok: duration recorded'

    # 2. Non-zero exit code is recorded, not hidden.
    $r = Invoke-Fake 'fail' 'fail'
    Check ($r.ExitCode -eq 1 -and $r.Result.repetitionResults[0].exitCode -eq 3 -and $r.Result.classification -eq 'formatter-error') "fail: exit code 3 not reported as success (runner $($r.ExitCode))"
    Check ($r.Result.repetitionResults[0].stderr -match 'failure requested') 'fail: stderr captured'
    Check (@($r.Result.repetitionResults[0].changed).Count -eq 0) 'fail: no file changed'

    # 3. Timeout kills only the started process tree.
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-Fake 'timeout' 'sleep' @{ TimeoutSeconds = 3 }
    $rep = $r.Result.repetitionResults[0]
    Check ($r.ExitCode -eq 1 -and $rep.state -eq 'timeout' -and $rep.killed -eq $true) "timeout: state=$($rep.state) killed=$($rep.killed)"
    Check ($sw.Elapsed.TotalSeconds -lt 60) 'timeout: runner returned promptly'
    Check ($r.Result.classification -eq 'aborted') 'timeout: classified aborted'
    $leftover = @(Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" | Where-Object { $_.CommandLine -like "*FakeFormatter.ps1*sleep*" })
    Check ($leftover.Count -eq 0) 'timeout: no fake process left'

    # 4. Dialog detection, text capture and controlled termination.
    $r = Invoke-Fake 'dialog' 'dialog' @{ TimeoutSeconds = 30 }
    $rep = $r.Result.repetitionResults[0]
    Check ($r.ExitCode -eq 1 -and $rep.state -eq 'dialog' -and $r.Result.classification -eq 'aborted') "dialog: state=$($rep.state)"
    Check ((@($rep.dialogTexts) -join "`n") -match 'fake dialog text' -and (@($rep.dialogTexts) -join "`n") -match 'Fake Formatter Dialog') 'dialog: text captured'
    Check ($rep.dialogClosedByRunner -or $rep.killed) 'dialog: closed or killed'
    Check ($rep.durationMs -lt 20000) 'dialog: did not wait for timeout'

    # 5. Determinism detection.
    $r = Invoke-Fake 'random' 'random' @{ Repetitions = 3 }
    Check ($r.Result.determinism.deterministic -eq $false -and $r.Result.determinism.perFile['O1AssignSpacing.pas'].distinct -eq 3) 'random: non-determinism detected'

    # 6. Guard on foreign files.
    $foreign = Join-Path $temp 'foreign.txt'
    [IO.File]::WriteAllText($foreign, "original`n")
    $r = Invoke-Fake 'touch' 'touch' @{ ProtectedPath = @($foreign) } @($foreign)
    Check ($r.ExitCode -eq 1 -and (@($r.Result.guardIssues) -join ';') -match 'foreign.txt' -and $r.Result.classification -eq 'guard-violation') 'guard: foreign file change reported'

    # 7. Preconditions: nothing executed, no run directory.
    $before = @(Get-ChildItem (Join-Path $temp 'runs') -Directory).Count
    $r = Invoke-Fake 'badhash' 'format' @{ ExpectedFormatterSha256 = ('0' * 64) }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'does not match' -and -not $r.Dir) 'precondition: wrong formatter hash'
    $r = Invoke-Fake 'manifesthash' 'format' @{ ExpectedFormatterSha256 = $null }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'manifest:TC-') 'precondition: manifest hash check rejects stand-in'
    $r = Invoke-Fake 'noinput' 'format' @{ InputPath = @((Join-Path $temp 'missing.pas')) }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'Input not found') 'precondition: missing input'
    $bad = Join-Path $temp 'bad.config'
    [IO.File]::WriteAllText($bad, '<TgConfig><Option')
    $r = Invoke-Fake 'badprofile' 'format' @{ ProfilePath = $bad }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'not well-formed') 'precondition: malformed profile'
    $foreignXml = Join-Path $temp 'foreign.config'
    [IO.File]::WriteAllText($foreignXml, '<Other/>')
    $r = Invoke-Fake 'foreignprofile' 'format' @{ ProfilePath = $foreignXml }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'expected TgConfig') 'precondition: foreign XML profile'
    Check (@(Get-ChildItem (Join-Path $temp 'runs') -Directory).Count -eq $before) 'precondition: no run directory created'
    $r = Invoke-Fake 'allowinvalid' 'format' @{ ProfilePath = $bad; AllowInvalidProfile = $true }
    Check ($r.ExitCode -eq 0 -and $r.Result.profile.fileName -eq 'bad.config') 'precondition: -AllowInvalidProfile runs'
    $r = Invoke-Fake 'reporoot' 'format' @{ RunRoot = (Join-Path $oracle 'fixtures') }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'below tests/FormatterOracle/local') 'precondition: run root inside repository refused'
    $r = Invoke-Fake 'insideroot' 'format' @{ InputPath = @($foreign); RunRoot = $temp }
    Check ($r.ExitCode -eq 2 -and $r.Output -match 'must not lie inside RunRoot') 'precondition: source inside run root refused'

    # 10. Experiment assertions, end to end through Invoke-O2Experiments.ps1 with the stand-in CLI.
    $experiments = Join-Path $PSScriptRoot 'Invoke-O2Experiments.ps1'
    $baseProfile = Join-Path $temp 'stand-in-base.config'
    Copy-Item -LiteralPath $profile $baseProfile
    $baseHash = Get-Sha $baseProfile
    $realManifests = @((Join-Path $oracle 'manifest/o1-manifest.json'), (Join-Path $oracle 'manifest/o2-manifest.json'))
    $realManifestHashes = @($realManifests | ForEach-Object { Get-Sha $_ })
    $script:experimentCounter = 0

    function Get-AllRuns($Manifest) { foreach ($x in $Manifest.experiments) { foreach ($r in $x.runs) { $r } } }

    function New-Reference([string]$Name, [string]$FormatterHash, [hashtable]$Observed = @{}, $Environment = $null) {
        # Temporary reference: the real O2 records, rebound to the stand-in artifacts.
        $m = [IO.File]::ReadAllText($realManifests[1]) | ConvertFrom-Json -AsHashtable
        $m.toolchains[0].formatter.exe.sha256 = $FormatterHash
        ($m.profiles | Where-Object id -eq 'PR-SHIP-DEFAULT').sha256 = $baseHash
        if ($Environment) { foreach ($k in 'culture', 'uiCulture', 'ansiCodePage') { $m.environments[0][$k] = $Environment[$k] } }
        foreach ($r in Get-AllRuns $m) {
            $r.formatterSha256 = $FormatterHash
            if ($r.profileId -eq 'PR-SHIP-DEFAULT') { $r.profileSha256 = $baseHash }
            if ($Observed.ContainsKey($r.runId)) { foreach ($k in $Observed[$r.runId].Keys) { $r[$k] = $Observed[$r.runId][$k] } }
        }
        $path = Join-Path $temp "$Name.json"
        [IO.File]::WriteAllText($path, ($m | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        $path
    }

    function Invoke-Experiment([string]$Which, [string]$Scenario, [string]$Reference, [hashtable]$Extra = @{}) {
        $script:experimentCounter++
        $root = Join-Path $temp "exp-$($script:experimentCounter)"
        $params = @{
            FormatterPath = $pwsh; Experiment = @($Which); BaseProfilePath = $baseProfile; ExperimentRoot = $root; ReferenceManifest = $Reference
            ArgumentPrefix = $hostArgs + @('-NoProfile', '-NonInteractive', '-File', $fake, 'cli'); HelpArgument = '/fake-help'; TimeoutSeconds = 30
        }
        foreach ($k in $Extra.Keys) { $params[$k] = $Extra[$k] }
        $env:FAKE_ORACLE_SCENARIO = $Scenario
        try { $output = & $experiments @params 6>$null; $code = $LASTEXITCODE } finally { Remove-Item Env:FAKE_ORACLE_SCENARIO -ErrorAction SilentlyContinue }
        $resultFile = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object Name -in 'analysis.json', 'p11-summary.json' | Select-Object -First 1
        [pscustomobject]@{
            ExitCode = $code; Output = ($output -join "`n"); Root = $root; Dir = $resultFile ? $resultFile.DirectoryName : $null
            Data = $resultFile ? ([IO.File]::ReadAllText($resultFile.FullName) | ConvertFrom-Json -AsHashtable) : $null
        }
    }

    function Test-Failed($R, [string]$Name, [string]$AssertionId) {
        Check ($R.ExitCode -eq 1 -and $R.Data.assertionStatus -eq 'failed') "$($Name): exit $($R.ExitCode), status $($R.Data?.assertionStatus): $($R.Output)"
        Check (@($R.Data.failureReasons | Where-Object { $_ -like "*$AssertionId*" }).Count -gt 0) "$($Name): reason $AssertionId missing: $($R.Data.failureReasons -join '; ')"
        Check (@($R.Data.assertions | Where-Object { $_.result -eq 'passed' }).Count -gt 0) "$($Name): other assertions still recorded"
    }

    $scenarioReference = New-Reference 'ref-unbound' $pwshHash
    $first = Invoke-Experiment 'P01' '' $scenarioReference
    Check ($first.ExitCode -eq 3 -and $first.Data.assertionStatus -eq 'unconfirmed') "reference: new combination is unconfirmed (exit $($first.ExitCode)): $($first.Output)"
    Check ($first.Data.reference.status -eq 'new-unconfirmed' -and $first.Data.executionStatus -eq 'executed') 'reference: executed but new-unconfirmed'
    Check (@($first.Data.assertions | Where-Object { $_.id -eq 'P01-GOLDEN' }).Count -eq 0) 'reference: no golden applied to a new combination'
    Check ($first.Data.compatibilityClaim -eq 'none') 'reference: no compatibility claim'
    $firstP11 = Invoke-Experiment 'P11' '' (New-Reference 'ref-unknown-p11' ('0' * 64)) @{ AcceptUnknownFormatter = $true }
    Check ($firstP11.ExitCode -eq 3 -and $firstP11.Data.assertionStatus -eq 'unconfirmed') "p11: unconfirmed without reference (exit $($firstP11.ExitCode)): $($firstP11.Output)"

    $observed = @{
        'O2-P01-A' = @{ profileSha256 = $first.Data.profiles.A.sha256; outputSha256 = $first.Data.outputs.A.outputSha256[0] }
        'O2-P01-B' = @{ profileSha256 = $first.Data.profiles.B.sha256; outputSha256 = $first.Data.outputs.B.outputSha256[0] }
    }
    foreach ($k in 'success', 'success-no-log') { $observed["O2-P11-$k"] = @{ outputSha256 = $firstP11.Data.reference.variants[$k].actualOutputSha256[0] } }
    $boundReference = New-Reference 'ref-bound' $pwshHash $observed $first.Data.environment
    $boundHash = Get-Sha $boundReference

    # Case 1: matching references pass.
    $r = Invoke-Experiment 'P01' '' $boundReference
    Check ($r.ExitCode -eq 0 -and $r.Data.assertionStatus -eq 'passed' -and $r.Data.reference.status -eq 'regression') "p01: passed with reference (exit $($r.ExitCode)): $($r.Output)"
    Check (@($r.Data.assertions | Where-Object { $_.id -eq 'P01-GOLDEN' -and $_.result -eq 'passed' }).Count -eq 2) 'p01: both goldens checked'
    Check ($null -ne $r.Data.outputs.A.exitCodes -and $r.Data.reference.variants.A.bound) 'p01: raw observations kept next to the evaluation'

    # Cases 2 to 6 and raw data retention.
    $r = Invoke-Experiment 'P01' 'wrong-output' $boundReference
    Test-Failed $r 'p01 wrong output' 'A/P01-GOLDEN'
    $golden = @($r.Data.assertions | Where-Object { $_.id -eq 'P01-GOLDEN' -and $_.variant -eq 'A' })[0]
    Check ($golden.result -eq 'failed' -and $golden.expected[0] -eq $observed['O2-P01-A'].outputSha256 -and $golden.actual[0] -ne $golden.expected[0]) 'p01 wrong output: expected and actual hash reported'
    Check (@(Get-ChildItem -LiteralPath $r.Dir -Recurse -Filter 'O1AssignSpacing.pas').Count -eq 6 -and @(Get-ChildItem -LiteralPath $r.Dir -Recurse -Filter 'run-result.json').Count -eq 2) 'p01 wrong output: raw outputs kept'
    Check ((Get-Sha $boundReference) -eq $boundHash) 'p01 wrong output: reference not overwritten'
    Test-Failed (Invoke-Experiment 'P01' 'nondeterministic' $boundReference) 'p01 nondeterministic' 'P01-DETERMINISTIC'
    Test-Failed (Invoke-Experiment 'P01' 'exit3' $boundReference) 'p01 exit code' 'P01-EXIT'
    Test-Failed (Invoke-Experiment 'P01' 'unexpected-dialog' $boundReference) 'p01 dialog' 'P01-STATE'
    $guarded = Join-Path $temp 'guarded.txt'
    [IO.File]::WriteAllText($guarded, "original`n")
    $env:FAKE_ORACLE_GUARD_FILE = $guarded
    try { Test-Failed (Invoke-Experiment 'P01' 'guard' $boundReference @{ ProtectedPath = @($guarded) }) 'p01 guard' 'P01-GUARD' }
    finally { Remove-Item Env:FAKE_ORACLE_GUARD_FILE -ErrorAction SilentlyContinue }
    Test-Failed (Invoke-Experiment 'P01' 'timeout' $boundReference @{ TimeoutSeconds = 3 }) 'p01 timeout' 'P01-STATE'
    $r = Invoke-Experiment 'P01' 'delete-input' $boundReference
    Test-Failed $r 'p01 deleted output' 'P01-OUTPUT-PRESENT'
    Check (-not (@($r.Data.failureReasons) -join ' ').Contains('EXCEPTION')) 'p01 deleted output: evaluated without exception'
    Test-Failed (Invoke-Experiment 'P01' '' $boundReference @{ Repetitions = 2 }) 'p01 too few repetitions' 'P01-MIN-REPETITIONS'

    # Case 7: wrong or missing input blocks before anything runs.
    $tampered = Join-Path $temp 'tampered/O1AssignSpacing.pas'
    New-Item -ItemType Directory -Path (Split-Path -Parent $tampered) | Out-Null
    [IO.File]::WriteAllText($tampered, "unit Tampered;`r`n")
    $r = Invoke-Experiment 'P01' '' $boundReference @{ FixturePath = $tampered }
    Check ($r.ExitCode -eq 2 -and $r.Data.assertionStatus -eq 'blocked' -and $r.Data.executionStatus -eq 'not-executed') "blocked: wrong input hash (exit $($r.ExitCode))"
    Check (@($r.Data.blockedReasons | Where-Object { $_ -like 'PRE-INPUT-HASH*' }).Count -eq 1 -and -not (Test-Path (Join-Path $r.Dir 'runs'))) 'blocked: wrong input hash ran nothing'
    $r = Invoke-Experiment 'P01' '' $boundReference @{ FixturePath = (Join-Path $temp 'missing.pas') }
    Check ($r.ExitCode -eq 2 -and @($r.Data.blockedReasons | Where-Object { $_ -like 'PRE-INPUT:*' }).Count -eq 1) 'blocked: missing input'
    $noOption = Join-Path $temp 'no-option.config'
    [IO.File]::WriteAllText($noOption, '<TgConfig Version="3"></TgConfig>')
    $withOther = (Get-Content -Raw $boundReference).Replace($baseHash, (Get-Sha $noOption))
    $otherReference = Join-Path $temp 'ref-other-base.json'
    [IO.File]::WriteAllText($otherReference, $withOther)
    $r = Invoke-Experiment 'P01' '' $otherReference @{ BaseProfilePath = $noOption }
    Check ($r.ExitCode -eq 2 -and @($r.Data.blockedReasons | Where-Object { $_ -like 'PRE-BASE-OPTION*' }).Count -eq 1) 'blocked: base profile without the option'

    # Case 8: an unknown formatter never claims the known evidence.
    $r = Invoke-Experiment 'P01' '' $realManifests[1]
    Check ($r.ExitCode -eq 2 -and @($r.Data.blockedReasons | Where-Object { $_ -like 'PRE-FORMATTER-HASH*' }).Count -eq 1) "unknown formatter: blocked by default (exit $($r.ExitCode))"
    $otherFormatter = New-Reference 'ref-other-formatter' ('0' * 64) $observed $first.Data.environment
    $r = Invoke-Experiment 'P01' '' $otherFormatter @{ AcceptUnknownFormatter = $true }
    Check ($r.ExitCode -eq 3 -and $r.Data.assertionStatus -eq 'unconfirmed') "unknown formatter: accepted run stays unconfirmed (exit $($r.ExitCode))"
    Check (@($r.Data.assertions | Where-Object { $_.id -eq 'P01-GOLDEN' }).Count -eq 0) 'unknown formatter: golden not applied'
    Check (@($r.Data.reference.variants.A.mismatches | Where-Object { $_.field -eq 'formatterSha256' }).Count -eq 1) 'unknown formatter: mismatch named'

    # Cases 9 to 12: negative tests of O2-P11.
    $r = Invoke-Experiment 'P11' '' $boundReference
    Check ($r.ExitCode -eq 0 -and $r.Data.assertionStatus -eq 'passed') "p11: expected failures pass (exit $($r.ExitCode)): $($r.Output)"
    Check ($r.Data.variants['missing-input-silent'].runnerClassification -eq 'formatter-error' -and $r.Data.variants['missing-input'].runnerClassification -eq 'aborted') 'p11: runner classification stays separate from assertion status'
    Check (@($r.Data.variants.Keys).Count -eq 11) 'p11: all variants evaluated'
    Test-Failed (Invoke-Experiment 'P11' 'negative-success' $boundReference) 'p11 unexpected success' 'P11-EXIT'
    Test-Failed (Invoke-Experiment 'P11' 'no-dialog' $boundReference) 'p11 missing dialog' 'P11-DIALOG'
    Test-Failed (Invoke-Experiment 'P11' 'dialog-silent' $boundReference) 'p11 dialog in silent run' 'missing-input-silent/P11-STATE'

    # Case 14: the exit code reaches a calling process.
    $wrapper = Join-Path $temp 'call-experiment.ps1'
    $prefix = (($hostArgs + @('-NoProfile', '-NonInteractive', '-File', $fake, 'cli') | ForEach-Object { "'$_'" }) -join ',')
    [IO.File]::WriteAllText($wrapper, "`$env:FAKE_ORACLE_SCENARIO = 'wrong-output'`n& '$experiments' -FormatterPath '$pwsh' -Experiment P01 -BaseProfilePath '$baseProfile' -ExperimentRoot '$(Join-Path $temp 'exp-child')' -ReferenceManifest '$boundReference' -ArgumentPrefix $prefix 6>`$null | Out-Null`nexit `$LASTEXITCODE`n")
    & $pwsh @hostArgs -NoProfile -NonInteractive -File $wrapper | Out-Null
    Check ($LASTEXITCODE -eq 1) "exit code: calling process sees failed ($LASTEXITCODE)"

    # Case 13: nothing overwrote manifests.
    Check ((Get-Sha $boundReference) -eq $boundHash) 'manifest: temporary reference unchanged'
    Check ((@($realManifests | ForEach-Object { Get-Sha $_ }) -join ',') -eq ($realManifestHashes -join ',')) 'manifest: committed manifests unchanged'

    # 8. Sources untouched; local results never publishable.
    Check ((Get-Sha $fixture) -eq $fixtureHash -and (Get-Sha $profile) -eq $profileHash) 'sources: fixture and profile unchanged'
    & git -C $repo check-ignore -q 'tests/FormatterOracle/local/runs/x/run-result.json'
    Check ($LASTEXITCODE -eq 0) 'publish: local/runs is git-ignored'
    $tracked = @(git -C $repo ls-files -- 'tests/FormatterOracle/local')
    Check ($tracked.Count -eq 0) 'publish: nothing under local/ is tracked'

    # 9. Manifest stays valid.
    foreach ($file in 'manifest/o1-manifest.json', 'manifest/o2-manifest.json') {
        $m = & (Join-Path $PSScriptRoot 'Test-OracleManifest.ps1') -Manifest $file
        Check ($LASTEXITCODE -eq 0) "manifest $($file): $($m -join ' ')"
    }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Output "FAIL $_" }
    Write-Output "$passed passed, $($failures.Count) failed."
    exit 1
}
Write-Output "PASS: $passed runner checks."
