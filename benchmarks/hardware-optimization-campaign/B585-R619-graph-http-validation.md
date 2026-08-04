# Qwen3.6 A3B MTP graph and HTTP qualification

Date: 2026-08-03

## Fixed workload

- Model: Qwen3.6-35B-A3B-UD-Q3_K_M, SHA256
  `8966DD0CD8C543C4228490A2A8B0E0814FC4F1E6A8E199CEED4DE6754AE7B8E1`
- Server: `engines/k424-context-skip5/llama-server.exe`, SHA256
  `AB4E2A3EE57443A61293865F4440125B08F1D639FD117D0CA1A6B542CC0063AA`
- RTX 3090, driver 610.62, CUDA 13.3, context 150000
- Batch 2048, microbatch 512, threads 10, parallel 1, F16 target and draft KV
- MTP depth 5, p-min 0.0, p-split 0.0, 40960-token draft projection
- Temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, reasoning off
- Backend sampling, five fixed seeds, 512-token coding cap
- Authoritative metric: streamed generation-only TPS; stream-total is the
  client-visible guard

## Fresh baseline

B585-B587 measured the promoted launcher in three independent five-seed
batches. The ordinary median over all 15 runs was 295.708 tok/s generation
only, 295.726 tok/s server decode, and 272.262 tok/s stream total. The new
thresholds were therefore 310.708 and 287.262 tok/s.

All 18 baseline outputs, including warmups, compiled under MSVC C++20 with
`/W4 /WX`, executed, and passed. No historical rate was used as the baseline.

## Profiling and rejected arms

The exact P560 Nsight trace attributes 21.1% of GPU kernel time to Q8_0
six-column verification, 14.1% to fused IQ3_S MoE, 10.4% to IQ4_XS MoE, and
7.4% to float matrix-vector work. CUDA API time is dominated by stream
synchronization, asynchronous copies, and graph launches.

Depth four regressed. Q8_0 one- and four-warp geometries regressed and changed
outputs. High process priority regressed. Core offsets of +150 and +200 MHz
were unstable, and +500 MHz memory changed trajectories. +120 MHz passed the
short screen but failed the repeated medium-context stability gate, so the
previously qualified +100 MHz offset was retained.

## Qualified winner

The retained changes are:

- `GGML_CUDA_GRAPH_OPT=1`
- one HTTP worker for the single-request contract
- the previously qualified 2190/9751 MHz locks, 100% fan, and +100 MHz core
  offset remain unchanged

R607-R609 measured the exact final stack in three independent five-seed
batches. The ordinary all-15 medians were:

- generation only: 330.979 tok/s, +35.271 tok/s
- server decode: 330.786 tok/s
- stream total: 302.860 tok/s, +30.597 tok/s
- TTFT: 95.210 ms

All 15 short outputs were byte-identical to the fresh baseline. All 18 final
short outputs, including warmups, compiled warning-clean and passed.

## Real-use matrix

- R610: five cold streamed short requests
- R611: five warm non-streamed short requests
- R606: five warm streamed 13.6k-context requests
- R612: five warm non-streamed 135k-context requests
- R615: five independently restarted cold 13.6k-context requests
- R616: five independently restarted cold 135k-context requests
- R618: 135049-token cold plus five warm 128-token exact C++ quality requests

The independently cold medium median was 278.294 tok/s generation only with
3910 ms TTFT. The independently cold near-limit median was 197.696 tok/s
decode with 64339 ms TTFT. R618 produced six byte-identical programs; all six
compiled warning-clean and passed. Every qualifying run returned accelerator
memory to its recorded starting value.

The original long-context coding prompt produced malformed programs for some
seeds in both candidate and matched control, with byte-identical candidate and
control output. Those prompt defects were not attributed to the optimization.
R618 supplies the separate long-context retrieval and compile quality gate.

## Launcher validation

R619 launched `run-qwen.bat` with MSI Afterburner initially stopped, verified
the exact server, model, alias, binary hash, and `--threads-http 1`, completed a
streamed request, then stopped the exact server. The launcher stopped
Afterburner, reset the locks and offset, and returned the GPU to 429 MiB at
1695/9751 MHz.
