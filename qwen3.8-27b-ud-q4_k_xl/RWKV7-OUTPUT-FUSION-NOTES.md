# RWKV7 output preparation fusion (upstream PR #27267)

## What this is

Integration of upstream llama.cpp PR https://github.com/ggml-org/llama.cpp/pull/27267
("cuda: fuse RWKV7 output preparation into a single kernel") into this branch,
on top of upstream commit `947fd9bb2`.

The PR fuses the post-recurrent RWKV7 output preparation chain into one CUDA
kernel. The chain, as it appears in the cgraph, is:

```
NORM -> RESHAPE -> MUL -> ADD -> MUL -> RESHAPE -> MUL -> SUM_ROWS -> MUL -> RESHAPE -> ADD [-> MUL (gate)]
```

Per (token, head) the fused kernel now does in a single pass:

1. per-head layernorm of the recurrent output `x` (eps taken from the NORM op params),
2. affine transform (weight + bias),
3. the RKV correction term `v * sum_rows(k * r * r_k)`,
4. optional gate multiply.

Previously this was 11 to 12 separate kernel launches per layer per step. The
upstream PR reports a 5-7% TG128 decode speedup on their hardware.

## Files changed

- `ggml/src/ggml-cuda/ggml-cuda.cu`
  - `ggml_cuda_rwkv7_output_fusion` struct + `ggml_cuda_other_src` helper +
    `ggml_cuda_try_rwkv7_output_fusion` matcher (inserted after
    `ggml_cuda_try_gdn_cache_fusion`).
  - NORM dispatch at the top of `ggml_cuda_try_fuse`: on a match it checks the
    fusion memory ranges, launches `ggml_cuda_op_rwkv7_output_fused`, and skips
    the elided nodes.
- `ggml/src/ggml-cuda/wkv.cu`
  - `rwkv7_output_f32<head_size, has_gate>` kernel (one block per (token, head);
    head_size 64 or 128; the norm stats use a 32-thread warp reduction to match
    the standalone norm kernel's reduction order).
  - `ggml_cuda_op_rwkv7_output_fused` launcher.
- `ggml/src/ggml-cuda/wkv.cuh` - declaration of the launcher.
- `tests/test-backend-ops.cpp`
  - `test_rwkv7_output` test case (head_size 64/128, n_tokens 1/4, gate on/off,
    plus two negative cases that must reject the fusion and run the original
    graph: broadcast affine tensors, and a norm weight that is itself an
    elided compute node).

The change is verbatim from the PR; no local modifications.

## Relevance to this branch

This model (Qwen3.8-27B UD-Q4_K_XL) uses the RWKV7 linear-attention path
(`ggml_rwkv_wkv7`), which is exactly what the fusion targets. The fused kernel
runs on every decode step for every linear-attention layer, so it should show
up directly in generation tok/s.

## Verification status

- [x] Code integrated (4 files, verbatim from PR #27267, 451 insertions)
- [x] `wkv.cu` and `ggml-cuda.cu` compile clean (objects built in
      `build-qwen38-ud-q4-k-xl`, CUDA 13.3, MSVC 19.44, SM86, Release)
- [x] `tests/test-backend-ops.cpp` compiles clean (verified standalone with
      the exact build flags)
- [ ] Link `ggml-cuda.dll` / `llama-server.exe` - blocked while the old
      `llama-server.exe` (PID 20452) holds `bin\ggml-base.dll` open
- [ ] Correctness: `test-backend-ops` with the new RWKV7_OUTPUT cases
      (CPU reference vs CUDA fused path)
- [ ] Benchmark: restart server via `run-qwen.bat`, compare generation tok/s
      against the pre-fusion baseline

## Finishing the build after the server restart

All objects are already compiled; only the final links are pending. After the
old server is stopped, run:

```
cd C:\llama-cpp-src\build-qwen38-ud-q4-k-xl
rebuild-server.bat
```

This links `ggml-base.dll`, `ggml-cuda.dll`, and `llama-server.exe` in one
pass (no recompilation). Then optionally run the new correctness tests:

```
bin\test-backend-ops.exe -b CUDA -t "RWKV7_OUTPUT"
```

## Rollback

The change is uncommitted (working tree only). To revert without touching the
branch:

```
git checkout -- ggml/src/ggml-cuda/ggml-cuda.cu ggml/src/ggml-cuda/wkv.cu ggml/src/ggml-cuda/wkv.cuh tests/test-backend-ops.cpp
```

then rebuild. Alternatively, the fusion can be disabled at runtime for A/B
testing without a rebuild:

```
set GGML_CUDA_DISABLE_FUSION=1
```

(note: this disables all CUDA graph fusions, not just this one).

## Benchmark: post-fusion baseline (2026-08-19)

First measured run with PR #27267 integrated. Server built 14:38 (CUDA 13.3,
MSVC 19.44, SM86, Release), launched via `run-qwen.bat` (ctx 120000, Q8_0 K/V,
FA on, MTP draft-n-max 4, p-split 0.10, backend sampling).

Method: `/metrics` cumulative counters `tokens_predicted_total` and
`tokens_predicted_seconds_total`, delta across each request. "Predicted tokens"
counts every draft token the target verifies (accepted + rejected), so it is
higher than the visible completion token count.

| Run | Prompt | Visible gen | Predicted tokens | Gen time | Throughput |
|---|---|---:|---:|---:|---:|
| C++ fib program | 42 | 93 (stop) | 462 | 9.33 s | 49.5 tok/s |
| B-tree explanation | 43 | 512 (length) | 512 | 9.22 s | 55.5 tok/s |
| Combined | - | - | 974 | 18.55 s | 52.5 tok/s |

MTP acceptance in this window was about 2.1 accepted tokens per verification
step.

Compare a future A/B (e.g. `GGML_CUDA_DISABLE_FUSION=1` or a stashed rebuild)
against these numbers.
