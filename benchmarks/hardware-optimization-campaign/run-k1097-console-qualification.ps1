[CmdletBinding()]
param(
    [string]$Engine = 'C:\llama-cpp-src\engines\k1097-k514-exactptx-iq3s-l2prefetch\llama-server.exe'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:SESSIONNAME -notmatch '^Console$') {
    throw "Console session required; current session is '$env:SESSIONNAME'"
}

$root = 'C:\llama-cpp-src'
$runner = Join-Path $root 'benchmarks\hardware-optimization-campaign\run-realworld.ps1'
$env:LLAMA_QWEN35_MTP_HOTMAP = Join-Path $root 'benchmarks\hardware-optimization-campaign\qwen36-target-hotmap-ranked-1575.txt'

$batches = @(
    [pscustomobject]@{ Id = 'K1159-k1097-console-forward-five'; Seeds = @(101, 202, 303, 404, 505) },
    [pscustomobject]@{ Id = 'K1160-k1097-console-reverse-five'; Seeds = @(505, 404, 303, 202, 101) },
    [pscustomobject]@{ Id = 'K1161-k1097-console-repeat-five';  Seeds = @(101, 202, 303, 404, 505) }
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
    Remove-Item Env:LLAMA_QWEN35_MTP_HOTMAP -ErrorAction SilentlyContinue
}
