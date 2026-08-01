$nsys = 'C:\Program Files\NVIDIA Corporation\Nsight Systems 2026.1.3\target-windows-x64\nsys.exe'
$server = 'C:\llama-cpp-src\build-audit-35b-mixed\bin\llama-server.exe'
$model = 'C:\llama-cpp-src\Qwen3.6-35B-A3B-MTP-GGUF\Qwen3.6-35B-A3B-UD-Q3_K_M.gguf'
$out = 'C:\llama-cpp-src\benchmarks\hardware-optimization-campaign\profiles\P020-mixed-q6fix-finalist'
New-Item -ItemType Directory -Path (Split-Path $out) -Force | Out-Null

$serverArgs = @(
    '-m', $model, '-ngl', 'all', '-c', '150000', '-b', '2048', '-ub', '512',
    '-t', '10', '-tb', '10', '-fa', 'on', '--no-mmap', '-ctk', 'f16', '-ctv', 'f16',
    '--reasoning', 'off', '--reasoning-format', 'none', '--temp', '0.6', '--top-k', '20',
    '--top-p', '0.95', '--min-p', '0.0', '--spec-type', 'draft-mtp',
    '--spec-draft-n-max', '4', '--spec-draft-n-min', '0', '--spec-draft-p-min', '0.20',
    '--spec-draft-p-split', '0.10', '--backend-sampling', '--spec-draft-device', 'CUDA0',
    '--spec-draft-ngl', 'all', '--spec-draft-threads', '10', '--spec-draft-threads-batch', '10',
    '-np', '1', '--host', '127.0.0.1', '--port', '18080', '--poll', '0',
    '--spec-draft-poll', '0', '--no-ui'
)
$profilerArgs = @(
    'profile', '--trace=cuda,nvtx', '--sample=none', '--cpuctxsw=none',
    '--cuda-graph-trace=node', '--duration=25', '--kill=true', '--force-overwrite=true',
    "--output=$out", $server
) + $serverArgs

$env:GGML_CUDA_Q8_SOURCE_REUSE = '1'
$env:GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE = '1'
$env:LLAMA_CUDA_SSM_CONV_DIRECT_STATE = '1'
$env:LLAMA_CUDA_GDN_PROJECTION_FUSION = '1'
$env:LLAMA_CUDA_GDN_DIRECT_STATE_GATHER = '1'

$profiler = Start-Process -FilePath $nsys -ArgumentList $profilerArgs -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput "$out.stdout.log" -RedirectStandardError "$out.stderr.log"
$profiledServer = $null
try {
    $ready = $false
    for ($i = 0; $i -lt 60; ++$i) {
        try {
            if ((Invoke-RestMethod 'http://127.0.0.1:18080/health' -TimeoutSec 1).status -eq 'ok') {
                $ready = $true
                break
            }
        } catch {}
        Start-Sleep -Milliseconds 250
    }
    if (-not $ready) { throw 'profile server not ready' }

    $profiledServer = Get-Process llama-server -ErrorAction Stop | Where-Object Path -eq $server
    $prompt = 'Write a complete C++20 program defining bool valid_brackets(std::string_view s) using a stack. Ignore non-bracket characters and support (), [], and {}. Include at least 10 assertions covering valid, invalid, nested, crossing, unmatched closing, empty, and ordinary-text inputs, then print All tests passed. Return only raw source code, with no Markdown fences, comments, or explanation.'
    foreach ($seed in 424242, 424243) {
        $body = @{
            model = 'qwen'
            messages = @(@{ role = 'user'; content = $prompt })
            temperature = 0.6
            top_k = 20
            top_p = 0.95
            min_p = 0.0
            seed = $seed
            max_tokens = 512
            stream = $false
        } | ConvertTo-Json -Depth 6 -Compress
        Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18080/v1/chat/completions' -ContentType 'application/json' -Body $body -TimeoutSec 180 | Out-Null
    }
    Wait-Process -Id $profiler.Id -Timeout 40
} finally {
    if ($profiledServer -and -not $profiledServer.HasExited) {
        Stop-Process -Id $profiledServer.Id
    }
}

Get-ChildItem "$out*" | Select-Object Name, Length, LastWriteTime
