#requires -Version 7.0
<#
.SYNOPSIS
Runs the original RAD Studio Formatter.exe (or a test stand-in) on isolated copies and records everything.
.DESCRIPTION
O2 oracle runner. For one run specification (formatter, optional profile, input files, argument
template) it:
  - verifies the formatter SHA-256 against the manifest toolchain (or an explicit expected hash),
  - creates a new run directory below -RunRoot (default tests/FormatterOracle/local/runs) and holds
    an exclusive lock file in it, so no second runner can use the same directory,
  - per repetition copies inputs and profile into a fresh rep-NN directory and only passes these
    copies to the process,
  - starts the process with the explicit argument list (no shell), watches it with a timeout and
    detects visible windows of the process tree (dialogs); a dialog is captured, closed with
    WM_CLOSE and, if still alive, the process tree is killed; only the started process tree is
    ever terminated,
  - records exit code, state, duration, stdout/stderr, all files in the rep directory before and
    after (SHA-256), created/changed/deleted files,
  - guards the source inputs/profile and the %APPDATA% Formatter.config files: they are hashed
    before and after; a changed %APPDATA% profile is restored from the in-memory copy and reported,
  - compares output hashes across repetitions (determinism),
  - writes run-result.json (format formatter4delphi.oracle-run/1) into the run directory.
The meaning of Formatter.exe arguments is not assumed: the caller passes -ArgumentTemplate.
Placeholders: {input} (first input copy), {input:N}, {profile}, {repDir}, {log} (= {repDir}\formatter.log).
Exit codes: 0 all repetitions finished by themselves and no guard tripped; 1 at least one
repetition timed out/hit a dialog/failed to start or a guard tripped; 2 precondition failure
(nothing was executed).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FormatterPath,
    [Parameter(Mandatory)][string[]]$ArgumentTemplate,
    [string[]]$InputPath = @(),
    [string]$ProfilePath,
    [string]$RunName = 'run',
    [string]$RunRoot,
    [int]$Repetitions = 3,
    [int]$TimeoutSeconds = 60,
    [int]$DialogGraceMilliseconds = 500,
    [string]$ExpectedFormatterSha256,
    [string]$Manifest,
    [string]$ToolchainId,
    [switch]$AllowInvalidProfile,
    [string[]]$ProtectedPath = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$oracleRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = [IO.Path]::GetFullPath((Join-Path $oracleRoot '../..'))
$localRoot = [IO.Path]::GetFullPath((Join-Path $oracleRoot 'local'))
if (-not $RunRoot) { $RunRoot = Join-Path $localRoot 'runs' }
if (-not $Manifest) { $Manifest = Join-Path $oracleRoot 'manifest/o1-manifest.json' }

function Stop-Precondition([string]$Message) {
    Write-Output "PRECONDITION FAILED: $Message"
    exit 2
}

function Get-Sha256File([string]$Path) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path)))
}

function Test-Below([string]$Path, [string]$Root) {
    $p = [IO.Path]::GetFullPath($Path).TrimEnd('\') + '\'
    $r = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)
}

Add-Type -TypeDefinition @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
public static class OracleWindows {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr p, EnumProc f, IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SendMessageTimeout(IntPtr h, uint m, IntPtr w, StringBuilder s, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    static string Text(IntPtr h) {
        var sb = new StringBuilder(16384); IntPtr r;
        SendMessageTimeout(h, 0x000D, (IntPtr)sb.Capacity, sb, 0x0002, 1000, out r); // WM_GETTEXT, SMTO_ABORTIFHUNG
        return sb.ToString();
    }
    public static List<IntPtr> Visible(HashSet<uint> pids) {
        var r = new List<IntPtr>();
        EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (pids.Contains(p) && IsWindowVisible(h)) r.Add(h); return true; }, IntPtr.Zero);
        return r;
    }
    public static string Describe(IntPtr h) {
        var parts = new List<string> { Text(h) };
        EnumChildWindows(h, (c, l) => { var t = Text(c); if (t.Length > 0) parts.Add(t); return true; }, IntPtr.Zero);
        return string.Join("\n---\n", parts);
    }
}
'@

function Get-ProcessTree([int]$RootId) {
    $ids = [Collections.Generic.HashSet[uint32]]::new()
    [void]$ids.Add([uint32]$RootId)
    $frontier = @($RootId)
    while ($frontier.Count) {
        $children = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $frontier[0]) -ErrorAction SilentlyContinue | ForEach-Object ProcessId)
        $frontier = @($frontier | Select-Object -Skip 1) + $children
        foreach ($c in $children) { [void]$ids.Add([uint32]$c) }
    }
    , $ids
}

function Get-DirectorySnapshot([string]$Dir) {
    $map = [ordered]@{}
    Get-ChildItem -LiteralPath $Dir -Recurse -File | Sort-Object FullName | ForEach-Object {
        $rel = [IO.Path]::GetRelativePath($Dir, $_.FullName).Replace('\', '/')
        $map[$rel] = [ordered]@{ sizeBytes = $_.Length; sha256 = Get-Sha256File $_.FullName }
    }
    $map
}

function Get-ProtectedSnapshot([string[]]$Paths) {
    $map = [ordered]@{}
    foreach ($p in $Paths) {
        $map[$p] = (Test-Path -LiteralPath $p -PathType Leaf) ? [IO.File]::ReadAllBytes($p) : $null
    }
    $map
}

function Expand-Template([string[]]$Template, [string[]]$Inputs, [string]$Profile, [string]$RepDir) {
    foreach ($t in $Template) {
        $v = $t.Replace('{repDir}', $RepDir).Replace('{log}', (Join-Path $RepDir 'formatter.log'))
        if ($Profile) { $v = $v.Replace('{profile}', $Profile) }
        for ($i = 0; $i -lt $Inputs.Count; $i++) { $v = $v.Replace("{input:$i}", $Inputs[$i]) }
        if ($Inputs.Count) { $v = $v.Replace('{input}', $Inputs[0]) }
        if ($v -match '\{(input(:\d+)?|profile)\}') { throw "Unresolved placeholder in argument '$t'." }
        $v
    }
}

function ConvertTo-Relative([string]$Value, [string]$RunDir) {
    # Recorded arguments use <run-dir>-relative paths so results carry no personal paths.
    $Value.Replace($RunDir, '<run-dir>')
}

# ---- Preconditions (nothing is executed before all pass) --------------------------------------
if ($Repetitions -lt 1) { Stop-Precondition 'Repetitions must be >= 1.' }
if ($TimeoutSeconds -lt 1) { Stop-Precondition 'TimeoutSeconds must be >= 1.' }
if ($RunName -notmatch '^[A-Za-z0-9._-]+$') { Stop-Precondition "RunName '$RunName' must match [A-Za-z0-9._-]+." }
if (-not (Test-Path -LiteralPath $FormatterPath -PathType Leaf)) { Stop-Precondition "Formatter not found: $FormatterPath" }
$FormatterPath = [IO.Path]::GetFullPath($FormatterPath)
$formatterHash = Get-Sha256File $FormatterPath
$toolchain = $null
if ($ExpectedFormatterSha256) {
    $expected = $ExpectedFormatterSha256.ToUpperInvariant()
    $hashSource = 'explicit'
} else {
    $m = [IO.File]::ReadAllText($Manifest) | ConvertFrom-Json
    $toolchain = $ToolchainId ? ($m.toolchains | Where-Object id -eq $ToolchainId) : @($m.toolchains)[0]
    if (-not $toolchain) { Stop-Precondition "Toolchain '$ToolchainId' not found in manifest." }
    $expected = $toolchain.formatter.exe.sha256
    $hashSource = "manifest:$($toolchain.id)"
}
if ($formatterHash -ne $expected) { Stop-Precondition "Formatter SHA-256 $formatterHash does not match expected $expected ($hashSource)." }

$inputs = @()
foreach ($p in $InputPath) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { Stop-Precondition "Input not found: $p" }
    $inputs += [IO.Path]::GetFullPath($p)
}
if (@($inputs | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object -Unique).Count -ne $inputs.Count) {
    Stop-Precondition 'Input file names must be unique (they are copied into one directory).'
}
if ($ProfilePath) {
    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) { Stop-Precondition "Profile not found: $ProfilePath" }
    $ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
    if (-not $AllowInvalidProfile) {
        try {
            $settings = [Xml.XmlReaderSettings]::new()
            $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
            $settings.XmlResolver = $null
            $reader = [Xml.XmlReader]::Create($ProfilePath, $settings)
            $rootName = $null
            try { while ($reader.Read()) { if ($null -eq $rootName -and $reader.NodeType -eq 'Element') { $rootName = $reader.LocalName } } } finally { $reader.Dispose() }
        } catch { Stop-Precondition "Profile is not well-formed XML: $($_.Exception.GetType().Name)" }
        if ($rootName -ne 'TgConfig') { Stop-Precondition "Profile root is '$rootName', expected TgConfig (use -AllowInvalidProfile for negative experiments)." }
    }
}

$RunRoot = [IO.Path]::GetFullPath($RunRoot)
if ((Test-Below $RunRoot $repoRoot) -and -not (Test-Below $RunRoot $localRoot)) {
    Stop-Precondition 'RunRoot inside the repository must be below tests/FormatterOracle/local.'
}
foreach ($p in @($inputs) + @($ProfilePath | Where-Object { $_ })) {
    if (Test-Below $p $RunRoot) { Stop-Precondition "Source file must not lie inside RunRoot: $p" }
}

$appdataProfiles = @()
if ($env:APPDATA -and (Test-Path (Join-Path $env:APPDATA 'Embarcadero\BDS'))) {
    $appdataProfiles = @(Get-ChildItem (Join-Path $env:APPDATA 'Embarcadero\BDS') -Directory | ForEach-Object { Join-Path $_.FullName 'Formatter.config' } | Where-Object { Test-Path $_ })
}
$guarded = @($inputs) + @($ProfilePath | Where-Object { $_ }) + $appdataProfiles + $ProtectedPath

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$runId = "$RunName-$stamp"
$runDir = Join-Path $RunRoot $runId
New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
try { New-Item -ItemType Directory -Path $runDir -ErrorAction Stop | Out-Null } catch { Stop-Precondition "Run directory already exists: $runId" }
$lock = [IO.File]::Open((Join-Path $runDir '.lock'), 'CreateNew', 'ReadWrite', 'None')

# ---- Execution -------------------------------------------------------------------------------
$repResults = [Collections.Generic.List[object]]::new()
$guardIssues = [Collections.Generic.List[string]]::new()
try {
    for ($rep = 1; $rep -le $Repetitions; $rep++) {
        $repName = 'rep-{0:D2}' -f $rep
        $repDir = Join-Path $runDir $repName
        New-Item -ItemType Directory -Path $repDir | Out-Null
        $inputCopies = @(foreach ($p in $inputs) { $dest = Join-Path $repDir ([IO.Path]::GetFileName($p)); Copy-Item -LiteralPath $p $dest; $dest })
        $profileCopy = $null
        if ($ProfilePath) {
            $profileCopy = Join-Path $repDir ('profile-' + [IO.Path]::GetFileName($ProfilePath))
            Copy-Item -LiteralPath $ProfilePath $profileCopy
        }
        $arguments = @(Expand-Template $ArgumentTemplate $inputCopies $profileCopy $repDir)
        $protectedBefore = Get-ProtectedSnapshot $guarded
        $before = Get-DirectorySnapshot $repDir

        $psi = [Diagnostics.ProcessStartInfo]::new($FormatterPath)
        foreach ($a in $arguments) { $psi.ArgumentList.Add($a) }
        $psi.WorkingDirectory = $repDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $true
        $state = 'exited'; $dialogs = @(); $dialogClosed = $false; $killed = $false; $exitCode = $null; $startError = $null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $process = $null
        try { $process = [Diagnostics.Process]::Start($psi) } catch { $state = 'start-failed'; $startError = $_.Exception.GetType().Name }
        if ($process) {
            $process.StandardInput.Close()
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            while (-not $process.WaitForExit(200)) {
                $tree = Get-ProcessTree $process.Id
                $windows = [OracleWindows]::Visible($tree)
                if ($windows.Count -gt 0) {
                    Start-Sleep -Milliseconds $DialogGraceMilliseconds
                    $windows = [OracleWindows]::Visible((Get-ProcessTree $process.Id))
                    $dialogs = @($windows | ForEach-Object { [OracleWindows]::Describe($_) })
                    $state = 'dialog'
                    foreach ($w in $windows) { [void][OracleWindows]::PostMessage($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) } # WM_CLOSE
                    $dialogClosed = $process.WaitForExit(5000)
                    if (-not $dialogClosed) { $process.Kill($true); $killed = $true }
                    break
                }
                if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                    $state = 'timeout'
                    $process.Kill($true); $killed = $true
                    break
                }
            }
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            $stdout = $stdoutTask.Result; $stderr = $stderrTask.Result
        } else { $stdout = ''; $stderr = '' }
        $sw.Stop()
        $utf8 = [Text.UTF8Encoding]::new($false)
        $outDir = Join-Path $runDir "$repName.process"
        New-Item -ItemType Directory -Path $outDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $outDir 'stdout.txt'), $stdout, $utf8)
        [IO.File]::WriteAllText((Join-Path $outDir 'stderr.txt'), $stderr, $utf8)
        for ($i = 0; $i -lt $dialogs.Count; $i++) { [IO.File]::WriteAllText((Join-Path $outDir "dialog-$i.txt"), $dialogs[$i], $utf8) }

        $after = Get-DirectorySnapshot $repDir
        $protectedAfter = Get-ProtectedSnapshot $guarded
        foreach ($p in $guarded) {
            $b = $protectedBefore[$p]; $a = $protectedAfter[$p]
            $same = ($null -eq $b -and $null -eq $a) -or ($null -ne $b -and $null -ne $a -and [Linq.Enumerable]::SequenceEqual([byte[]]$b, [byte[]]$a))
            if (-not $same) {
                $label = ($appdataProfiles -contains $p) ? '%APPDATA% Formatter.config' : [IO.Path]::GetFileName($p)
                if ($appdataProfiles -contains $p -and $null -ne $b) { [IO.File]::WriteAllBytes($p, [byte[]]$b); $label += ' (restored)' }
                $guardIssues.Add("$($repName): protected file changed: $label")
            }
        }
        $created = @($after.Keys | Where-Object { -not $before.Contains($_) })
        $deleted = @($before.Keys | Where-Object { -not $after.Contains($_) })
        $changed = @($after.Keys | Where-Object { $before.Contains($_) -and $before[$_].sha256 -ne $after[$_].sha256 })
        $repResults.Add([ordered]@{
            repetition = $rep
            directory = $repName
            arguments = @($arguments | ForEach-Object { ConvertTo-Relative $_ $runDir })
            workingDirectory = "<run-dir>/$repName"
            state = $state
            exitCode = $exitCode
            startError = $startError
            killed = $killed
            dialogClosedByRunner = $dialogClosed
            dialogTexts = $dialogs
            durationMs = [Math]::Round($sw.Elapsed.TotalMilliseconds)
            stdoutSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($stdout)))
            stderrSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($stderr)))
            stdout = $stdout
            stderr = $stderr
            filesBefore = $before
            filesAfter = $after
            created = $created; changed = $changed; deleted = $deleted
        })
    }
} finally {
    $lock.Dispose()
    Remove-Item -LiteralPath (Join-Path $runDir '.lock') -Force -ErrorAction SilentlyContinue
}

# ---- Determinism and result ------------------------------------------------------------------
$outputKeys = @($repResults | ForEach-Object { $_.filesAfter.Keys } | Sort-Object -Unique)
$perFile = [ordered]@{}
foreach ($k in $outputKeys) {
    $hashes = @($repResults | ForEach-Object { $_.filesAfter.Contains($k) ? $_.filesAfter[$k].sha256 : '<absent>' })
    $perFile[$k] = [ordered]@{ distinct = @($hashes | Sort-Object -Unique).Count; sha256 = $hashes }
}
$volatile = @('formatter.log')
$stableKeys = @($outputKeys | Where-Object { $volatile -notcontains $_ })
$deterministic = @($stableKeys | Where-Object { $perFile[$_].distinct -ne 1 }).Count -eq 0 -and
    @($repResults | ForEach-Object { "$($_.state)|$($_.exitCode)" } | Sort-Object -Unique).Count -eq 1
$clean = @($repResults | Where-Object { $_.state -ne 'exited' }).Count -eq 0 -and $guardIssues.Count -eq 0

$result = [ordered]@{
    resultFormat = 'formatter4delphi.oracle-run/1'
    runId = $runId
    formatter = [ordered]@{
        fileName = [IO.Path]::GetFileName($FormatterPath); sha256 = $formatterHash; hashCheck = $hashSource
        fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($FormatterPath).FileVersion
        toolchainId = $toolchain ? $toolchain.id : $null
    }
    environment = [ordered]@{
        os = [Environment]::OSVersion.VersionString; culture = (Get-Culture).Name; uiCulture = (Get-UICulture).Name
        ansiCodePage = [Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage; powershell = $PSVersionTable.PSVersion.ToString()
    }
    argumentTemplate = $ArgumentTemplate
    inputs = @($inputs | ForEach-Object { [ordered]@{ fileName = [IO.Path]::GetFileName($_); sha256 = Get-Sha256File $_; sizeBytes = (Get-Item -LiteralPath $_).Length } })
    profile = $ProfilePath ? [ordered]@{ fileName = [IO.Path]::GetFileName($ProfilePath); sha256 = Get-Sha256File $ProfilePath } : $null
    timeoutSeconds = $TimeoutSeconds
    repetitions = $Repetitions
    repetitionResults = $repResults
    determinism = [ordered]@{ deterministic = $deterministic; ignoredForDeterminism = $volatile; perFile = $perFile }
    guardIssues = $guardIssues
    classification = $clean ? 'completed' : 'failed'
}
$json = $result | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path $runDir 'run-result.json'), $json.Replace("`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Output ('{0}: {1}; states {2}; exit codes {3}; deterministic {4}; result {5}' -f $runId, $result.classification,
    (($repResults | ForEach-Object state) -join ','), (($repResults | ForEach-Object exitCode) -join ','), $deterministic,
    [IO.Path]::GetRelativePath($repoRoot, (Join-Path $runDir 'run-result.json')).Replace('\', '/'))
exit ($clean ? 0 : 1)
