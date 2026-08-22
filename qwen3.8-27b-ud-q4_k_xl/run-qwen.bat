@echo off
setlocal EnableExtensions

if not defined LLAMA_SERVER set "LLAMA_SERVER=C:\llama-cpp-src\build-qwen38-ud-q4-k-xl\bin\llama-server.exe"
if not defined MODEL set "MODEL=C:\llama-cpp-src\qwen3.8-27b-ud-q4_k_xl\Qwen3.8-27B-UD-Q4_K_XL.gguf"
if not defined MMPROJ set "MMPROJ=C:\llama-cpp-src\qwen3.8-27b-ud-q4_k_xl\mmproj-F16.gguf"
if not defined HOST set "HOST=0.0.0.0"
if not defined PORT set "PORT=8080"
if not defined HEALTH_HOST set "HEALTH_HOST=%HOST%"
if /I "%HEALTH_HOST%"=="0.0.0.0" set "HEALTH_HOST=127.0.0.1"
if not defined MODEL_ALIAS set "MODEL_ALIAS=qwen3.8-27b@ud-q4_k_xl"
if not defined CTX set "CTX=147456"
if not defined BATCH set "BATCH=2048"
if not defined UBATCH set "UBATCH=512"
if not defined THREADS set "THREADS=6"
if not defined PARALLEL set "PARALLEL=1"
if not defined CACHE_TYPE_K set "CACHE_TYPE_K=q8_0"
if not defined CACHE_TYPE_V set "CACHE_TYPE_V=q8_0"
if not defined LLAMA_TEMP set "LLAMA_TEMP=0.6"
if not defined TOP_K set "TOP_K=20"
if not defined TOP_P set "TOP_P=0.95"
if not defined MIN_P set "MIN_P=0.0"
if not defined REPEAT_PENALTY set "REPEAT_PENALTY=1.0"
if not defined PRESENCE_PENALTY set "PRESENCE_PENALTY=0.0"
if not defined LLAMA_QWEN35_MTP_VOCAB set "LLAMA_QWEN35_MTP_VOCAB=64"
if not defined LLAMA_QWEN35_MTP_MAP set "LLAMA_QWEN35_MTP_MAP=%~dp0mtp-tail-token-map.txt"
if not defined SPEC_DRAFT_N_MAX set "SPEC_DRAFT_N_MAX=5"
if not defined SPEC_DRAFT_P_SPLIT set "SPEC_DRAFT_P_SPLIT=0.10"
if not defined LLAMA_CUDA_GDN_DIRECT_STATE_GATHER set "LLAMA_CUDA_GDN_DIRECT_STATE_GATHER=1"
if not defined LLAMA_CUDA_SSM_CONV_DIRECT_STATE set "LLAMA_CUDA_SSM_CONV_DIRECT_STATE=1"

rem Mapped chained drafting uses the compact prefix and tail output head.
if not defined LLAMA_SPEC_CHAIN set "LLAMA_SPEC_CHAIN=1"
if not defined LLAMA_SPEC_CHAIN_SKIP_PROB set "LLAMA_SPEC_CHAIN_SKIP_PROB=1"
if not defined LLAMA_SPEC_CHAIN_SUB set "LLAMA_SPEC_CHAIN_SUB=32768"
if not defined LLAMA_SCHED_POOL set "LLAMA_SCHED_POOL=0"
if not defined LLAMA_META_MIRROR_OUTPUT set "LLAMA_META_MIRROR_OUTPUT=0"
if not defined EXTRA_ARGS set "EXTRA_ARGS="

if not exist "%LLAMA_SERVER%" (
    echo ERROR: llama-server was not found at "%LLAMA_SERVER%"
    exit /b 2
)
if not exist "%MODEL%" (
    echo ERROR: model was not found at "%MODEL%"
    exit /b 2
)
if not exist "%MMPROJ%" (
    echo ERROR: vision projector was not found at "%MMPROJ%"
    exit /b 2
)

curl -fsS -m 3 "http://%HEALTH_HOST%:%PORT%/health" >nul 2>&1
if not errorlevel 1 (
    echo ERROR: port %PORT% already has a healthy server.
    exit /b 3
)

echo Launching "%MODEL_ALIAS%" with vision enabled
"%LLAMA_SERVER%" ^
    -m "%MODEL%" ^
    --mmproj "%MMPROJ%" ^
    --no-mmproj-offload ^
    --image-min-tokens 1024 ^
    --alias "%MODEL_ALIAS%" ^
    --host "%HOST%" ^
    --port "%PORT%" ^
    --jinja ^
    --reasoning-format auto ^
    --reasoning-preserve ^
    -ngl all ^
    -c "%CTX%" ^
    -b "%BATCH%" ^
    -ub "%UBATCH%" ^
    -t "%THREADS%" ^
    -tb "%THREADS%" ^
    -np "%PARALLEL%" ^
    -fa on ^
    --fit off ^
    -ctk "%CACHE_TYPE_K%" ^
    -ctv "%CACHE_TYPE_V%" ^
    --temp "%LLAMA_TEMP%" ^
    --top-k "%TOP_K%" ^
    --top-p "%TOP_P%" ^
    --min-p "%MIN_P%" ^
    --repeat-penalty "%REPEAT_PENALTY%" ^
    --presence-penalty "%PRESENCE_PENALTY%" ^
    --spec-type draft-mtp ^
    --spec-draft-n-max "%SPEC_DRAFT_N_MAX%" ^
    --spec-draft-n-min 0 ^
    --spec-draft-p-min 0.0 ^
    --spec-draft-p-split "%SPEC_DRAFT_P_SPLIT%" ^
    --backend-sampling ^
    --spec-draft-device CUDA0 ^
    --spec-draft-ngl all ^
    --spec-draft-threads "%THREADS%" ^
    --spec-draft-threads-batch "%THREADS%" ^
	--metrics ^
    %EXTRA_ARGS%

set "SERVER_EXIT=%ERRORLEVEL%"
if not "%SERVER_EXIT%"=="0" echo llama-server exited with code %SERVER_EXIT%
exit /b %SERVER_EXIT%
