param([switch]$CheckPinnedFiles)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/FetchCoverageCorpus.ps1" -FunctionsOnly
$testRoot = Join-Path $root 'build/coverage-selection-test'
New-Item -ItemType Directory -Force "$testRoot/Source" | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)
foreach ($entry in @(@('z.pas','unit Z;'), @('a.pas','unit A;'),
    @('directive.pas','{$IFDEF X} unit D;'), @('large.pas',('x' * 70000)))) {
  [IO.File]::WriteAllText((Join-Path "$testRoot/Source" $entry[0]),$entry[1],$encoding)
}
$first = @(Select-CorpusFiles $testRoot 'Source' 3)
$second = @(Select-CorpusFiles $testRoot 'Source' 3)
if (($first | ConvertTo-Json -Depth 8 -Compress) -cne ($second | ConvertTo-Json -Depth 8 -Compress)) {
  throw 'Selection is not deterministic'
}
$actual = ($first | ForEach-Object {$_.path}) -join ','
if ($actual -cne 'Source/large.pas,Source/directive.pas,Source/a.pas') { throw "Unexpected strata/order: $actual" }
if ($first[0].bytes -ne 70000) { throw 'Incorrect size' }
if ($first[1].directiveCandidates -ne 1) { throw 'Incorrect directive stratum' }
if ($CheckPinnedFiles) {
  $manifest = Get-Content -Raw "$root/tests/CoverageCorpus/manifest.json" | ConvertFrom-Json
  foreach ($repo in $manifest.repositories) {
    $repoPath = Join-Path $root $repo.root
    $selected = @(Select-CorpusFiles $repoPath $repo.selectionPaths[0] $repo.files.Count)
    if (($selected | ConvertTo-Json -Depth 8 -Compress) -cne ($repo.files | ConvertTo-Json -Depth 8 -Compress)) {
      throw "Pinned selection differs: $($repo.name)"
    }
    if ((Invoke-CorpusGit @('-C',$repoPath,'rev-parse','HEAD')).Trim() -cne $repo.commit) { throw 'Commit differs' }
  }
  foreach ($file in $manifest.internalFiles) {
    $path = Join-Path "$root/$($manifest.internalRoot)" $file.path
    if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or
      (Get-FileHash -LiteralPath $path).Hash -ne $file.sha256) { throw 'Internal baseline differs' }
  }
}
Write-Output 'PASS: exact selection, strata, order, hashes and repeatability'
