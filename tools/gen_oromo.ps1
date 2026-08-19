$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'lib/l10n/app_strings.dart'
$jsonPath = Join-Path $PSScriptRoot 'oromo_translations.json'
$out = Join-Path $root 'lib/l10n/oromo_catalog.dart'

$matches = [regex]::Matches([System.IO.File]::ReadAllText($src, [Text.UTF8Encoding]::new($false)), "t\('((?:\\'|[^'])*)'")
$keys = @($matches | ForEach-Object { $_.Groups[1].Value -replace "\\'", "'" } |
    Where-Object { $_ -notmatch '\$' } | Select-Object -Unique | Sort-Object)

$tr = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
$jsonText = [System.IO.File]::ReadAllText($jsonPath, [Text.UTF8Encoding]::new($false))
foreach ($line in ($jsonText -split "`n")) {
    if ($line -match '^\s*"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"\s*,?\s*$') {
        $en = [System.Text.RegularExpressions.Regex]::Unescape($matches[1])
        $om = [System.Text.RegularExpressions.Regex]::Unescape($matches[2])
        $tr[$en] = $om
    }
}

function Escape-Dart([string]$s) {
    if ($null -eq $s) { return '' }
    return ($s -replace "'", "\\'")
}

$missing = @()
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/// Afaan Oromoo translations keyed by English source text.')
[void]$sb.AppendLine('class OromoCatalog {')
[void]$sb.AppendLine('  OromoCatalog._();')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('  static const Map<String, String> _strings = {')

foreach ($k in $keys) {
    if (-not $tr.ContainsKey($k)) {
        $missing += $k
        continue
    }
    $ek = Escape-Dart $k
    $ev = Escape-Dart $tr[$k]
    [void]$sb.AppendLine("    '$ek': '$ev',")
}

[void]$sb.AppendLine('  };')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('  static String? lookup(String en) => _strings[en];')
[void]$sb.AppendLine('}')

if ($missing.Count -gt 0) {
    Write-Warning "Missing translations ($($missing.Count)): $($missing -join ' | ')"
}

[System.IO.File]::WriteAllText($out, $sb.ToString(), [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $($keys.Count) entries to $out"
