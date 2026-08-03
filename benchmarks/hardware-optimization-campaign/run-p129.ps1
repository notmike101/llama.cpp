$ErrorActionPreference = 'Stop'
$nsys = 'C:\Program Files\NVIDIA Corporation\Nsight Systems 2026.1.3\target-windows-x64\nsys.exe'
$server = 'C:\llama-cpp-src\engines\b10085-qwen36-device-checkpoint\llama-server.exe'
$model = 'C:\llama-cpp-src\Qwen3.6-35B-A3B-MTP-GGUF\Qwen3.6-35B-A3B-UD-Q3_K_M.gguf'
$out = 'C:\llama-cpp-src\benchmarks\hardware-optimization-campaign\profiles\P129-promoted-device-checkpoint'
$port = 18080

$existing = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('llama-server.exe', 'llama-cli.exe', 'llama-bench.exe', 'nsys.exe', 'ncu.exe')
})
if ($existing.Count -gt 0) { throw "Inference or profiler process already active: $($existing.ProcessId -join ', ')" }

$serverArgs = @(
    '-m', $model, '--jinja', '--spec-type', 'draft-mtp', '--spec-draft-n-max', '4',
    '--spec-draft-n-min', '0', '--spec-draft-p-min', '0.20', '--spec-draft-p-split', '0.10',
    '--backend-sampling', '--spec-draft-device', 'CUDA0', '--spec-draft-ngl', 'all',
    '--spec-draft-threads', '10', '--spec-draft-threads-batch', '10',
    '--alias', 'qwen3.6-35b-a3b@q3_k_m', '--host', '127.0.0.1', '--port', "$port",
    '-ngl', 'all', '-c', '150000', '-b', '2048', '-ub', '512', '-t', '10', '-tb', '10',
    '-np', '1', '-fa', 'on', '--no-mmap', '--no-host', '-ctk', 'f16', '-ctv', 'f16',
    '--reasoning', 'off', '--reasoning-format', 'none', '--temp', '0.6', '--top-k', '20',
    '--top-p', '0.95', '--min-p', '0.0', '--poll', '0', '--spec-draft-poll', '0', '--no-ui'
)
$profilerArgs = @(
    'profile', '--trace=cuda,nvtx', '--sample=none', '--cpuctxsw=none',
    '--cuda-graph-trace=node', '--duration=40', '--kill=true', '--force-overwrite=true',
    "--output=$out", $server
) + $serverArgs

$env:GGML_CUDA_Q8_SOURCE_REUSE = '1'
$env:GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE = '1'
$env:LLAMA_CUDA_SSM_CONV_DIRECT_STATE = '1'
$env:LLAMA_CUDA_GDN_PROJECTION_FUSION = '1'
$env:LLAMA_CUDA_GDN_DIRECT_STATE_GATHER = '1'
$env:LLAMA_SERVER_DEVICE_CHECKPOINT = '1'

& nvidia-smi -lgc 1905,1905 | Out-Null
& nvidia-smi -lmc 9751,9751 | Out-Null
$profiler = $null
$serverProcess = $null
try {
    $profiler = Start-Process -FilePath $nsys -ArgumentList $profilerArgs -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput "$out.stdout.log" -RedirectStandardError "$out.stderr.log"
    $ready = $false
    for ($i = 0; $i -lt 240; ++$i) {
        if ($profiler.HasExited) { throw "Profiler exited with code $($profiler.ExitCode)" }
        try {
            if ((Invoke-RestMethod "http://127.0.0.1:$port/health" -TimeoutSec 1).status -eq 'ok') {
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'Profile server readiness timeout' }
    $owner = Get-NetTCPConnection -LocalPort $port -State Listen | Select-Object -First 1
    $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($owner.OwningProcess)"
    if ($live.ExecutablePath -ne $server -or $live.CommandLine.IndexOf($model, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Live profile server identity mismatch'
    }
    $serverProcess = Get-Process -Id $live.ProcessId
    $prompt = 'Write a complete C++20 program defining bool valid_brackets(std::string_view s) using a stack. Ignore non-bracket characters and support (), [], and {}. Include at least 10 assertions covering valid, invalid, nested, crossing, unmatched closing, empty, and ordinary-text inputs, then print All tests passed. Return only raw source code, with no Markdown fences, comments, or explanation.'
    foreach ($seed in 999, 101, 202, 303, 404, 505) {
        $body = @{
            model = 'qwen3.6-35b-a3b@q3_k_m'; messages = @(@{ role = 'user'; content = $prompt })
            temperature = 0.6; top_k = 20; top_p = 0.95; min_p = 0.0; seed = $seed
            max_tokens = 512; stream = $false
        } | ConvertTo-Json -Depth 8 -Compress
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/v1/chat/completions" `
            -ContentType 'application/json' -Body $body -TimeoutSec 300 | Out-Null
    }
    Wait-Process -Id $profiler.Id -Timeout 60
} finally {
    if ($serverProcess -and -not $serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id }
    if ($profiler -and -not $profiler.HasExited) { Stop-Process -Id $profiler.Id }
    & nvidia-smi -rgc | Out-Null
    & nvidia-smi -rmc | Out-Null
}

Get-ChildItem "$out*" | Select-Object Name, Length, LastWriteTime
