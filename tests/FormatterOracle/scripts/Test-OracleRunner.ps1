#requires -Version 7.0
<#
.SYNOPSIS
Self-tests for RunFormatterOracle.ps1 with the controlled stand-in FakeFormatter.ps1; needs no RAD Studio.
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
