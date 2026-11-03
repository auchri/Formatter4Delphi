#requires -Version 7.0
<#
.SYNOPSIS
Read-only O1 inventory of a local RAD Studio formatter installation and native .config profiles.
.DESCRIPTION
Hashes and describes Formatter.exe and related binaries, then parses native formatter profiles
(shipped, IDE-active and IDE-exported copies) without loading assemblies, DTDs or external
entities. Writes one deterministic JSON document (no timestamps, no absolute paths; values that
look like absolute paths are replaced by a hash). Observed data and derived classifications are
kept in separate fields. Nothing is executed and no input file is modified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BdsRoot,
    [string]$UserConfigDir,
    [string[]]$ExtraProfileDir = @(),
    [Parameter(Mandatory)][string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256([byte[]]$Bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
}

function Get-PeMachine([byte[]]$Bytes) {
    $offset = [BitConverter]::ToInt32($Bytes, 0x3C)
    $machine = [BitConverter]::ToUInt16($Bytes, $offset + 4)
    switch ($machine) { 0x014C { 'x86' } 0x8664 { 'x64' } 0xAA64 { 'arm64' } default { '0x{0:X4}' -f $machine } }
}

function Get-Artifact([string]$Root, [string]$Relative) {
    $full = Join-Path $Root $Relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        return [ordered]@{ location = '$(BDS)\' + $Relative; present = $false }
    }
    $bytes = [IO.File]::ReadAllBytes($full)
    $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($full)
    $assembly = $null
    try { $assembly = [Reflection.AssemblyName]::GetAssemblyName($full).FullName } catch { }
    [ordered]@{
        location = '$(BDS)\' + $Relative; present = $true
        sizeBytes = $bytes.Length; sha256 = Get-Sha256 $bytes
        fileVersion = $info.FileVersion; productVersion = $info.ProductVersion
        productName = $info.ProductName; fileDescription = $info.FileDescription
        companyName = $info.CompanyName; peMachine = Get-PeMachine $bytes
        managedAssembly = $assembly
    }
}

function ConvertTo-AttributeMap($Element) {
    $map = [ordered]@{}
    foreach ($attr in $Element.get_Attributes()) { $map[$attr.Name] = $attr.Value }
    $map
}

function Get-DeclaredConstants([string]$Dll, [string]$Namespace, [string[]]$TypeNames) {
    # Reads enum members / string constants from ECMA-335 metadata only; nothing is loaded or run.
    $result = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Dll -PathType Leaf)) { return $result }
    $stream = [IO.File]::OpenRead($Dll)
    $pe = [Reflection.PortableExecutable.PEReader]::new($stream)
    try {
        $md = [Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($pe)
        foreach ($handle in $md.TypeDefinitions) {
            $type = $md.GetTypeDefinition($handle)
            $name = $md.GetString($type.Name)
            if ($md.GetString($type.Namespace) -ne $Namespace -or $TypeNames -notcontains $name) { continue }
            $members = [ordered]@{}
            foreach ($fieldHandle in $type.GetFields()) {
                $field = $md.GetFieldDefinition($fieldHandle)
                $fieldName = $md.GetString($field.Name)
                $constantHandle = $field.GetDefaultValue()
                if ($fieldName -eq 'value__' -or $constantHandle.IsNil) { continue }
                $constant = $md.GetConstant($constantHandle)
                $blob = $md.GetBlobReader($constant.Value)
                $members[$fieldName] = switch ($constant.TypeCode.ToString()) {
                    'Int32' { $blob.ReadInt32() }
                    'String' { $blob.ReadUTF16($blob.Length) }
                    default { 'unread:' + $constant.TypeCode }
                }
            }
            $result[$name] = $members
        }
    } finally { $pe.Dispose(); $stream.Dispose() }
    $result
}

function Test-AbsolutePath([string]$Value) {
    $Value -match '^[A-Za-z]:[\\/]' -or $Value -match '^\\\\'
}

function Get-Encoding([byte[]]$Bytes) {
    $bom = 'none'; $skip = 0
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { $bom = 'utf-8'; $skip = 3 }
    elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) { $bom = 'utf-16le'; $skip = 2 }
    elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) { $bom = 'utf-16be'; $skip = 2 }
    $strict = [Text.UTF8Encoding]::new($false, $true)
    $validUtf8 = $true
    try { [void]$strict.GetString($Bytes, $skip, $Bytes.Length - $skip) } catch { $validUtf8 = $false }
    $nonAscii = @($Bytes[$skip..($Bytes.Length - 1)] | Where-Object { $_ -ge 0x80 }).Count
    $crlf = 0; $lf = 0; $cr = 0
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -eq 13) {
            if ($i + 1 -lt $Bytes.Length -and $Bytes[$i + 1] -eq 10) { $crlf++; $i++ } else { $cr++ }
        } elseif ($Bytes[$i] -eq 10) { $lf++ }
    }
    $last = if ($Bytes.Length) { $Bytes[$Bytes.Length - 1] } else { 0 }
    [ordered]@{
        bom = $bom; validUtf8WithoutBom = $validUtf8; nonAsciiBytes = $nonAscii
        eol = [ordered]@{ crlf = $crlf; lf = $lf; cr = $cr }
        endsWithNewline = ($last -eq 10 -or $last -eq 13)
    }
}

function Read-Profile([string]$Label, [string]$Location, [string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $settings.IgnoreWhitespace = $true
    $doc = [Xml.XmlDocument]::new()
    $doc.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create([IO.MemoryStream]::new($bytes), $settings)
    try { $doc.Load($reader) } finally { $reader.Dispose() }

    $declaration = $doc.get_ChildNodes() | Where-Object { $_.get_NodeType() -eq 'XmlDeclaration' } | Select-Object -First 1
    $root = $doc.DocumentElement
    $known = @('Name', 'Type', 'Category', 'SubCategory', 'Value', 'Levels')
    $entries = [Collections.Generic.List[object]]::new()
    $children = [ordered]@{}
    $commented = [Collections.Generic.List[string]]::new()
    $comments = 0
    $assemblies = [Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($node in $root.get_ChildNodes()) {
        if ($node.get_NodeType() -eq 'Comment') {
            $comments++
            $m = [regex]::Match($node.get_Value(), '^\s*Option\s+Name="([^"]+)"')
            if ($m.Success) { $commented.Add($m.Groups[1].Value) }
            continue
        }
        if ($node.get_NodeType() -ne 'Element') { continue }
        $element = $node.get_LocalName()
        $children[$element] = 1 + ($children.Contains($element) ? $children[$element] : 0)
        if ($element -eq 'Assemblies') {
            foreach ($a in $node.get_ChildNodes()) {
                if ($a.get_NodeType() -eq 'Element') {
                    $assemblies.Add([ordered]@{ element = $a.get_LocalName(); attributes = ConvertTo-AttributeMap $a })
                }
            }
            continue
        }
        if ($element -ne 'Option') { continue }
        $value = $node.GetAttribute('Value')
        $redacted = $false
        if (Test-AbsolutePath $value) {
            $value = 'redacted-absolute-path:sha256=' + (Get-Sha256 ([Text.Encoding]::UTF8.GetBytes($value)))
            $redacted = $true
        }
        $extra = [ordered]@{}
        foreach ($attr in $node.get_Attributes()) {
            if ($known -notcontains $attr.Name) { $extra[$attr.Name] = $attr.Value }
        }
        $entries.Add([ordered]@{
            index = $index++
            name = $node.GetAttribute('Name')
            type = $node.GetAttribute('Type')
            category = $node.HasAttribute('Category') ? $node.GetAttribute('Category') : $null
            subCategory = $node.HasAttribute('SubCategory') ? $node.GetAttribute('SubCategory') : $null
            levels = $node.HasAttribute('Levels') ? $node.GetAttribute('Levels') : $null
            value = $value
            valueRedacted = $redacted
            attributeOrder = @($node.get_Attributes() | ForEach-Object Name) -join ','
            extraAttributes = $extra
            hasChildNodes = $node.get_HasChildNodes()
        })
    }
    $names = @($entries | ForEach-Object name)
    $duplicates = @($names | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    $groups = [ordered]@{}
    foreach ($n in $names) {
        $g = ($n -split '\.')[0]
        $groups[$g] = 1 + ($groups.Contains($g) ? $groups[$g] : 0)
    }
    [ordered]@{
        label = $Label; location = $Location
        sizeBytes = $bytes.Length; sha256 = Get-Sha256 $bytes
        encoding = Get-Encoding $bytes
        xml = [ordered]@{
            declarationVersion = $declaration ? $declaration.Version : $null
            declarationEncoding = ($declaration -and $declaration.Encoding) ? $declaration.Encoding : $null
            root = $root.get_LocalName()
            rootAttributes = ConvertTo-AttributeMap $root
            rootChildElements = $children
            assemblies = $assemblies
            commentNodes = $comments
            commentedOutOptionNames = $commented
        }
        optionCount = $entries.Count
        duplicateOptionNames = $duplicates
        derivedNamePrefixCounts = $groups
        options = $entries
    }
}

$bds = [IO.Path]::GetFullPath($BdsRoot)
$profileFiles = [Collections.Generic.List[object]]::new()
Get-ChildItem -LiteralPath (Join-Path $bds 'bin\config') -Filter 'Formatter*.config' -File |
    Sort-Object Name | ForEach-Object {
        $profileFiles.Add([pscustomobject]@{ Label = 'shipped:' + $_.Name; Location = '$(BDS)\bin\config\' + $_.Name; Path = $_.FullName })
    }
if ($UserConfigDir) {
    $active = Join-Path $UserConfigDir 'Formatter.config'
    if (Test-Path -LiteralPath $active -PathType Leaf) {
        $profileFiles.Add([pscustomobject]@{ Label = 'ide-active:Formatter.config'; Location = '%APPDATA%\Embarcadero\BDS\<bds-version>\Formatter.config'; Path = $active })
    }
}
foreach ($dir in $ExtraProfileDir) {
    $leaf = Split-Path -Leaf ([IO.Path]::GetFullPath($dir))
    Get-ChildItem -LiteralPath $dir -Filter '*.config' -File | Sort-Object Name | ForEach-Object {
        $profileFiles.Add([pscustomobject]@{ Label = "$($leaf):$($_.Name)"; Location = "local/$leaf/$($_.Name)"; Path = $_.FullName })
    }
}
$profiles = @($profileFiles | ForEach-Object { Read-Profile $_.Label $_.Location $_.Path })

# Option catalog: union of names in first-seen order, per-profile observed attributes.
$catalog = [ordered]@{}
foreach ($p in $profiles) {
    foreach ($e in $p.options) {
        if (-not $catalog.Contains($e.name)) {
            $catalog[$e.name] = [ordered]@{
                name = $e.name
                derivedPrefixGroup = ($e.name -split '\.')[0]
                types = [ordered]@{}; categories = [ordered]@{}; subCategories = [ordered]@{}
                levels = [ordered]@{}; values = [ordered]@{}
            }
        }
        $c = $catalog[$e.name]
        foreach ($pair in @(@('types', $e.type), @('categories', $e.category), @('subCategories', $e.subCategory), @('levels', $e.levels))) {
            $key = $null -eq $pair[1] ? '(absent)' : [string]$pair[1]
            if (-not $c[$pair[0]].Contains($key)) { $c[$pair[0]][$key] = 0 }
            $c[$pair[0]][$key]++
        }
        $c.values[$p.label] = $e.value
    }
}
foreach ($c in $catalog.Values) {
    $c.presentIn = $c.values.Count
    $c.distinctValues = @($c.values.Values | Sort-Object -Unique).Count
}

$comparisons = [Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $profiles.Count; $i++) {
    for ($j = $i + 1; $j -lt $profiles.Count; $j++) {
        $a = $profiles[$i]; $b = $profiles[$j]
        $mapA = @{}; foreach ($e in $a.options) { $mapA[$e.name] = $e }
        $mapB = @{}; foreach ($e in $b.options) { $mapB[$e.name] = $e }
        $diffValues = [Collections.Generic.List[object]]::new()
        $diffAttrs = [Collections.Generic.List[object]]::new()
        $same = 0
        foreach ($e in $a.options) {
            if (-not $mapB.ContainsKey($e.name)) { continue }
            $f = $mapB[$e.name]
            if ($e.value -cne $f.value) { $diffValues.Add([ordered]@{ name = $e.name; a = $e.value; b = $f.value }) } else { $same++ }
            foreach ($attr in 'type', 'category', 'subCategory', 'levels', 'attributeOrder') {
                if ([string]$e[$attr] -cne [string]$f[$attr]) {
                    $diffAttrs.Add([ordered]@{ name = $e.name; attribute = $attr; a = $e[$attr]; b = $f[$attr] })
                }
            }
        }
        $commonA = @($a.options | Where-Object { $mapB.ContainsKey($_.name) } | ForEach-Object name)
        $commonB = @($b.options | Where-Object { $mapA.ContainsKey($_.name) } | ForEach-Object name)
        $comparisons.Add([ordered]@{
            a = $a.label; b = $b.label
            byteIdentical = ($a.sha256 -eq $b.sha256)
            identicalValues = $same
            differentValues = $diffValues
            onlyInA = @($a.options | Where-Object { -not $mapB.ContainsKey($_.name) } | ForEach-Object name)
            onlyInB = @($b.options | Where-Object { -not $mapA.ContainsKey($_.name) } | ForEach-Object name)
            attributeDifferences = $diffAttrs
            commonOptionOrderEqual = (($commonA -join "`n") -ceq ($commonB -join "`n"))
            encodingDifferent = (($a.encoding | ConvertTo-Json -Compress) -cne ($b.encoding | ConvertTo-Json -Compress))
        })
    }
}

$registry = @()
foreach ($hive in 'HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS', 'HKCU:\SOFTWARE\Embarcadero\BDS') {
    if (Test-Path $hive) {
        $registry += Get-ChildItem $hive | Sort-Object PSChildName | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath
            [ordered]@{
                key = ($hive -replace ':\\', '\') + '\' + $_.PSChildName
                productVersion = $p.PSObject.Properties['ProductVersion']?.Value
                edition = $p.PSObject.Properties['Edition']?.Value
                installLanguage = $p.PSObject.Properties['InstallLanguage']?.Value
            }
        }
    }
}

$result = [ordered]@{
    inventoryFormat = 'formatter4delphi.o1.native-artifact-inventory/1'
    generator = 'tests/FormatterOracle/scripts/Get-NativeArtifactInventory.ps1'
    note = 'Observed data only; fields prefixed "derived" are classifications by this script, not relevance or behavior evidence.'
    environment = [ordered]@{
        osVersion = [Environment]::OSVersion.VersionString
        osArchitecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        culture = (Get-Culture).Name; uiCulture = (Get-UICulture).Name
        ansiCodePage = [Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
        bdsRegistry = $registry
    }
    artifacts = @(
        'bin\Formatter.exe', 'bin\Embarcadero.Modeling.Formatter.dll',
        'bin\Embarcadero.Modeling.Formatter.Resources.dll', 'bin\de\Embarcadero.Modeling.Formatter.Resources.dll',
        'bin\Embarcadero.Modeling.OPENAPI3.DLL', 'bin\bds.exe', 'bin\dcc32290.dll', 'bin\dcc64290.dll', 'bin\dcc32.exe', 'bin\dcc64.exe'
    ) | ForEach-Object { Get-Artifact $bds $_ }
    profiles = @($profiles | ForEach-Object {
        $copy = [ordered]@{} + $_
        $copy.Remove('options')
        $copy.optionNamesInOrder = @($_.options | ForEach-Object name)
        $copy.optionsWithExtraAttributes = @($_.options | Where-Object { $_.extraAttributes.Count -gt 0 } |
            ForEach-Object { [ordered]@{ name = $_.name; extraAttributes = $_.extraAttributes; levels = $_.levels } })
        $copy
    })
    declaredConfigTypes = [ordered]@{
        source = '$(BDS)\bin\Embarcadero.Modeling.OPENAPI3.DLL (metadata constants only)'
        namespace = 'Borland.Together.OpenAPI3.Config'
        types = Get-DeclaredConstants (Join-Path $bds 'bin\Embarcadero.Modeling.OPENAPI3.DLL') 'Borland.Together.OpenAPI3.Config' (
            @('CfgFileAttribute', 'FormatterConfigOptionCategory') + @($catalog.Values | ForEach-Object { $_.types.Keys } |
                Where-Object { $_ -like 'Borland.Together.OpenAPI3.Config.*' } | ForEach-Object { $_.Substring(33) } | Sort-Object -Unique))
    }
    optionCatalog = @($catalog.Values)
    comparisons = $comparisons
}
$json = $result | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutFile), $json.Replace("`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Output ('Profiles: {0}; catalog options: {1}; comparisons: {2}; wrote {3}' -f $profiles.Count, $catalog.Count, $comparisons.Count, $OutFile)
