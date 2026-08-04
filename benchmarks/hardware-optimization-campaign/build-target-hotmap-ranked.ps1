[CmdletBinding()]
param([int]$Count = 1800)

$ErrorActionPreference = 'Stop'
$campaign = 'C:\llama-cpp-src\benchmarks\hardware-optimization-campaign'
$logs = @(
    'D299-top20-warm-nonstream\SERVER-LOG.txt',
    'D300-top20-cold-stream\SERVER-LOG.txt',
    'D301-top20-medium-warm-stream\SERVER-LOG.txt',
    'D302-top20-nearmax-cold-nonstream\SERVER-LOG.txt'
) | ForEach-Object { Join-Path $campaign $_ }

$frequency = @{}
foreach ($log in $logs) {
    foreach ($line in Get-Content -LiteralPath $log) {
        if (-not $line.StartsWith('FAST_TOP20 ')) { continue }
        foreach ($value in ($line.Substring(11) -split '\s+')) {
            if (-not $value) { continue }
            $id = [int]$value
            $frequency[$id] = 1 + [int]$frequency[$id]
        }
    }
}

$selected = @($frequency.GetEnumerator() |
    Sort-Object @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Key'; Descending = $false } |
    Select-Object -First $Count -ExpandProperty Key |
    Sort-Object)
$output = Join-Path $campaign "qwen36-target-hotmap-ranked-$Count.txt"
('FAST_TOP20 ' + (($selected | ForEach-Object { [string]$_ }) -join ' ')) |
    Set-Content -LiteralPath $output -Encoding ascii -NoNewline

[pscustomobject]@{ output = $output; token_count = $selected.Count; source_unique = $frequency.Count }
