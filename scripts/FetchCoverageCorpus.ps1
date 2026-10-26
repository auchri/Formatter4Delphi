param([switch]$Initialize, [switch]$FunctionsOnly, [int]$FilesPerRepository = 40,
  [string]$Manifest = "$PSScriptRoot/../tests/CoverageCorpus/manifest.json")
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath("$PSScriptRoot/..")
$manifestPath = [IO.Path]::GetFullPath($Manifest)
function Invoke-CorpusGit([string[]]$Arguments) {
  $answer = & git @Arguments
  if ($LASTEXITCODE -ne 0) { throw "git failed: $Arguments" }
  return $answer
}
function Select-CorpusFiles($repoPath, $sourcePath, $limit) {
  # Stratify by size and directive density, then take round-robin in ordinal path order.
  $groups = @{}
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repoPath $sourcePath) -Filter *.pas -Recurse -File) {
    $relative = $file.FullName.Substring($repoPath.Length + 1).Replace('\','/')
    $size = if ($file.Length -lt 16384) {'small'} elseif ($file.Length -lt 65536) {'medium'} else {'large'}
    $text = [IO.File]::ReadAllText($file.FullName)
    $directives = [regex]::Matches($text, '\{\$|\(\*\$').Count
    $density = if ($directives -eq 0) {'none'} elseif ($directives -lt 10) {'few'} else {'many'}
    $category = "$size/$density"
    if (!$groups.ContainsKey($category)) { $groups[$category] = @() }
    $groups[$category] += [ordered]@{path=$relative; bytes=$file.Length;
      sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant();
      category=$category; directiveCandidates=$directives;
      compatibility= $(if ($relative -match '(?i)(^|[/._])fpc([/._]|$)') {'fpc-path'} else {'unreviewed'})}
  }
  $keys = [string[]]@($groups.Keys); [Array]::Sort($keys, [StringComparer]::Ordinal)
  foreach ($key in $keys) {
    $paths = [string[]]@($groups[$key] | ForEach-Object {$_.path})
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $byPath = @{}; foreach ($entry in $groups[$key]) {$byPath[$entry.path]=$entry}
    $groups[$key] = @($paths | ForEach-Object {$byPath[$_]})
  }
  $selected = @(); $index = 0
  do {
    $added = $false
    foreach ($key in $keys) {
      if ($index -lt $groups[$key].Count -and $selected.Count -lt $limit) {
        $selected += $groups[$key][$index]; $added = $true
      }
    }
    $index++
  } while ($added -and $selected.Count -lt $limit)
  return $selected
}
if ($FunctionsOnly) { return }
if ($Initialize) {
  if (Test-Path -LiteralPath $manifestPath) { throw 'Manifest exists; initialization never overwrites a pinned manifest.' }
  $specs = @(
    @('DUnitX','https://github.com/VSoftTechnologies/DUnitX.git','Source','Apache-2.0'),
    @('Indy','https://github.com/IndySockets/Indy.git','Lib','Indy Modified BSD / MPL-1.1 (dual)'),
    @('DelphiMVCFramework','https://github.com/danieleteti/delphimvcframework.git','sources','Apache-2.0'),
    @('mORMot2','https://github.com/synopse/mORMot2.git','src','MPL-1.1 / GPL-2.0-or-later / LGPL-2.1-or-later (tri-license)'))
  $repos = @()
  foreach ($spec in $specs) {
    $repoPath = Join-Path $root "build/coverage-corpora/$($spec[0])"
    New-Item -ItemType Directory -Force -Path (Split-Path $repoPath) | Out-Null
    if (!(Test-Path -LiteralPath "$repoPath/.git")) { Invoke-CorpusGit @('clone','--depth','1',$spec[1],$repoPath) | Out-Null }
    Invoke-CorpusGit @('-C',$repoPath,'config','core.autocrlf','false') | Out-Null
    Invoke-CorpusGit @('-C',$repoPath,'config','core.eol','lf') | Out-Null
    Invoke-CorpusGit @('-C',$repoPath,'checkout-index','--all','--force') | Out-Null
    $sha = (Invoke-CorpusGit @('-C',$repoPath,'rev-parse','HEAD')).Trim()
    $repos += [ordered]@{name=$spec[0]; url=$spec[1]; commit=$sha; license=$spec[3];
      licenseSource=($spec[1] -replace '\.git$','') + "/tree/$sha";
      root="build/coverage-corpora/$($spec[0])"; selectionPaths=@($spec[2]);
      files=@(Select-CorpusFiles $repoPath $spec[2] $FilesPerRepository)}
  }
  # Snapshot the versioned fixtures without touching the working source files.
  # git archive avoids differences caused by global autocrlf/editor buffers.
  $internalCommit = (Invoke-CorpusGit @('-C',$root,'rev-parse','HEAD')).Trim()
  $internalRoot = 'build/coverage-corpora/Formatter4Delphi'
  $archive = Join-Path $root 'build/coverage-fixtures.zip'
  Invoke-CorpusGit @('-C',$root,'archive','--format=zip',"--output=$archive",$internalCommit,'tests/Fixtures') | Out-Null
  Expand-Archive -LiteralPath $archive -DestinationPath "$root/$internalRoot" -Force
  $internalFiles = @(Get-ChildItem -LiteralPath "$root/$internalRoot/tests/Fixtures" -Filter *.pas -File |
    Sort-Object Name | ForEach-Object { [ordered]@{path=$_.Name; bytes=$_.Length;
      sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
  $data = [ordered]@{schemaVersion=1; selection='size/directive strata; ordinal path round-robin v1';
    checkoutPolicy='core.autocrlf=false; core.eol=lf; repository attributes still apply';
    repositories=$repos; internalRoot="$internalRoot/tests/Fixtures";
    internalCommit=$internalCommit; internalFiles=$internalFiles}
  New-Item -ItemType Directory -Force -Path (Split-Path $manifestPath) | Out-Null
  $manifestJson = (($data | ConvertTo-Json -Depth 12) -replace "`r`n", "`n") + "`n"
  [IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))
} else {
  $data = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  foreach ($repo in $data.repositories) {
    if ($repo.commit -notmatch '^[0-9a-f]{40}$') { throw "Invalid commit: $($repo.name)" }
    $repoPath = Join-Path $root $repo.root
    if (!(Test-Path -LiteralPath "$repoPath/.git")) { Invoke-CorpusGit @('clone','--no-checkout',$repo.url,$repoPath) | Out-Null }
    Invoke-CorpusGit @('-C',$repoPath,'config','core.autocrlf','false') | Out-Null
    Invoke-CorpusGit @('-C',$repoPath,'config','core.eol','lf') | Out-Null
    Invoke-CorpusGit @('-C',$repoPath,'fetch','origin',$repo.commit) | Out-Null
    Invoke-CorpusGit @('-C',$repoPath,'checkout','--detach',$repo.commit) | Out-Null
    if ((Invoke-CorpusGit @('-C',$repoPath,'rev-parse','HEAD')).Trim() -ne $repo.commit) { throw 'Commit mismatch' }
    foreach ($file in $repo.files) {
      $path = Join-Path $repoPath $file.path
      if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or
          (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) { throw "Corpus mismatch: $path" }
    }
  }
  $archive = Join-Path $root 'build/coverage-fixtures.zip'
  Invoke-CorpusGit @('-C',$root,'archive','--format=zip',"--output=$archive",$data.internalCommit,'tests/Fixtures') | Out-Null
  Expand-Archive -LiteralPath $archive -DestinationPath "$root/build/coverage-corpora/Formatter4Delphi" -Force
}
Write-Output "Pinned corpus ready: $manifestPath"
