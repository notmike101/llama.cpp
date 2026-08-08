@echo off
setlocal EnableExtensions

rem Optimized llama.cpp Qwen MTP build qualified on RTX 3090.
if not defined LLAMA_SERVER set "LLAMA_SERVER=C:\llama-cpp-src\engines\k1097-k514-exactptx-iq3s-l2prefetch\llama-server.exe"
if not defined MODELS_PRESET set "MODELS_PRESET=%~dp0qwen-router.ini"
if not defined HOST set "HOST=0.0.0.0"
if not defined PORT set "PORT=8080"
if not defined MODEL_ALIAS set "MODEL_ALIAS=qwen3.6-35b-a3b@q3_k_m"
if not defined UI_CONFIG set "UI_CONFIG=%~dp0qwen-ui-config.json"
if not defined NGL set "NGL=all"
if not defined CTX set "CTX=150000"
if not defined BATCH set "BATCH=2048"
if not defined UBATCH set "UBATCH=512"
if not defined THREADS set "THREADS=8"
if not defined HTTP_THREADS set "HTTP_THREADS=1"
if not defined PARALLEL set "PARALLEL=1"
if not defined EXTRA_ARGS set "EXTRA_ARGS="
if not defined GPU_CLOCK set "GPU_CLOCK=0"
if not defined GPU_MEMORY_CLOCK set "GPU_MEMORY_CLOCK=9751"
if not defined ENABLE_HARDWARE_TUNING set "ENABLE_HARDWARE_TUNING=0"
if not defined GPU_FAN_MODE set "GPU_FAN_MODE=auto"
if not defined GPU_FAN set "GPU_FAN=100"
if not defined GPU_CORE_OFFSET set "GPU_CORE_OFFSET=100000"
if not defined MSI_AFTERBURNER set "MSI_AFTERBURNER=C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
if not defined MACM_CONTROL set "MACM_CONTROL=%~dp0macm-control.exe"

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
if not defined SPEC_DRAFT_P_MIN set "SPEC_DRAFT_P_MIN=0.16"
if not defined SPEC_DRAFT_P_SPLIT set "SPEC_DRAFT_P_SPLIT=0.10"
if not defined MTP_DRAFT_VOCAB set "MTP_DRAFT_VOCAB=40192"
if not defined ENABLE_CONTEXT_SKIP5 set "ENABLE_CONTEXT_SKIP5=0"
if not defined SPEC_TYPE set "SPEC_TYPE=draft-mtp"
if not defined SPEC_ARGS set "SPEC_ARGS="

set "GGML_CUDA_Q8_SOURCE_REUSE=1"
set "GGML_CUDA_Q8_PERSISTENT_SOURCE_REUSE=1"
set "GGML_CUDA_GRAPH_OPT="
set "LLAMA_CUDA_SSM_CONV_DIRECT_STATE=1"
set "LLAMA_CUDA_GDN_PROJECTION_FUSION=1"
set "LLAMA_CUDA_GDN_DIRECT_STATE_GATHER=1"
set "LLAMA_SERVER_DEVICE_CHECKPOINT=0"
set "LLAMA_QWEN35_MTP_VOCAB=%MTP_DRAFT_VOCAB%"
set "LLAMA_SPEC_TARGET_FAST_SAMPLE="
set "LLAMA_QWEN35_TARGET_HOTMAP="
if "%ENABLE_CONTEXT_SKIP5%"=="1" (
    set "LLAMA_QWEN35_CONTEXT_SKIP5=1"
    set "LLAMA_QWEN35_CONTEXT_SKIP5_MAX=4096"
) else (
    set "LLAMA_QWEN35_CONTEXT_SKIP5="
    set "LLAMA_QWEN35_CONTEXT_SKIP5_MAX="
)

set "AB_STARTED=0"
set "HARDWARE_TUNED=0"
if "%ENABLE_HARDWARE_TUNING%"=="1" (
    tasklist /FI "IMAGENAME eq MSIAfterburner.exe" 2>nul | find /I "MSIAfterburner.exe" >nul
    if errorlevel 1 (
        start "" /min "%MSI_AFTERBURNER%"
        timeout /t 5 /nobreak >nul
        set "AB_STARTED=1"
    )
    if /I "%GPU_FAN_MODE%"=="auto" (
        "%MACM_CONTROL%" 0 1 "%GPU_CORE_OFFSET%" 0 >nul
    ) else (
        "%MACM_CONTROL%" "%GPU_FAN%" 0 "%GPU_CORE_OFFSET%" 0 >nul
    )
    if errorlevel 1 goto hardware_error
    set "HARDWARE_TUNED=1"
)

if not "%GPU_CLOCK%"=="0" (
    nvidia-smi -lgc "%GPU_CLOCK%","%GPU_CLOCK%" >nul
    if errorlevel 1 goto clock_error
)
if not "%GPU_MEMORY_CLOCK%"=="0" (
    nvidia-smi -lmc "%GPU_MEMORY_CLOCK%","%GPU_MEMORY_CLOCK%" >nul
    if errorlevel 1 goto clock_error
)

"%LLAMA_SERVER%" ^
    --models-preset "%MODELS_PRESET%" ^
    --no-models-autoload ^
    --jinja ^
    --spec-type "%SPEC_TYPE%" ^
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
    --ui-config-file "%UI_CONFIG%" ^
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
    -ctk f16 ^
    -ctv f16 ^
    --reasoning "%REASONING%" ^
    --reasoning-format "%REASONING_FORMAT%" ^
    --temp "%LLAMA_TEMP%" ^
    --top-k "%TOP_K%" ^
    --top-p "%TOP_P%" ^
    --min-p "%MIN_P%" ^
    --poll 50 ^
    --spec-draft-poll 50 ^
    %SPEC_ARGS% ^
    %EXTRA_ARGS%

set "SERVER_EXIT=%ERRORLEVEL%"
goto clock_cleanup

:clock_error
set "SERVER_EXIT=%ERRORLEVEL%"
goto clock_cleanup

:hardware_error
set "SERVER_EXIT=%ERRORLEVEL%"

:clock_cleanup
if not "%GPU_CLOCK%"=="0" nvidia-smi -rgc >nul
if not "%GPU_MEMORY_CLOCK%"=="0" nvidia-smi -rmc >nul
if "%HARDWARE_TUNED%"=="1" (
    "%MACM_CONTROL%" 0 1 0 0 >nul
    if "%AB_STARTED%"=="1" timeout /t 3 /nobreak >nul
)
if "%AB_STARTED%"=="1" taskkill /IM MSIAfterburner.exe /T /F >nul 2>&1
exit /b %SERVER_EXIT%
