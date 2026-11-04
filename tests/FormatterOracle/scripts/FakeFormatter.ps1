#requires -Version 7.0
<#
.SYNOPSIS
Controlled stand-in for Formatter.exe, used only by Test-OracleRunner.ps1 (no RAD Studio needed).
.DESCRIPTION
Modes:
  format  <file>      rewrites ':=' with one blank on each side in place, writes fake-output.txt, stdout line, exit 0
  fail    <file>      writes to stderr, leaves the file unchanged, exit 3
  sleep   <file>      sleeps 120 s (timeout test)
  random  <file>      appends a random line to the file (non-determinism test), exit 0
  dialog  <file>      shows a blocking message box (dialog test)
  touch   <file> <p>  formats like 'format' and also appends to the foreign file <p> (guard test)
  cli     <args>      imitates the observed Formatter.exe command line for the experiment tests:
                      -delphi, -silent, -config <file>, -log <file>, <file>, /fake-help. Deviations are
                      selected with $env:FAKE_ORACLE_SCENARIO: wrong-output, nondeterministic, exit3,
                      unexpected-dialog, guard (appends to $env:FAKE_ORACLE_GUARD_FILE), negative-success,
                      no-dialog, dialog-silent, delete-input, timeout.
This imitation has no evidence value about the real formatter.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Mode, [Parameter(ValueFromRemainingArguments)][string[]]$Rest = @())
$ErrorActionPreference = 'Stop'
$File = $Rest.Count -gt 0 ? $Rest[0] : $null
$Other = $Rest.Count -gt 1 ? $Rest[1] : $null
function Format-File {
    $text = [IO.File]::ReadAllText($File)
    [IO.File]::WriteAllText($File, ($text -replace '\s*:=\s*', ' := '), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path (Get-Location) 'fake-output.txt'), "formatted $([IO.Path]::GetFileName($File))`n")
    [Console]::Out.WriteLine("fake: formatted $([IO.Path]::GetFileName($File))")
}
function Show-Dialog([string]$Text) {
    Add-Type -Namespace FakeFormatter -Name User32 -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int MessageBoxW(IntPtr h, string text, string caption, uint type);'
    [void][FakeFormatter.User32]::MessageBoxW([IntPtr]::Zero, $Text, 'Fake Formatter Dialog', 0)
}

function Invoke-Cli {
    $scenario = [string]$env:FAKE_ORACLE_SCENARIO
    $silent = $false; $config = $null; $log = $null; $help = $false
    $files = [Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Rest.Count; $i++) {
        switch -CaseSensitive ($Rest[$i]) {
            '-delphi' { }
            '-silent' { $silent = $true }
            '-config' { $config = $Rest[++$i] }
            '-log' { $log = $Rest[++$i] }
            '/fake-help' { $help = $true }
            default { $files.Add($Rest[$i]) }
        }
    }
    if ($scenario -eq 'no-dialog') { $silent = $true }
    if ($scenario -eq 'dialog-silent') { $silent = $false }
    function Stop-WithError([string]$Message) {
        if ($scenario -eq 'negative-success') { return }
        if ($log) { [IO.File]::AppendAllText($log, "00:00:00.000 $Message`r`n") } else { [Console]::Out.WriteLine("00:00:00.000 $Message") }
        if (-not $silent) { Show-Dialog $Message }
        exit 1
    }
    if ($help) {
        if ($scenario -eq 'negative-success') { exit 0 }
        if (-not $silent) { Show-Dialog 'Syntax: fake usage' }
        exit 1
    }
    $value = 'BeforeAndAfter'
    if ($config) {
        if (-not (Test-Path -LiteralPath $config)) { Stop-WithError "Cannot load config file `"$config`"" }
        else {
            $text = [IO.File]::ReadAllText($config)
            try { [void][xml]$text } catch { Stop-WithError 'Unable to load config options: fake XML error' }
            $m = [regex]::Match($text, 'Name="DelphiFormatter\.AssignSpaces"[^>]*Value="([^"]*)"')
            if ($m.Success) { $value = $m.Groups[1].Value }
        }
    }
    foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
            Stop-WithError "File $(Join-Path (Get-Location) ([IO.Path]::GetFileName($f))) doesn't exist"
            continue
        }
        if ($log) { [IO.File]::AppendAllText($log, "00:00:00.000 Formatting file $f`r`n") } else { [Console]::Out.WriteLine("00:00:00.000 Formatting file $f") }
        $spaced = $value -eq 'None' ? ':=' : ' := '
        $lines = [IO.File]::ReadAllText($f) -split "`r`n" | ForEach-Object {
            if ($_.TrimStart().StartsWith('//') -or $_.TrimStart().StartsWith('{')) { return $_ }
            ([regex]::Split($_, "('(?:[^']|'')*')") | ForEach-Object { $_.StartsWith("'") ? $_ : ($_ -replace '[ \t]*:=[ \t]*', $spaced) }) -join ''
        }
        $text = $lines -join "`r`n"
        if ($scenario -eq 'wrong-output') { $text += "// deviation`r`n" }
        if ($scenario -eq 'nondeterministic') { $text += "// $([Guid]::NewGuid())`r`n" }
        [IO.File]::WriteAllText($f, $text, [Text.UTF8Encoding]::new($false))
        if ($scenario -eq 'delete-input') { Remove-Item -LiteralPath $f }
    }
    switch ($scenario) {
        'exit3' { exit 3 }
        'unexpected-dialog' { Show-Dialog 'unexpected fake dialog' }
        'guard' { [IO.File]::AppendAllText($env:FAKE_ORACLE_GUARD_FILE, "touched`n") }
        'timeout' { Start-Sleep -Seconds 120 }
    }
    exit 0
}

switch ($Mode) {
    'cli' { Invoke-Cli }
    'format' { Format-File; exit 0 }
    'fail' { [Console]::Error.WriteLine('fake: failure requested'); exit 3 }
    'sleep' { Start-Sleep -Seconds 120; exit 0 }
    'random' { [IO.File]::AppendAllText($File, "// $([Guid]::NewGuid())`r`n"); exit 0 }
    'dialog' {
        Add-Type -Namespace FakeFormatter -Name User32 -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int MessageBoxW(IntPtr h, string text, string caption, uint type);'
        [void][FakeFormatter.User32]::MessageBoxW([IntPtr]::Zero, 'fake dialog text', 'Fake Formatter Dialog', 0)
        exit 7
    }
    'touch' { Format-File; [IO.File]::AppendAllText($Other, "touched`n"); exit 0 }
    default { exit 99 }
}
