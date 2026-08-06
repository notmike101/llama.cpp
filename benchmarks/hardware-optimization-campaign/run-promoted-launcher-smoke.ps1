[CmdletBinding()]
param(
    [string]$Id = 'K1179-promoted-launcher-console-smoke',
    [int]$Port = 18080,
    [int[]]$Seeds = @(101, 202, 303, 404, 505),
    [int]$WarmupSeed = 101
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = 'C:\llama-cpp-src'
$campaign = Join-Path $root 'benchmarks\hardware-optimization-campaign'
$launcher = Join-Path $root 'Qwen3.6-35B-A3B-MTP-GGUF\run-qwen.bat'
$output = Join-Path $campaign "$Id.json"
$serverOut = Join-Path $campaign "$Id.out"
$serverErr = Join-Path $campaign "$Id.err"

$env:HOST = '127.0.0.1'
$env:PORT = [string]$Port
$wrapper = Start-Process -FilePath cmd.exe -ArgumentList @('/d', '/c', $launcher) `
    -RedirectStandardOutput $serverOut -RedirectStandardError $serverErr `
    -WindowStyle Hidden -PassThru

try {
    $ready = $false
    for ($i = 0; $i -lt 240; ++$i) {
        if ($wrapper.HasExited) {
            throw "Launcher exited with code $($wrapper.ExitCode)"
        }
        try {
            if ((Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 1).status -eq 'ok') {
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        throw 'Launcher readiness timeout'
    }

    $owner = Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object -First 1
    $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($owner.OwningProcess)"
    $prompt = 'Write a complete C++20 program defining bool valid_brackets(std::string_view s) using a stack. Ignore non-bracket characters and support (), [], and {}. Include at least 10 assertions covering valid, invalid, nested, crossing, unmatched closing, empty, and ordinary-text inputs, then print All tests passed. Return only raw source code, with no Markdown fences, comments, or explanation.'
    function Invoke-Completion([int]$Seed) {
        $body = @{
            model = 'qwen3.6-35b-a3b@q3_k_m'
            messages = @(@{ role = 'user'; content = $prompt })
            temperature = 0.6
            top_k = 20
            top_p = 0.95
            min_p = 0.0
            seed = $Seed
            max_tokens = 512
            backend_sampling = $true
            reasoning_format = 'none'
            stream = $false
        } | ConvertTo-Json -Depth 8 -Compress
        Invoke-RestMethod "http://127.0.0.1:$Port/v1/chat/completions" `
            -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 120
    }

    Invoke-Completion $WarmupSeed | Out-Null
    $rows = @($Seeds | ForEach-Object {
        $response = Invoke-Completion $_
        [pscustomobject]@{
            seed = $_
            output_tokens = $response.usage.completion_tokens
            generation_tps = $response.timings.predicted_per_second
            content = $response.choices[0].message.content
        }
    })
    $sorted = @($rows.generation_tps | Sort-Object)
    $result = [pscustomobject]@{
        executable = $live.ExecutablePath
        command_line = $live.CommandLine
        median_generation_tps = $sorted[[math]::Floor($sorted.Count / 2)]
        rows = $rows
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content $output
    $result
} finally {
    Get-Process -Name llama-server -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    if (-not $wrapper.HasExited) {
        Stop-Process -Id $wrapper.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item Env:HOST -ErrorAction SilentlyContinue
    Remove-Item Env:PORT -ErrorAction SilentlyContinue
}
