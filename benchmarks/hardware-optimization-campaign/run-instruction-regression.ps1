[CmdletBinding()]
param(
    [string]$Id = 'Q627-instruction-isolation',
    [int[]]$Seeds = @(101),
    [int]$Port = 18080,
    [int]$ArchiveRepeats = 680,
    [int]$RequestMaxTokens = 128,
    [switch]$IncludeTools,
    [switch]$SkipChatParsing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = 'C:\llama-cpp-src'
$campaign = Join-Path $root 'benchmarks\hardware-optimization-campaign'
$output = Join-Path $campaign $Id
$engine = Join-Path $root 'engines\k424-context-skip5\llama-server.exe'
$model = Join-Path $root 'Qwen3.6-35B-A3B-MTP-GGUF\Qwen3.6-35B-A3B-UD-Q3_K_M.gguf'
$serverLog = Join-Path $output 'SERVER-LOG.txt'
$serverOut = Join-Path $output 'SERVER-OUT.txt'

$active = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('llama-server.exe', 'llama-cli.exe', 'llama-bench.exe', 'nsys.exe', 'ncu.exe')
})
if ($active.Count -gt 0) {
    throw "Inference or profiler process already active: $($active.ProcessId -join ', ')"
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$env:GGML_CUDA_GRAPH_OPT = '1'
$env:LLAMA_QWEN35_CONTEXT_SKIP5 = $null
$env:LLAMA_QWEN35_CONTEXT_SKIP5_MAX = $null
$env:LLAMA_SPEC_TARGET_FAST_SAMPLE = '1'
$env:LLAMA_QWEN35_TARGET_HOTMAP = Join-Path $campaign 'qwen36-skipmiddle4-target-hotmap.txt'
$env:LLAMA_QWEN35_MTP_VOCAB = '40960'
$env:LLAMA_SERVER_DEVICE_CHECKPOINT = '1'
$env:GGML_CUDA_Q8_SOURCE_REUSE = '1'
$env:GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE = '1'
$env:LLAMA_CUDA_SSM_CONV_DIRECT_STATE = '1'
$env:LLAMA_CUDA_GDN_PROJECTION_FUSION = '1'
$env:LLAMA_CUDA_GDN_DIRECT_STATE_GATHER = '1'

$args = @(
    '-m', $model, '--jinja', '--spec-type', 'draft-mtp', '--spec-draft-n-max', '5',
    '--spec-draft-n-min', '0', '--spec-draft-p-min', '0.0', '--spec-draft-p-split', '0.0',
    '--backend-sampling', '--spec-draft-device', 'CUDA0', '--spec-draft-ngl', 'all',
    '--spec-draft-threads', '10', '--spec-draft-threads-batch', '10',
    '--alias', 'qwen3.6-35b-a3b@q3_k_m', '--host', '127.0.0.1', '--port', "$Port",
    '-ngl', 'all', '-c', '150000', '-b', '2048', '-ub', '512', '-t', '10', '-tb', '10',
    '--threads-http', '1', '-np', '1', '-fa', 'on', '--no-mmap', '--no-host',
    '-ctk', 'f16', '-ctv', 'f16', '--reasoning', 'off', '--reasoning-format', 'none',
    '--temp', '0.6', '--top-k', '20', '--top-p', '0.95', '--min-p', '0.0',
    '--poll', '0', '--spec-draft-poll', '0', '--no-ui', '--perf'
)
if ($SkipChatParsing) {
    $args += '--skip-chat-parsing'
}

$before = [int](& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
$process = Start-Process -FilePath $engine -ArgumentList $args -RedirectStandardOutput $serverOut `
    -RedirectStandardError $serverLog -WindowStyle Hidden -PassThru

try {
    $ready = $false
    for ($i = 0; $i -lt 240; ++$i) {
        if ($process.HasExited) { throw "Server exited with code $($process.ExitCode)" }
        try {
            if ((Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 1).status -eq 'ok') {
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'Server readiness timeout' }

    $owner = Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object -First 1
    $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($owner.OwningProcess)"
    $aliases = (Invoke-RestMethod "http://127.0.0.1:$Port/v1/models").data.id
    if ($live.ExecutablePath -ne $engine -or $live.CommandLine.IndexOf($model, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
        $aliases -notcontains 'qwen3.6-35b-a3b@q3_k_m') {
        throw 'Live server identity mismatch'
    }
    [ordered]@{
        pid = $live.ProcessId
        executable = $live.ExecutablePath
        command_line = $live.CommandLine
        executable_sha256 = (Get-FileHash $engine -Algorithm SHA256).Hash
        model = $model
        model_sha256 = (Get-FileHash $model -Algorithm SHA256).Hash
        alias = $aliases
        context_skip5 = $false
        verified = $true
    } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'IDENTITY.json')

    $archive = [Text.StringBuilder]::new()
    for ($i = 0; $i -lt $ArchiveRepeats; ++$i) {
        [void]$archive.Append("Archived turn $i discusses unrelated implementation details, test plans, filenames, and status updates. Ignore this archive when following the final user instruction.`n")
    }
    $messages = @(
        @{ role = 'system'; content = 'Follow the latest user instruction exactly. Earlier archive text is context only.' },
        @{ role = 'user'; content = $archive.ToString() },
        @{ role = 'assistant'; content = 'Understood. I will follow the next user instruction.' },
        @{ role = 'user'; content = "Do nothing except say 'Hello'." }
    )
    $tools = @(@{
        type = 'function'
        function = @{
            name = 'unused_tool'
            description = 'An intentionally unused tool.'
            parameters = @{ type = 'object'; properties = @{}; additionalProperties = $false }
        }
    })

    $rows = @()
    foreach ($seed in $Seeds) {
        $body = [ordered]@{
            model = 'qwen3.6-35b-a3b@q3_k_m'
            messages = $messages
            temperature = 0.6
            top_k = 20
            top_p = 0.95
            min_p = 0.0
            seed = $seed
            max_tokens = $RequestMaxTokens
            backend_sampling = $true
            reasoning_format = 'none'
            stream = $false
        }
        if ($IncludeTools) {
            $body.tools = $tools
        }
        $body = $body | ConvertTo-Json -Depth 12 -Compress
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-RestMethod "http://127.0.0.1:$Port/v1/chat/completions" -Method Post `
            -ContentType 'application/json' -Body $body -TimeoutSec 120
        $clock.Stop()
        $text = ([string]$response.choices[0].message.content) -replace '^\s*<think>\s*</think>\s*', ''
        $text = $text.Trim()
        $row = [ordered]@{
            seed = $seed
            prompt_tokens = [int]$response.usage.prompt_tokens
            completion_tokens = [int]$response.usage.completion_tokens
            text = $text
            exact = $text -eq 'Hello'
            finish_reason = [string]$response.choices[0].finish_reason
            wall_ms = $clock.Elapsed.TotalMilliseconds
            server_decode_tps = [double]$response.timings.predicted_per_second
        }
        $rows += [pscustomobject]$row
        $row | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output "seed-$seed.json")
    }
    $summary = [ordered]@{
        required_temperature = 0.6
        requested_max_tokens = $RequestMaxTokens
        grammar_tools_present = [bool]$IncludeTools
        skip_chat_parsing = [bool]$SkipChatParsing
        context_skip5 = $false
        all_exact = -not ($rows.exact -contains $false)
        all_stopped_before_cap = -not ($rows.finish_reason -contains 'length')
        rows = $rows
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $output 'SUMMARY.json')
    $summary | ConvertTo-Json -Depth 10
} finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
    [ordered]@{
        before_vram_mib = $before
        after_vram_mib = [int](& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    } | ConvertTo-Json | Set-Content (Join-Path $output 'MEMORY.json')
}
