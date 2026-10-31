#requires -Version 7.0
<#
.SYNOPSIS
Read-only structural checks for the A0 design documents and repository entry points.
.DESCRIPTION
Checks registers, traceability, relative Markdown links and obvious competing
Pascal API declarations in fenced code. This is not a semantic consistency proof,
a Delphi compiler, an external-link checker or a Markdown implementation.
No ignored build files, personal paths, Git state or backup manifests are required.
#>
[CmdletBinding()]
param(
    [string]$Repository = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$issues = [Collections.Generic.List[object]]::new()
$documents = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::OrdinalIgnoreCase)

function Add-Issue([string]$Severity, [string]$Path, [int]$Line, [string]$Message) {
    $issues.Add([pscustomobject]@{
        Severity = $Severity; Path = $Path; Line = $Line; Message = $Message
    })
}

function Report-Issues {
    foreach ($item in $issues | Sort-Object Path, Line, Severity, Message) {
        $message = '{0}:{1}: {2}' -f $item.Path, $item.Line, $item.Message
        if ($item.Severity -eq 'Error') {
            Write-Output "ERROR $message"
        } else {
            Write-Warning $message
        }
    }
}

try {
    $root = [IO.Path]::GetFullPath($Repository)
} catch {
    Write-Output "ERROR Repository:1: Invalid repository path: $($_.Exception.Message)"
    exit 1
}
$spec = 'design/docs/spec/'
$canonical = @(
    '01_PRODUCT_REQUIREMENTS.md', '02_ARCHITECTURE.md', '03_LEXER.md',
    '04_SOURCE_CST.md', '05_DIRECTIVES.md', '06_FORMATTER.md',
    '07_RAD_CONFIG.md', '08_TESTS.md', '09_IMPLEMENTATION_PLAN.md',
    '10_LANGUAGE_COVERAGE.md', '11_OPEN_QUESTIONS.md', '12_CURRENT_CODE_AUDIT.md',
    '13_ACCEPTANCE_SCENARIOS.md', '14_CONTRACTS.md', '15_TRACEABILITY.md',
    '16_A0_CHANGELOG.md'
) | ForEach-Object { $spec + $_ }
$required = @(
    'AGENTS.md', 'CODEX_START.md', 'README.md',
    'design/README.md', 'design/CONTRIBUTING_IMPLEMENTATION.md',
    'design/fixtures/contracts/README.md',
    'design/docs/adr/ADR-001-source-cst.md',
    'design/docs/adr/ADR-002-safe-editing.md',
    'design/docs/adr/ADR-003-native-config.md',
    'design/docs/adr/ADR-004-contracts-and-baseline.md'
) + $canonical
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        Add-Issue Error $relative 1 'Required canonical/entry document is missing.'
    }
}
if ($issues.Count -gt 0) {
    Report-Issues
    exit 1
}
$paths = @($required)
foreach ($directory in @('design/docs/spec', 'design/docs/adr')) {
    $paths += Get-ChildItem -LiteralPath (Join-Path $root $directory) -Filter '*.md' -File |
        ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/') }
}
foreach ($relative in $paths | Sort-Object -Unique) {
    try {
        $full = Join-Path $root $relative
        $text = [IO.File]::ReadAllText($full)
        $documents.Add($relative, [pscustomobject]@{
            Path = $relative; Full = $full; Text = $text
            Lines = @([regex]::Split($text, '\r?\n'))
        })
    } catch {
        Add-Issue Error $relative 1 "Cannot read document: $($_.Exception.Message)"
    }
}
if ($issues.Count -gt 0) {
    Report-Issues
    exit 1
}

function Get-TableRows($Document) {
    $header = $null
    $inFence = $false
    for ($i = 0; $i -lt $Document.Lines.Count; $i++) {
        $line = $Document.Lines[$i]
        if ($line -match '^\s*(?:~{3,}|\x60{3,})') {
            $inFence = -not $inFence
            $header = $null
            continue
        }
        if ($inFence) { continue }
        if ($line -notmatch '^\s*\|.*\|\s*$') {
            $header = $null
            continue
        }
        $cells = @(([regex]::Split($line.Trim().Trim('|'), '(?<!\\)\|')) |
            ForEach-Object { $_.Trim() })
        if (@($cells | Where-Object { $_ -notmatch '^:?-{3,}:?$' }).Count -eq 0) {
            continue
        }
        if ($null -eq $header) { $header = $cells; continue }
        [pscustomobject]@{
            Path = $Document.Path; Line = $i + 1; Cells = $cells; Header = $header
        }
    }
}

function Read-Register([string]$File, [string]$Header, [string]$Pattern) {
    $items = [Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal)
    foreach ($row in Get-TableRows $documents[$spec + $File]) {
        if ($row.Header[0] -ne $Header) { continue }
        $matchItem = [regex]::Match($row.Cells[0], $Pattern)
        if (-not $matchItem.Success) {
            Add-Issue Error $row.Path $row.Line "Malformed register ID: $($row.Cells[0])"
            continue
        }
        $id = $matchItem.Groups[1].Value
        if ($items.ContainsKey($id)) {
            Add-Issue Error $row.Path $row.Line (
                "Duplicate ID $id; first definition at $($items[$id].Path):$($items[$id].Line).")
        } else {
            $items.Add($id, $row)
        }
    }
    if ($items.Count -eq 0) {
        Add-Issue Error ($spec + $File) 1 "Empty or missing register: $Header"
    }
    return ,$items
}

$requirements = Read-Register '01_PRODUCT_REQUIREMENTS.md' 'ID' '^([A-Z]+-\d{2})$'
$tests = Read-Register '08_TESTS.md' 'Test-ID' '^(T-[A-Z0-9-]+)$'
$steps = Read-Register '09_IMPLEMENTATION_PLAN.md' 'PR-ID' '^([A-Z]+\d+|REL)$'
$roles = Read-Register '04_SOURCE_CST.md' 'Shape-ID' '^(N-[A-Z0-9-]+)$'
$features = Read-Register '10_LANGUAGE_COVERAGE.md' 'Feature-ID / Priorität' '^(LF-\d{2}) /'
$experiments = Read-Register '11_OPEN_QUESTIONS.md' 'Experiment-ID' '^(E-[A-Z0-9-]+)$'
$families = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($row in $features.Values) {
    foreach ($matchItem in [regex]::Matches(($row.Cells -join ' '), '\bK-LF-\d{2}\b')) {
        [void]$families.Add($matchItem.Value)
    }
}
function Test-Step([string]$Id) {
    if ($steps.ContainsKey($Id)) { return $true }
    $family = [regex]::Match($Id, '^(K-LF-\d{2})(?:-[a-z0-9-]+)?$')
    return $family.Success -and $families.Contains($family.Groups[1].Value)
}

$traceRows = @(Get-TableRows $documents[$spec + '15_TRACEABILITY.md'] |
    Where-Object { $_.Header[0] -eq 'Requirement' })
$traced = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($row in $traceRows) {
    $id = $row.Cells[0]
    if (-not $requirements.ContainsKey($id)) {
        Add-Issue Error $row.Path $row.Line "Unknown trace requirement: $id"
    }
    if (-not $traced.Add($id)) {
        Add-Issue Error $row.Path $row.Line "Duplicate trace row: $id"
    }
    if ($row.Cells.Count -lt 4 -or
        [string]::IsNullOrWhiteSpace($row.Cells[1]) -or
        [string]::IsNullOrWhiteSpace($row.Cells[2])) {
        Add-Issue Error $row.Path $row.Line "Incomplete Requirement-to-Test-to-PR trace: $id"
        continue
    }
    foreach ($token in [regex]::Matches($row.Cells[1], '[^\s,]+')) {
        if (-not $tests.ContainsKey($token.Value)) {
            Add-Issue Error $row.Path $row.Line "Unknown trace test: $($token.Value)"
        }
    }
    foreach ($token in [regex]::Matches($row.Cells[2], '[^\s,]+')) {
        if (-not (Test-Step $token.Value)) {
            Add-Issue Error $row.Path $row.Line "Unknown trace implementation step: $($token.Value)"
        }
    }
}
foreach ($id in $requirements.Keys | Sort-Object) {
    if (-not $traced.Contains($id)) {
        $row = $requirements[$id]
        Add-Issue Error $row.Path $row.Line "Requirement $id has no trace row in 15_TRACEABILITY.md."
    }
}

function Test-HeadingAnchor([string]$Path, [string]$Anchor) {
    $seen = @{}
    foreach ($line in [regex]::Split([IO.File]::ReadAllText($Path), '\r?\n')) {
        if ($line -notmatch '^#{1,6}\s+(.+?)(?:\s+#+)?\s*$') { continue }
        $slug = $Matches[1].ToLowerInvariant() -replace '[^\p{L}\p{Nd}\p{M}\s_-]', ''
        $slug = $slug.Trim() -replace '\s', '-'
        $number = 0
        if ($seen.ContainsKey($slug)) { $number = $seen[$slug] + 1 }
        $seen[$slug] = $number
        if ($number -gt 0) { $slug += "-$number" }
        if ($slug -ceq $Anchor) { return $true }
    }
    return $false
}

$linkCount = 0
function Check-Link($Document, [int]$Line, [string]$Target) {
    if ($Target -match '^[A-Za-z][A-Za-z0-9+.-]*:') { return }
    $script:linkCount++
    try {
        $parts = $Target.Trim('<', '>') -split '#', 2
        $pathPart = [Uri]::UnescapeDataString($parts[0])
        $full = $Document.Full
        if ($pathPart.Length -gt 0) {
            if ([IO.Path]::IsPathRooted($pathPart)) {
                Add-Issue Error $Document.Path $Line "Non-portable absolute local link: $Target"
                return
            }
            $full = [IO.Path]::GetFullPath((Join-Path (Split-Path $Document.Full) $pathPart))
        }
        $relative = [IO.Path]::GetRelativePath($root, $full)
        if ($relative -eq '..' -or $relative.StartsWith('../') -or $relative.StartsWith('..\')) {
            Add-Issue Error $Document.Path $Line "Local link leaves the repository: $Target"
        } elseif (-not (Test-Path -LiteralPath $full)) {
            Add-Issue Error $Document.Path $Line "Broken relative Markdown link: $Target"
        } elseif ($parts.Count -eq 2 -and $parts[1].Length -gt 0) {
            if ([IO.Path]::GetExtension($full) -eq '.md') {
                if (-not (Test-HeadingAnchor $full ([Uri]::UnescapeDataString($parts[1])))) {
                    Add-Issue Warning $Document.Path $Line (
                        "Heading-anchor heuristic could not resolve: $Target; check manually.")
                }
            } else {
                Add-Issue Warning $Document.Path $Line "Non-Markdown fragment not checked: $Target"
            }
        }
    } catch {
        Add-Issue Error $Document.Path $Line "Invalid Markdown link $Target : $($_.Exception.Message)"
    }
}

$contractsPath = $spec + '14_CONTRACTS.md'
$canonicalTypes = @(
    'TSyntaxTree', 'TDiagnostic', 'TContextState', 'TSlotDecision',
    'TProtectedRange', 'TFormatResult', 'TFormattingOptions',
    'TNativeProfileResult', 'TEffectiveOptionsResult'
) + @([regex]::Matches($documents[$contractsPath].Text,
    '(?m)^\s*(T[A-Za-z0-9_]+)\s*=') | ForEach-Object { $_.Groups[1].Value })
$requirementPrefixes = @($requirements.Keys | ForEach-Object { ($_ -split '-')[0] } |
    Sort-Object -Unique)
$requirementPattern = '\b(?:' + ($requirementPrefixes -join '|') + ')-\d{2}(?!\d)\b'
$stepPrefixes = @($steps.Keys | Where-Object { $_ -match '\d$' } |
    ForEach-Object { $_ -replace '\d+$', '' } | Sort-Object -Unique)
foreach ($document in $documents.Values | Sort-Object Path) {
    $fence = $null
    $pascal = $false
    for ($i = 0; $i -lt $document.Lines.Count; $i++) {
        $line = $document.Lines[$i]
        $fenceMatch = [regex]::Match($line, '^\s*(~{3,}|\x60{3,})(.*)$')
        if ($fenceMatch.Success) {
            $marker = $fenceMatch.Groups[1].Value[0]
            if ($null -eq $fence) {
                $fence = $marker
                $pascal = $fenceMatch.Groups[2].Value.Trim() -match '^(pascal|delphi|objectpascal)$'
            } elseif ($fence -eq $marker) {
                $fence = $null
                $pascal = $false
            }
            continue
        }
        if ($null -ne $fence) {
            if ($pascal -and $document.Path -ne $contractsPath) {
                $typeMatch = [regex]::Match($line, '^\s*(T[A-Za-z0-9_]+)\s*=')
                $apiMatch = [regex]::Match($line,
                    '^\s*(?:class\s+)?function\s+(?:\w+\.)?(FormatText|LoadNativeProfile|ParseSource)\s*\(')
                if (($typeMatch.Success -and $typeMatch.Groups[1].Value -in $canonicalTypes) -or
                    $apiMatch.Success) {
                    Add-Issue Error $document.Path ($i + 1) (
                        'Competing normative API declaration outside 14_CONTRACTS.md.')
                }
            }
            continue
        }
        foreach ($matchItem in [regex]::Matches($line,
            '!?\[[^\]]*\]\((<[^>]+>|[^)\s]+)(?:\s+"[^"]*")?\)')) {
            Check-Link $document ($i + 1) $matchItem.Groups[1].Value
        }
        $referenceLink = [regex]::Match($line, '^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)')
        if ($referenceLink.Success) {
            Check-Link $document ($i + 1) $referenceLink.Groups[1].Value
        }
        foreach ($matchItem in [regex]::Matches($line, $requirementPattern)) {
            if (-not $requirements.ContainsKey($matchItem.Value)) {
                Add-Issue Error $document.Path ($i + 1) "Unknown requirement: $($matchItem.Value)"
            }
        }
        foreach ($entry in @(
            @{ Pattern = '\bT-[A-Z0-9]+(?:-[A-Z0-9]+)*\b'; Register = $tests; Label = 'test' },
            @{ Pattern = '\bN-[A-Z0-9]+(?:-[A-Z0-9]+)*\b'; Register = $roles; Label = 'role' },
            @{ Pattern = '\bE-[A-Z0-9]+(?:-[A-Z0-9]+)*\b'; Register = $experiments; Label = 'experiment' }
        )) {
            foreach ($matchItem in [regex]::Matches($line, $entry.Pattern)) {
                if (-not $entry.Register.ContainsKey($matchItem.Value)) {
                    Add-Issue Error $document.Path ($i + 1) (
                        "Unknown $($entry.Label) reference: $($matchItem.Value)")
                }
            }
        }
        foreach ($matchItem in [regex]::Matches($line,
            '(?<![\p{L}\p{N}_-])(?:K-LF-\d{2}(?:-[a-z][a-z0-9-]*)?|[A-Z]{1,4}\d+|REL)(?![\p{L}\p{N}_-])')) {
            $id = $matchItem.Value
            # S0 is a safety profile; G0 is the explicitly historical architecture gate.
            if ($id -in @('S0', 'G0') -or $id -match '^[MP]\d+$') { continue }
            $prefix = $id -replace '\d+$', ''
            if (($id.StartsWith('K-LF-') -or $prefix -in $stepPrefixes -or $id -eq 'REL') -and
                -not (Test-Step $id)) {
                Add-Issue Error $document.Path ($i + 1) "Unknown implementation step: $id"
            }
        }
    }
    if ($null -ne $fence) {
        Add-Issue Warning $document.Path $document.Lines.Count 'Unclosed code fence; inspect manually.'
    }
}

Report-Issues
$errorCount = @($issues | Where-Object Severity -eq Error).Count
$warningCount = @($issues | Where-Object Severity -eq Warning).Count
Write-Output ('Checked: {0} documents, {1} requirements, {2} tests, {3} steps, {4} trace rows, {5} local links.' -f
    $documents.Count, $requirements.Count, $tests.Count, $steps.Count, $traceRows.Count, $linkCount)
Write-Output "Warnings: $warningCount. Text checks do not prove semantic consistency or API correctness."
if ($errorCount -gt 0) {
    Write-Output "FAIL: $errorCount error(s)."
    exit 1
}
Write-Output 'PASS: structural document checks.'
exit 0
