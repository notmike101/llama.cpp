# Qwen3.8-27B Q4_K_M

Run `run-qwen.bat` to serve the Q4_K_M model with its F16 vision projector.
The launcher uses the model's embedded MTP predictor. The projector stays in
CPU memory so the 147,456-token Q8_0 K/V cache and MTP state fit on a 24 GiB
RTX 3090. The qualified configuration left about 669 MiB free during a request.

The launcher defaults thinking to off. Anthropic clients enable it per request:

```json
{
  "thinking": {
    "type": "enabled",
    "budget_tokens": 1024
  }
}
```

Omitting `thinking`, or sending `{"thinking":{"type":"disabled"}}`, keeps
thinking disabled. The coding sampling defaults are temperature 0.6, top-k 20,
top-p 0.95, min-p 0.0, repeat penalty 1.0, and presence penalty 0.0.

The model and projector can be relocated with the `MODEL` and `MMPROJ`
environment variables. Other launcher defaults can be overridden the same way.

## Build

The qualified binary was built from commit `0e4b4d643` with CUDA 13.3, MSVC
19.44, CMake Release mode, native CPU instructions, and CUDA architecture 86:

```powershell
cmake -S . -B build-qwen38 -G Ninja `
    -DGGML_CUDA=ON `
    -DCMAKE_CUDA_ARCHITECTURES=86 `
    -DCMAKE_BUILD_TYPE=Release
cmake --build build-qwen38 --config Release --target llama-server -j 10
```

Expected SHA-256 values:

- `Qwen3.8-27B-Q4_K_M.gguf`: `7B2AEC3B9ABABDFD75AA17552EE95607D866E44DECF547F6F12FCEF85CC89F1B`
- `mmproj-F16.gguf`: `CBB841A9EE0636B2EC172F5BB8DF2EA8DFEB01E90FE7C6126581D662A0B4E43E`
- Qualified `llama-server.exe`: `B1E3B6B5CE97ED90EA9D0F4EAF8863157E51A727223D3E58EDFE3F5C1A6F48E7`

Model files and build products are intentionally excluded from Git.

## Benchmark

The fixed workload used `POST /completion`, no prompt cache, no streaming, one
request at a time, 512 generated tokens, and seeds 101, 202, 303, 404, and 505.
The request fields were:

```json
{
  "prompt": "Write a C++20 function that validates balanced brackets while ignoring brackets inside quoted strings. Include a compact self-test. Return code only.",
  "n_predict": 512,
  "seed": 101,
  "temperature": 0.6,
  "top_k": 20,
  "top_p": 0.95,
  "min_p": 0.0,
  "cache_prompt": false,
  "stream": false
}
```

Change only `seed` for the other four runs. The ordinary five-run median was
63.89 server decode tok/s and 62.42 request end-to-end tok/s. The corresponding
baseline without MTP was 38.54 and 37.99 tok/s. Complete responses, timings,
identity manifests, and summaries are in `baseline-20260814-100334-measured` and
`M002-mtp4-cpummproj-five`.

Raw `/completion` does not apply a chat template, so `--reasoning off` does not
suppress `<think>` output on this endpoint. Use `/v1/chat/completions` with
`chat_template_kwargs.enable_thinking` set to `false` for normal client output.
