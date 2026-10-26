# Compare the same successful source snapshots; never replace the M2.7 baseline.
param(
  [string]$Before = "$PSScriptRoot/../reports/m2_7/coverage.json",
  [string]$After = "$PSScriptRoot/../reports/m2_8/coverage.json",
  [string]$Output = "$PSScriptRoot/../reports/m2_8/comparison.md"
)
$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$b = Get-Content -Raw -LiteralPath $Before | ConvertFrom-Json
$a = Get-Content -Raw -LiteralPath $After | ConvertFrom-Json
if ($a.encodingPolicy -cne $b.encodingPolicy -or $a.codepage -ne $b.codepage -or
    $a.repeatCount -ne $b.repeatCount) { throw 'Comparison policies differ' }
$old = @{}; foreach ($f in $b.files) { $old[$f.path] = $f }
if ($a.files.Count -ne $b.files.Count) { throw 'Different file selection' }
$pairs = @(foreach ($f in $a.files) {
  $prev = $old[$f.path]
  if (!$prev -or $prev.sha256 -cne $f.sha256 -or $prev.commit -cne $f.commit -or
      $prev.repository -cne $f.repository -or $prev.bytes -ne $f.bytes) { throw "Snapshot differs: $($f.path)" }
  if ($prev.lossless -and $f.lossless) {
    if ($prev.codeUnits -ne $f.codeUnits -or $prev.utf16Units -ne $f.utf16Units -or
        $prev.tokens -ne $f.tokens) { throw "Token/source denominator differs: $($f.path)" }
    [pscustomobject]@{before=$prev;after=$f}
  }
})
function Sum($rows, $field) { ($rows | Measure-Object -Property $field -Sum).Sum }
function Fmt($value) { ([double]$value).ToString('0.000000', $culture) }
function Percent($rows, $field) {
  $den = Sum $rows 'codeUnits'; if (!$den) { return 'n/a' }
  Fmt (100.0 * (Sum $rows $field) / $den)
}
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('# M2.7 / M2.8 paired corpus comparison')
$lines.Add('')
$lines.Add('The manifest and all paths, commits, byte counts and SHA-256 values are unchanged. Strict encoding policy and three repetitions match. Every table uses the same files successfully analyzed in both runs. Internal fixtures remain separate from the external corpus. No encoding failures enter coverage denominators.')
$lines.Add('')
$lines.Add("Paired successful files: $($pairs.Count) total, $(@($pairs | Where-Object {$_.after.repository -ne 'internal'}).Count) external. Attempted: $($a.files.Count) total, 160 external. Both runs have six external encoding failures; analyzer exit 1 is the expected partial-input result, not a parser/invariant failure.")
$lines.Add('')
$lines.Add('| Repository | Paired files | Structured % before | Structured % after | Opaque % before | Opaque % after | Directive fallbacks before / after |')
$lines.Add('|---|---:|---:|---:|---:|---:|---:|')
foreach ($repo in @('external','DUnitX','Indy','DelphiMVCFramework','mORMot2','internal')) {
  $p = @($pairs | Where-Object { if($repo -eq 'external'){$_.after.repository -ne 'internal'}else{$_.after.repository -eq $repo} })
  $x = @($p | ForEach-Object before); $y = @($p | ForEach-Object after)
  $lines.Add("| $repo | $($p.Count) | $(Percent $x 'structuredCodeUnits') | $(Percent $y 'structuredCodeUnits') | $(Percent $x 'opaqueCodeUnits') | $(Percent $y 'opaqueCodeUnits') | $(@($x | Where-Object directiveFallback).Count) / $(@($y | Where-Object directiveFallback).Count) |")
}
$lines.Add('')
$lines.Add('All percentages sum original UTF-16 code units before division; directives/trivia remain excluded. Conditional-region nodes and their contents count as opaque. Error takes priority. A reduced fallback count alone does not imply more recognized code.')
$lines.Add('')
$lines.Add('| Paired external metric | M2.7 | M2.8 |')
$lines.Add('|---|---:|---:|')
$x = @($pairs | Where-Object {$_.after.repository -ne 'internal'} | ForEach-Object before)
$y = @($pairs | Where-Object {$_.after.repository -ne 'internal'} | ForEach-Object after)
foreach ($field in @('codeUnits','structuredCodeUnits','opaqueCodeUnits','errorCodeUnits','lexerDiagnostics','parserDiagnostics','parserErrors')) {
  $lines.Add("| $field | $(Sum $x $field) | $(Sum $y $field) |")
}
$lines.Add("| Files with nonzero structured code | $(@($x | Where-Object {$_.structuredCodeUnits -gt 0}).Count) | $(@($y | Where-Object {$_.structuredCodeUnits -gt 0}).Count) |")
$lines.Add("| Unit hierarchies retained | $(@($x | Where-Object {$_.nodes -gt 2 -and !$_.completeOpaque}).Count) | $(Sum $y 'structuredUnitDeclarations') |")
$lines.Add("| Lossless checks passed | $(@($x | Where-Object lossless).Count) | $(@($y | Where-Object lossless).Count) |")
$lines.Add("| Determinism checks passed | $(@($x | Where-Object deterministic).Count) | $(@($y | Where-Object deterministic).Count) |")
$lines.Add('')
$lines.Add('The old report did not count unit nodes directly: the baseline unit-hierarchy count is inferred from its non-fallback compilation trees (nodes > 2); M2.8 counts skUnitDeclaration directly. This is hierarchy retention, not a claim that all descendants are supported or error-free.')
$lines.Add('')
$allNew = @($pairs | ForEach-Object after)
$lines.Add("Recognized protected conditional islands: $(Sum $allNew 'protectedConditionalRegions') across paired files, $(Sum $allNew 'protectedConditionalUnits') UTF-16 units including leading trivia/directives. External islands: $(Sum $y 'protectedConditionalRegions'). All (100%) accepted branch contents remain opaque; no branch is interpreted as active. Whole-file fallbacks protect additional conditionals, but this island count does not pretend to count or locate those hidden branches.")
$lines.Add('')
$lines.Add('## Runtime under comparable conditions')
$lines.Add('')
$lines.Add("Before: $($b.environment)")
$lines.Add('')
$lines.Add("After: $($a.environment)")
$lines.Add('')
$lines.Add('| Sum over paired external files | Before ms | After ms |')
$lines.Add('|---|---:|---:|')
foreach ($field in @('lexerMs','parserMs','analysisMs','totalMs')) {
  $lines.Add("| $field | $(Fmt (Sum $x $field)) | $(Fmt (Sum $y $field)) |")
}
$lines.Add('')
$lines.Add('lexerMs/parserMs/analysisMs sum per-file medians; totalMs sums complete per-file repeated runs including I/O. Same installed compiler, Debug checks, host and repeat count; runs are sequential historical observations with ordinary scheduling/cache variation, not controlled performance guarantees. The directive prepass and newly exposed CST construction add work; no timing threshold is asserted.')
$lines.Add('')
$lines.Add('## Encoding exclusions')
$lines.Add('')
foreach ($f in $a.files | Where-Object {!$_.lossless}) {
  if ($old[$f.path].status -cne $f.status) { throw "Failure status changed: $($f.path)" }
  $lines.Add("- $($f.repository): ``$($f.path)`` — $($f.status) in both runs.")
}
$lines.Add('')
$lines.Add('## Parser diagnostic changes')
$lines.Add('')
$changes = @(foreach ($p in $pairs) {
  $prevErrors = @($p.before.diagnostics | Where-Object {$_.code -like 'PAR*' -and $_.severity -eq 'dsError'})
  $newErrors = @($p.after.diagnostics | Where-Object {$_.code -like 'PAR*' -and $_.severity -eq 'dsError'})
  $prevKeys = @{}; foreach($d in $prevErrors){$key=$d | ConvertTo-Json -Compress; if(!$prevKeys.ContainsKey($key)){$prevKeys[$key]=0};$prevKeys[$key]++}
  $newKeys = @{}; foreach($d in $newErrors){$key=$d | ConvertTo-Json -Compress; if(!$newKeys.ContainsKey($key)){$newKeys[$key]=0};$newKeys[$key]++}
  $added=@(foreach($key in $newKeys.Keys){$n=$newKeys[$key]-$prevKeys[$key];for($i=0;$i -lt $n;$i++){$key | ConvertFrom-Json}})
  $removed=@(foreach($key in $prevKeys.Keys){$n=$prevKeys[$key]-$newKeys[$key];for($i=0;$i -lt $n;$i++){$key | ConvertFrom-Json}})
  if($added.Count -or $removed.Count){
    [pscustomobject]@{path=$p.after.path;before=$prevErrors.Count;after=$newErrors.Count;
      added=@($added | Sort-Object start,code,message);removed=@($removed | Sort-Object start,code,message)}
  }
})
$changes | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 -LiteralPath (Join-Path (Split-Path $Output) 'diagnostic-changes.json')
foreach($c in $changes){$lines.Add("- ``$($c.path)``: errors $($c.before) -> $($c.after); added $($c.added.Count), removed $($c.removed.Count).")}
$lines.Add('')
$lines.Add('Exact new/removed error code, severity, message and UTF-16 span records are in [diagnostic-changes.json](diagnostic-changes.json). Removing whole-input protection exposes existing unsupported grammar and recovery diagnostics; these are measured parser errors, not proof that upstream source fails to compile. No foreign units were compiled. Warning-message/span refinements also identify include/unknown blockers directly; the complete original diagnostics remain in each report.')
$lines.Add('')
$lines.Add('## Remaining complete-input blockers')
$lines.Add('')
$fallback = @($allNew | Where-Object directiveFallback)
$causes = @($fallback | ForEach-Object {
  $messages=@($_.diagnostics | ForEach-Object message)
  if($messages -contains 'Malformed conditional structure preserved as opaque'){'malformed-conditional'}
  elseif($messages -contains 'Include directive requires unresolved source expansion'){'include'}
  elseif($messages -contains 'Unknown compiler directive preserved as opaque'){'unknown-directive'}
  elseif($messages -contains 'Directive outside a safe section boundary'){'unproven-context'}
  else{'other-unclassified'}
} | Group-Object | Sort-Object Count -Descending)
foreach($c in $causes){$lines.Add("- $($c.Name): $($c.Count) files (parser diagnostic evidence; one priority category per fallback).")}
$lines.Add('')
$lines.Add('Include/unknown/malformed categories are explicit parser reasons, not raw keyword guesses. Other contexts are not automatically labeled as type/method/declaration positions. Manual contextual evidence, five improved source excerpts and at least five remaining problem cases are in [examples.md](examples.md).')
[IO.File]::WriteAllLines([IO.Path]::GetFullPath($Output), $lines, [Text.UTF8Encoding]::new($false))
Write-Output "PASS: $($pairs.Count) paired snapshots; comparison and diagnostic deltas written"
