# Optional report QA uses PowerShell 7's built-in JSON Schema validator.
# It is not a dependency of the Delphi analyzer or its DUnitX suite.
#requires -Version 7.4
param([string]$ReportDirectory = "$PSScriptRoot/../reports/m2_7")
$ErrorActionPreference = 'Stop'
$json = Get-Content -Raw -LiteralPath (Join-Path $ReportDirectory 'coverage.json')
if (!($json | Test-Json -SchemaFile "$PSScriptRoot/../tests/CoverageCorpus/coverage.schema.json")) { throw 'Schema failure' }
$data = $json | ConvertFrom-Json
$csv = @(Import-Csv -LiteralPath (Join-Path $ReportDirectory 'coverage.csv'))
if ($csv.Count -ne $data.files.Count) { throw 'CSV/JSON row mismatch' }
for ($i=0; $i -lt $data.files.Count; $i++) {
  $f = $data.files[$i]
  if ($csv[$i].path -cne $f.path -or $csv[$i].status -cne $f.status) { throw 'CSV order/content mismatch' }
  if (!$f.lossless) {
    if ($null -ne $f.structuredPercent) { throw 'Failure has fabricated coverage' }
    continue
  }
  if ($f.structuredCodeUnits + $f.opaqueCodeUnits + $f.errorCodeUnits -ne $f.codeUnits) { throw 'Code partition' }
  if ($f.structuredUnits + $f.opaqueUnits + $f.errorUnits -ne $f.utf16Units) { throw 'Source partition' }
  if ($f.triviaUnits + $f.directiveUnits + $f.codeUnits -ne $f.utf16Units) { throw 'Trivia/directive partition' }
  if ($f.nonTriviaTokens + $f.triviaTokens + 1 -ne $f.tokens) { throw 'Token partition including EOF' }
  $next = 0
  foreach ($run in $f.tokenCategories) {
    if ($run.firstToken -ne $next) { throw 'Token-category run gap/overlap' }
    $next += $run.count
  }
  if ($next -ne $f.tokens) { throw 'Token-category run extent' }
  if ($f.codeUnits -gt 0 -and [math]::Abs($f.structuredPercent - 100.0*$f.structuredCodeUnits/$f.codeUnits) -gt 0.000001) { throw 'Percentage' }
}
foreach ($summary in $data.summaries | Where-Object group -eq 'all') {
  $rows = @($data.files | Where-Object {
    ($summary.repository -eq '') -or
    ($summary.repository -eq 'external' -and $_.repository -ne 'internal') -or
    ($_.repository -eq $summary.repository)
  })
  $valid = @($rows | Where-Object lossless)
  if ($rows.Count -ne $summary.files -or $valid.Count -ne $summary.validFiles) { throw 'Aggregate counts' }
  foreach ($field in @('codeUnits','structuredCodeUnits','opaqueCodeUnits','errorCodeUnits')) {
    $sum = ($valid | Measure-Object -Property $field -Sum).Sum
    if ($sum -ne $summary.$field) { throw "Aggregate $field" }
  }
}
Write-Output "PASS: schema, $($data.files.Count) CSV/JSON rows, token/source partitions and weighted aggregates"
