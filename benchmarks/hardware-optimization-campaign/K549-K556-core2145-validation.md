# Qwen3.6 35B A3B MTP core 2145 validation

Date: 2026-08-03

## Fixed contract

- Model: `Qwen3.6-35B-A3B-UD-Q3_K_M.gguf`
- Model SHA-256: `8966DD0CD8C543C4228490A2A8B0E0814FC4F1E6A8E199CEED4DE6754AE7B8E1`
- Server SHA-256: `AB4E2A3EE57443A61293865F4440125B08F1D639FD117D0CA1A6B542CC0063AA`
- CUDA SHA-256: `607B21407FFB6577CDD60FD6F1D1D32980971DCB57FC97018893664F6FC36319`
- RTX 3090 clocks: 2145 MHz core, 9751 MHz memory
- Context: 150000; batch: 2048; ubatch: 512; threads: 10; parallel: 1
- Sampling: temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, backend sampling
- MTP: depth 5, p-min 0.0, p-split 0.0, vocabulary 40960
- Workload: sampled single-user streamed C++ generation, 512-token cap
- Seeds: 101, 202, 303, 404, 505

## Fresh baseline and target

- Promoted 1935 MHz ordinary all-run median: 283.938180130871 tok/s
- Required gain: 30 tok/s
- Required result: 313.938180130871 tok/s

## Winner raw ordinary results

The three independent five-seed sets are retained in `K549`, `K550`, and `K551`.

Sorted generation tok/s across all 15 runs:

`287.421921174373, 292.286950529930, 296.342892973407, 305.723331849301, 306.213835558821, 307.391630559352, 308.395308816724, 322.347848342007, 322.660210201368, 323.296418454311, 326.344613978823, 330.654740731015, 337.637609345652, 338.706727393019, 340.301289939165`

- All-run median: 322.347848342007 tok/s
- Gain over baseline: 38.409668211136 tok/s
- Output-token trajectory in every set: 343, 348, 345, 352, 352
- Ten ordinary generated programs from the first two qualification sets compiled and passed their assertions.

## Real-use qualification

- `K555`: cold streamed five-seed median 319.395263488594 tok/s; output trajectory unchanged.
- `K556`: warm non-streamed five-seed median 323.169358645440 tok/s; output trajectory unchanged.
- `K552`: 500-repeat medium-context streamed run completed for three seeds. Seeds 101 and 202 compiled and passed. Seed 303 reproduced an existing sampling-quality limitation and was not used to claim a quality improvement.
- `K554`: 135097-token cold non-streamed prompt completed at 206.617943633461 generation tok/s. Its answer SHA-256 exactly matched the promoted 1935 MHz baseline answer and compiled and passed.
- `K549` through `K556`: no server crash, CUDA error, OOM, or model-load failure.
- Idle VRAM returned to 409 MiB after each run.

## Profiling basis

Nsight Systems report `profiles/P492-current-promoted.nsys-rep` identified Q8_0 J6 MMVQ, fused IQ3 MoE, IQ4_XS MoE, F32 matmul, Q8_1 quantization, and GDN as the dominant GPU work. Kernel rewrites tested from that profile were rejected when they changed output stability or reduced real throughput. The promoted change therefore retains the qualified binaries and raises only the launcher's validated RTX 3090 core lock.
