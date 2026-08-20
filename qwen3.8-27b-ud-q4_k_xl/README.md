# Qwen3.8-27B UD-Q4_K_XL

Run `run-qwen.bat` to serve the local Unsloth UD-Q4_K_XL model with its F16 vision projector.

The launcher defaults to a 130,000-token context, full CUDA offload, Q8_0 K/V cache, Flash Attention, thinking enabled, and the model's recommended coding sampling. Override any launcher variable before running the batch file when needed.

## Sources

- Model repository: `unsloth/Qwen3.8-27B-GGUF`
- Model repository revision: `27af057ecb382ddfea5d12837360a8980560e3ed`
- llama.cpp upstream commit: `947fd9bb2bdeaa72e9dd74b6aa3b5d68f03f3d6a`

## Build

The binaries in `build-qwen38-ud-q4-k-xl\bin` use CUDA 13.3, MSVC 19.44, CMake Release mode, and CUDA architecture 86.

## SHA-256

- `Qwen3.8-27B-UD-Q4_K_XL.gguf`: `3F227079003ADD2511437E5B1E94812E363385225BF6A9B47B0054A72BC8B01E`
- `mmproj-F16.gguf`: `CBB841A9EE0636B2EC172F5BB8DF2EA8DFEB01E90FE7C6126581D662A0B4E43E`

Model files and build products are excluded from Git.
