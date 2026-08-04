[CmdletBinding()]
param(
    [string]$Engine = 'C:\llama-cpp-src\engines\k1097-k514-exactptx-iq3s-l2prefetch\llama-server.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$activeSession = (& qwinsta | Where-Object { $_ -match '^>' }) -join ' '
if ($activeSession -notmatch '^>console\s+') {
    throw "Console session required; current session is '$activeSession'"
}

$root = 'C:\llama-cpp-src'
$runner = Join-Path $root 'benchmarks\hardware-optimization-campaign\run-realworld.ps1'
$env:LLAMA_SPEC_TARGET_FAST_SAMPLE = '1'
$env:LLAMA_QWEN35_TARGET_HOTMAP = Join-Path $root 'benchmarks\hardware-optimization-campaign\qwen36-target-hotmap-ranked-1575.txt'

$batches = @(
    [pscustomobject]@{ Id = 'K1165-k1097-console-forward-five'; Seeds = @(101, 202, 303, 404, 505) },
    [pscustomobject]@{ Id = 'K1166-k1097-console-reverse-five'; Seeds = @(505, 404, 303, 202, 101) },
    [pscustomobject]@{ Id = 'K1167-k1097-console-repeat-five';  Seeds = @(101, 202, 303, 404, 505) }
)

try {
    foreach ($batch in $batches) {
        & $runner `
            -Id $batch.Id `
            -Engine $Engine `
            -Seeds $batch.Seeds `
            -DraftMax 5 `
            -DraftMin 0 `
            -DraftPMin 0.16 `
            -DraftPSplit 0.10 `
            -Threads 8 `
            -MtpVocab 40192 `
            -Mode stream
    }
} finally {
    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Remove-Item Env:LLAMA_SPEC_TARGET_FAST_SAMPLE -ErrorAction SilentlyContinue
    Remove-Item Env:LLAMA_QWEN35_TARGET_HOTMAP -ErrorAction SilentlyContinue
}
