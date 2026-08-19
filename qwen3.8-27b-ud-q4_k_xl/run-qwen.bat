@echo off
setlocal EnableExtensions

if not defined LLAMA_SERVER set "LLAMA_SERVER=C:\llama-cpp-src\build-qwen38-ud-q4-k-xl\bin\llama-server.exe"
if not defined MODEL set "MODEL=%~dp0Qwen3.8-27B-UD-Q4_K_XL.gguf"
if not defined MMPROJ set "MMPROJ=%~dp0mmproj-F16.gguf"
if not defined HOST set "HOST=0.0.0.0"
if not defined PORT set "PORT=8080"
if not defined MODEL_ALIAS set "MODEL_ALIAS=qwen3.8-27b@ud-q4_k_xl"
if not defined CTX set "CTX=32768"
if not defined BATCH set "BATCH=2048"
if not defined UBATCH set "UBATCH=512"
if not defined THREADS set "THREADS=6"
if not defined PARALLEL set "PARALLEL=1"
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

echo Launching "%MODEL_ALIAS%" with vision enabled
"%LLAMA_SERVER%" ^
    -m "%MODEL%" ^
    --mmproj "%MMPROJ%" ^
    --no-mmproj-offload ^
    --alias "%MODEL_ALIAS%" ^
    --host "%HOST%" ^
    --port "%PORT%" ^
    --jinja ^
    --reasoning off ^
    --reasoning-format auto ^
    -ngl all ^
    -c "%CTX%" ^
    -b "%BATCH%" ^
    -ub "%UBATCH%" ^
    -t "%THREADS%" ^
    -tb "%THREADS%" ^
    -np "%PARALLEL%" ^
    -fa on ^
    -ctk q8_0 ^
    -ctv q8_0 ^
    --temp 0.6 ^
    --top-k 20 ^
    --top-p 0.95 ^
    --min-p 0.0 ^
    --repeat-penalty 1.0 ^
    --presence-penalty 0.0 ^
    %EXTRA_ARGS%

exit /b %ERRORLEVEL%
