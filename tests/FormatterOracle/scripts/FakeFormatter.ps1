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
#>
param([Parameter(Mandatory)][string]$Mode, [string]$File, [string]$Other)
$ErrorActionPreference = 'Stop'
function Format-File {
    $text = [IO.File]::ReadAllText($File)
    [IO.File]::WriteAllText($File, ($text -replace '\s*:=\s*', ' := '), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path (Get-Location) 'fake-output.txt'), "formatted $([IO.Path]::GetFileName($File))`n")
    [Console]::Out.WriteLine("fake: formatted $([IO.Path]::GetFileName($File))")
}
switch ($Mode) {
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
