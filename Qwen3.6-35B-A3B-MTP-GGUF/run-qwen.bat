@echo off
setlocal EnableExtensions

rem Optimized llama.cpp b10085 CUDA build qualified at 208.36 tok/s streamed E2E on RTX 3090.
if not defined LLAMA_SERVER set "LLAMA_SERVER=C:\llama-cpp-src\engines\b10085-qwen36-device-checkpoint\llama-server.exe"
if not defined MODEL set "MODEL=C:\llama-cpp-src\Qwen3.6-35B-A3B-MTP-GGUF\Qwen3.6-35B-A3B-UD-Q3_K_M.gguf"
if not defined HOST set "HOST=0.0.0.0"
if not defined PORT set "PORT=8080"
if not defined MODEL_ALIAS set "MODEL_ALIAS=qwen3.6-35b-a3b@q3_k_m"
if not defined NGL set "NGL=all"
if not defined CTX set "CTX=150000"
if not defined BATCH set "BATCH=2048"
if not defined UBATCH set "UBATCH=512"
if not defined THREADS set "THREADS=10"
if not defined PARALLEL set "PARALLEL=1"
if not defined EXTRA_ARGS set "EXTRA_ARGS="
if not defined GPU_CLOCK set "GPU_CLOCK=1935"
if not defined GPU_MEMORY_CLOCK set "GPU_MEMORY_CLOCK=9751"

rem Sampling defaults applied to every request unless the caller overrides.
rem Use LLAMA_TEMP because TEMP is a standard Windows directory variable.
if not defined LLAMA_TEMP set "LLAMA_TEMP=0.6"
if not defined TOP_K set "TOP_K=20"
if not defined TOP_P set "TOP_P=0.95"
if not defined MIN_P set "MIN_P=0.0"
if not defined REASONING set "REASONING=off"
if not defined REASONING_FORMAT set "REASONING_FORMAT=none"
if not defined SPEC_DRAFT_N_MAX set "SPEC_DRAFT_N_MAX=5"
if not defined SPEC_DRAFT_N_MIN set "SPEC_DRAFT_N_MIN=0"
if not defined SPEC_DRAFT_P_MIN set "SPEC_DRAFT_P_MIN=0.20"
if not defined SPEC_DRAFT_P_SPLIT set "SPEC_DRAFT_P_SPLIT=0.10"
if not defined SPEC_ARGS set "SPEC_ARGS="

set "GGML_CUDA_Q8_SOURCE_REUSE=1"
set "GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE=1"
set "LLAMA_CUDA_SSM_CONV_DIRECT_STATE=1"
set "LLAMA_CUDA_GDN_PROJECTION_FUSION=1"
set "LLAMA_CUDA_GDN_DIRECT_STATE_GATHER=1"
set "LLAMA_SERVER_DEVICE_CHECKPOINT=1"

if not "%GPU_CLOCK%"=="0" (
    nvidia-smi -lgc "%GPU_CLOCK%","%GPU_CLOCK%" >nul
    if errorlevel 1 goto clock_error
)
if not "%GPU_MEMORY_CLOCK%"=="0" (
    nvidia-smi -lmc "%GPU_MEMORY_CLOCK%","%GPU_MEMORY_CLOCK%" >nul
    if errorlevel 1 goto clock_error
)

"%LLAMA_SERVER%" ^
    -m "%MODEL%" ^
    --jinja ^
    --spec-type draft-mtp ^
    --spec-draft-n-max "%SPEC_DRAFT_N_MAX%" ^
    --spec-draft-n-min "%SPEC_DRAFT_N_MIN%" ^
    --spec-draft-p-min "%SPEC_DRAFT_P_MIN%" ^
    --spec-draft-p-split "%SPEC_DRAFT_P_SPLIT%" ^
    --backend-sampling ^
    --spec-draft-device CUDA0 ^
    --spec-draft-ngl all ^
    --spec-draft-threads "%THREADS%" ^
    --spec-draft-threads-batch "%THREADS%" ^
    --alias "%MODEL_ALIAS%" ^
    --host "%HOST%" ^
    --port "%PORT%" ^
    -ngl "%NGL%" ^
    -c "%CTX%" ^
    -b "%BATCH%" ^
    -ub "%UBATCH%" ^
    -t "%THREADS%" ^
    -tb "%THREADS%" ^
    -np "%PARALLEL%" ^
    -fa on ^
    --no-mmap ^
    --no-host ^
    -ctk f16 ^
    -ctv f16 ^
    --reasoning "%REASONING%" ^
    --reasoning-format "%REASONING_FORMAT%" ^
    --temp "%LLAMA_TEMP%" ^
    --top-k "%TOP_K%" ^
    --top-p "%TOP_P%" ^
    --min-p "%MIN_P%" ^
    --poll 0 ^
    --spec-draft-poll 0 ^
    %SPEC_ARGS% ^
    %EXTRA_ARGS%

set "SERVER_EXIT=%ERRORLEVEL%"
goto clock_cleanup

:clock_error
set "SERVER_EXIT=%ERRORLEVEL%"

:clock_cleanup
if not "%GPU_CLOCK%"=="0" nvidia-smi -rgc >nul
if not "%GPU_MEMORY_CLOCK%"=="0" nvidia-smi -rmc >nul
exit /b %SERVER_EXIT%
