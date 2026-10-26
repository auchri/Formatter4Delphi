param([string]$Executable = "$PSScriptRoot/../build/Win64/Debug/DelphiFormatter.Coverage.exe")
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath("$PSScriptRoot/..")
Push-Location $root
try {
  & $Executable --file tests/Fixtures/Minimal.pas --output build/coverage-cli-single --repeat 2 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Single-file exit' }
  $single = Get-Content -Raw build/coverage-cli-single/coverage.json | ConvertFrom-Json
  if ($single.files.Count -ne 1 -or !$single.files[0].lossless) { throw 'Single-file report' }
  & $Executable --directory tests/Fixtures --include '*Corpus.pas' --exclude 'LexicalCorpus.pas' --output build/coverage-cli-directory | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Directory exit' }
  $directory = Get-Content -Raw build/coverage-cli-directory/coverage.json | ConvertFrom-Json
  if ($directory.files.Count -ne 6) { throw 'Include/exclude selection' }
  & $Executable --file build/no-such-coverage-file.pas --output build/coverage-cli-missing | Out-Null
  if ($LASTEXITCODE -ne 1) { throw 'Missing-file exit' }
  $missing = Get-Content -Raw build/coverage-cli-missing/coverage.json | ConvertFrom-Json
  if ($missing.files[0].status -ne 'file_error' -or $missing.summaries[0].validFiles -ne 0) { throw 'Missing-file report' }
  $ErrorActionPreference = 'Continue'
  & $Executable --file tests/Fixtures/Minimal.pas --directory tests/Fixtures 2>$null | Out-Null
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 1) { throw 'Conflicting-input exit' }
  Write-Output 'PASS: file/directory/include/exclude modes, report creation and failure exit codes'
} finally { Pop-Location }
