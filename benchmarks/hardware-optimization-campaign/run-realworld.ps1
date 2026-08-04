[CmdletBinding()]
param(
    [string]$Id = 'RW001-promoted-control',
    [string]$Engine = 'C:\llama-cpp-src\engines\b10079-mtp-215tps\llama-server.exe',
    [string]$Model = '',
    [int]$Port = 18080,
    [int[]]$Seeds = @(101, 202, 303, 404, 505),
    [int]$DraftMax = 4,
    [int]$DraftMin = 0,
    [string]$SpecType = 'draft-mtp',
    [double]$DraftPMin = 0.25,
    [double]$DraftPSplit = 0.10,
    [int]$Threads = 10,
    [int]$Batch = 2048,
    [int]$UBatch = 512,
    [ValidateSet('stream', 'nonstream')][string]$Mode = 'stream',
    [string]$PromptFile = '',
    [ValidateRange(0, 5000)][int]$ContextRepeat = 0,
    [int]$MaxTokens = 512,
    [switch]$SkipWarmup,
    [ValidateRange(0, 100)][int]$Poll = 50,
    [ValidateRange(0, 100)][int]$DraftPoll = 50,
    [ValidateSet(0, 1)][int]$Q8SourceReuse = 1,
    [ValidateSet(0, 1)][int]$Q8PersistentSourceReuse = 1,
    [ValidateSet(0, 1)][int]$SsmDirectState = 1,
    [ValidateSet(0, 1)][int]$GdnProjectionFusion = 1,
    [ValidateSet(0, 1)][int]$GdnDirectStateGather = 1,
    [ValidateSet(0, 1)][int]$DeviceCheckpoint = 0,
    [ValidateRange(0, 248320)][int]$MtpVocab = 0,
    [switch]$NoHost,
    [ValidateRange(0, 4096)][int]$CacheReuse = 0,
    [ValidateSet('Normal', 'AboveNormal', 'High')][string]$Priority = 'Normal',
    [UInt64]$AffinityMask = 0,
    [string[]]$ExtraArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = 'C:\llama-cpp-src'
$campaign = Join-Path $root 'benchmarks\hardware-optimization-campaign'
$model = if ($Model) { $Model } else { Join-Path $root 'Qwen3.6-35B-A3B-MTP-GGUF\Qwen3.6-35B-A3B-UD-Q3_K_M.gguf' }
$output = Join-Path $campaign $Id
$serverLog = Join-Path $output 'SERVER-LOG.txt'
$serverOut = Join-Path $output 'SERVER-OUT.txt'
$prompt = if ($PromptFile) { [IO.File]::ReadAllText((Resolve-Path $PromptFile)) } else { 'Write a complete C++20 program defining bool valid_brackets(std::string_view s) using a stack. Ignore non-bracket characters and support (), [], and {}. Include at least 10 assertions covering valid, invalid, nested, crossing, unmatched closing, empty, and ordinary-text inputs, then print All tests passed. Return only raw source code, with no Markdown fences, comments, or explanation.' }
if ($ContextRepeat -gt 0) {
    $contextUnit = "Existing project convention: use C++20, standard library containers, deterministic assertions, warning-clean code, and no external dependencies.`n"
    $prompt = ($contextUnit * $ContextRepeat) + "`nTask:`n" + $prompt
}

function Get-Median([double[]]$Values) {
    $valuesSorted = @($Values | Sort-Object)
    $middle = [math]::Floor($valuesSorted.Count / 2)
    if (($valuesSorted.Count % 2) -eq 1) { return $valuesSorted[$middle] }
    return ($valuesSorted[$middle - 1] + $valuesSorted[$middle]) / 2.0
}

function Invoke-Stream([int]$Seed, [string]$RunDirectory) {
    New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null
    $body = [ordered]@{
        model = 'qwen3.6-35b-a3b@q3_k_m'
        messages = @(@{ role = 'user'; content = $prompt })
        temperature = 0.6; top_k = 20; top_p = 0.95; min_p = 0.0
        seed = $Seed; max_tokens = $MaxTokens; backend_sampling = $true
        reasoning_format = 'none'; stream = ($Mode -eq 'stream')
        stream_options = @{ include_usage = $true }
    } | ConvertTo-Json -Depth 10 -Compress
    $client = [Net.Http.HttpClient]::new()
    try {
        $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "http://127.0.0.1:$Port/v1/chat/completions")
        $request.Content = [Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, 'application/json')
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $completionOption = if ($Mode -eq 'stream') { [Net.Http.HttpCompletionOption]::ResponseHeadersRead } else { [Net.Http.HttpCompletionOption]::ResponseContentRead }
        $response = $client.SendAsync($request, $completionOption).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null
        if ($Mode -eq 'nonstream') {
            $rawResponse = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $clock.Stop()
            $result = $rawResponse | ConvertFrom-Json
            $tokens = [double]$result.usage.completion_tokens
            $sourceText = ([string]$result.choices[0].message.content) -replace '^\s*<think>\s*</think>\s*', ''
            [IO.File]::WriteAllText((Join-Path $RunDirectory 'response.json'), $rawResponse, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $RunDirectory 'answer.cpp'), $sourceText, [Text.UTF8Encoding]::new($false))
            return [pscustomobject]@{
                seed = $Seed; output_tokens = $tokens; server_decode_tps = [double]$result.timings.predicted_per_second
                stream_total_tps = $tokens / $clock.Elapsed.TotalSeconds
                stream_generation_only_tps = [double]$result.timings.predicted_per_second
                ttft_ms = [double]$result.timings.prompt_ms; wall_ms = $clock.Elapsed.TotalMilliseconds
                prompt_tokens = [double]$result.timings.prompt_n; prompt_ms = [double]$result.timings.prompt_ms
            }
        }
        $reader = [IO.StreamReader]::new($response.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
        $raw = [Collections.Generic.List[string]]::new()
        $source = [Text.StringBuilder]::new()
        $firstTokenMs = $null
        $lastTokenMs = $null
        $tokens = $null
        $serverTps = $null
        while ($null -ne ($line = $reader.ReadLine())) {
            $raw.Add($line)
            $candidate = $line -replace '^data:\s*', ''
            if ([string]::IsNullOrWhiteSpace($candidate) -or $candidate -eq '[DONE]') { continue }
            try {
                $piece = $candidate | ConvertFrom-Json
                if (@($piece.choices).Count -gt 0 -and $null -ne $piece.choices[0].delta.content) {
                    $delta = [string]$piece.choices[0].delta.content
                    if ($delta.Length -gt 0) {
                        if ($null -eq $firstTokenMs) { $firstTokenMs = $clock.Elapsed.TotalMilliseconds }
                        $lastTokenMs = $clock.Elapsed.TotalMilliseconds
                        [void]$source.Append($delta)
                    }
                }
                if ($null -ne $piece.usage) { $tokens = [double]$piece.usage.completion_tokens }
                if ($null -ne $piece.timings) {
                    $serverTps = [double]$piece.timings.predicted_per_second
                    if ($null -eq $tokens) { $tokens = [double]$piece.timings.predicted_n }
                }
            } catch {}
        }
        $clock.Stop()
        if ($null -eq $tokens -or $null -eq $firstTokenMs) { throw "Incomplete stream metrics for seed $Seed" }
        [IO.File]::WriteAllLines((Join-Path $RunDirectory 'response.sse'), $raw)
        $sourceText = $source.ToString() -replace '^\s*<think>\s*</think>\s*', ''
        [IO.File]::WriteAllText((Join-Path $RunDirectory 'answer.cpp'), $sourceText, [Text.UTF8Encoding]::new($false))
        return [pscustomobject]@{
            seed = $Seed; output_tokens = $tokens; server_decode_tps = $serverTps
            stream_total_tps = $tokens / $clock.Elapsed.TotalSeconds
            stream_generation_only_tps = $tokens / (($lastTokenMs - $firstTokenMs) / 1000.0)
            ttft_ms = $firstTokenMs; wall_ms = $clock.Elapsed.TotalMilliseconds
        }
    } finally { $client.Dispose() }
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$existing = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('llama-server.exe', 'llama-cli.exe', 'llama-bench.exe', 'nsys.exe', 'ncu.exe') })
if ($existing.Count -gt 0) { throw "Inference or profiler process already active: $($existing.ProcessId -join ', ')" }
$env:GGML_CUDA_Q8_SOURCE_REUSE = [string]$Q8SourceReuse
$env:GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE = [string]$Q8PersistentSourceReuse
$env:LLAMA_CUDA_SSM_CONV_DIRECT_STATE = [string]$SsmDirectState
$env:LLAMA_CUDA_GDN_PROJECTION_FUSION = [string]$GdnProjectionFusion
$env:LLAMA_CUDA_GDN_DIRECT_STATE_GATHER = [string]$GdnDirectStateGather
$env:LLAMA_SERVER_DEVICE_CHECKPOINT = [string]$DeviceCheckpoint
if ($MtpVocab -gt 0) {
    $env:LLAMA_QWEN35_MTP_VOCAB = [string]$MtpVocab
} else {
    Remove-Item Env:LLAMA_QWEN35_MTP_VOCAB -ErrorAction SilentlyContinue
}
$hostArgs = if ($NoHost) { @('--no-host') } else { @() }
$cacheArgs = if ($CacheReuse -gt 0) { @('--cache-reuse', "$CacheReuse") } else { @() }
$args = @(
    '-m', $model, '--jinja', '--spec-type', $SpecType, '--spec-draft-n-max', "$DraftMax",
    '--spec-draft-n-min', "$DraftMin", '--spec-draft-p-min', "$DraftPMin", '--spec-draft-p-split', "$DraftPSplit",
    '--backend-sampling', '--spec-draft-device', 'CUDA0', '--spec-draft-ngl', 'all',
    '--spec-draft-threads', "$Threads", '--spec-draft-threads-batch', "$Threads",
    '--alias', 'qwen3.6-35b-a3b@q3_k_m', '--host', '127.0.0.1', '--port', "$Port",
    '-ngl', 'all', '-c', '150000', '-b', "$Batch", '-ub', "$UBatch", '-t', "$Threads", '-tb', "$Threads",
    '-np', '1', '-fa', 'on', '--no-mmap', '-ctk', 'f16', '-ctv', 'f16', '--reasoning', 'off',
    '--reasoning-format', 'none', '--temp', '0.6', '--top-k', '20', '--top-p', '0.95', '--min-p', '0.0',
    '--poll', "$Poll", '--spec-draft-poll', "$DraftPoll", '--no-ui', '--perf'
) + $hostArgs + $cacheArgs + $ExtraArgs
$before = [int](& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
$process = Start-Process -FilePath $Engine -ArgumentList $args -RedirectStandardOutput $serverOut -RedirectStandardError $serverLog -PassThru -WindowStyle Hidden
try {
    if ($Priority -ne 'Normal') { $process.PriorityClass = $Priority }
    if ($AffinityMask -ne 0) { $process.ProcessorAffinity = [IntPtr]$AffinityMask }
    $ready = $false
    for ($i = 0; $i -lt 240; ++$i) {
        if ($process.HasExited) { throw "Server exited with code $($process.ExitCode)" }
        try { if ((Invoke-RestMethod "http://127.0.0.1:$Port/health" -TimeoutSec 1).status -eq 'ok') { $ready = $true; break } } catch {}
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'Server readiness timeout' }
    $owner = Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object -First 1
    $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($owner.OwningProcess)"
    $aliases = (Invoke-RestMethod "http://127.0.0.1:$Port/v1/models").data.id
    if ($live.ExecutablePath -ne $Engine -or $live.CommandLine.IndexOf($model, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or $aliases -notcontains 'qwen3.6-35b-a3b@q3_k_m') { throw 'Live server identity mismatch' }
    [pscustomobject]@{ pid = $live.ProcessId; executable = $live.ExecutablePath; command_line = $live.CommandLine; executable_sha256 = (Get-FileHash $Engine -Algorithm SHA256).Hash; cuda_sha256 = (Get-FileHash (Join-Path (Split-Path $Engine) 'ggml-cuda.dll') -Algorithm SHA256).Hash; model = $model; model_sha256 = (Get-FileHash $model -Algorithm SHA256).Hash; alias = $aliases; verified = $true } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'IDENTITY.json')
    if (-not $SkipWarmup) { Invoke-Stream -Seed 999 -RunDirectory (Join-Path $output 'WARMUP') | ConvertTo-Json | Set-Content (Join-Path $output 'WARMUP.json') }
    $rows = @($Seeds | ForEach-Object { Invoke-Stream -Seed $_ -RunDirectory (Join-Path $output "seed-$_") })
    $summary = [ordered]@{ mode = $Mode; warmup = -not $SkipWarmup; prompt_file = $PromptFile; context_repeat = $ContextRepeat; max_tokens = $MaxTokens; spec_type = $SpecType; batch = $Batch; ubatch = $UBatch; seeds = $Seeds; stream_total_tps_median = Get-Median @($rows.stream_total_tps); stream_generation_only_tps_median = Get-Median @($rows.stream_generation_only_tps); server_decode_tps_median = Get-Median @($rows.server_decode_tps); ttft_ms_median = Get-Median @($rows.ttft_ms); raw_results = $rows }
    $summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $output 'SUMMARY.json')
    $summary | ConvertTo-Json -Depth 10
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id; Wait-Process -Id $process.Id -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    [pscustomobject]@{ before_vram_mib = $before; after_vram_mib = [int](& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) } | ConvertTo-Json | Set-Content (Join-Path $output 'MEMORY.json')
}
