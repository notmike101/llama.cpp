# Qwen3.6 A3B MTP hardware qualification

Date: 2026-08-03

## Fixed workload

- Model: Qwen3.6-35B-A3B-UD-Q3_K_M, SHA256
  `8966DD0CD8C543C4228490A2A8B0E0814FC4F1E6A8E199CEED4DE6754AE7B8E1`
- Server: `engines/k424-context-skip5/llama-server.exe`, SHA256
  `AB4E2A3EE57443A61293865F4440125B08F1D639FD117D0CA1A6B542CC0063AA`
- CUDA backend SHA256:
  `607B21407FFB6577CDD60FD6F1D1D32980971DCB57FC97018893664F6FC36319`
- RTX 3090, driver 610.62, CUDA 13.3, 150000 configured context
- Batch 2048, microbatch 512, threads 10, parallel 1, F16 target and draft KV
- MTP depth 5, p-min 0.0, p-split 0.0, 40960-token draft projection
- Temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, reasoning off
- Backend sampling, one streamed request, five fixed seeds, 512-token cap
- Authoritative throughput: streamed generation-only TPS, with stream-total TPS
  retained as the client-visible check

## Fresh control

K557-K559 measured the currently promoted 2145/9751 MHz launcher state in
three independent five-seed batches. The ordinary median over all 15 runs was
310.464 tok/s generation-only, 310.516 tok/s server decode, and 280.556 tok/s
stream-total. The additional-15 thresholds were therefore 325.464 and 295.556
tok/s for generation-only and stream-total respectively.

All output lengths were the established 343, 348, 345, 352, and 352 tokens.
No historical result was used as the control.

## Profiling and rejected arms

P560 profiled the exact control. Q8_0 six-column verification accounted for
21.1% of GPU kernel time, followed by fused IQ3_S and IQ4_XS MoE kernels at
14.1% and 10.4%. Verification-only layer removal reduced MTP efficiency and
was restored. Requested core clocks of 2205 and 2235 MHz were less stable than
the 2190 MHz efficiency point. Fixed 80% fan and fixed 100% fan without a core
offset did not independently meet the target.

## Qualified winner

The retained hardware stack is:

- 2190 MHz requested graphics clock and 9751 MHz memory clock
- 100% fan during model residency
- +100000 kHz MSI Afterburner core-boost offset
- automatic fan control, zero offset, and NVIDIA clock reset on exit

H576-H578 produced these 15 generation-only rates, grouped by batch:

- 305.070, 333.002, 350.585, 338.844, 312.083 tok/s
- 340.099, 350.001, 334.938, 333.295, 319.787 tok/s
- 331.768, 327.309, 343.618, 320.485, 313.178 tok/s

The ordinary all-run median was 333.002 tok/s generation-only, 333.057 tok/s
server decode, and 302.840 tok/s stream-total. This is +22.538 tok/s on the
authoritative metric and +22.284 tok/s client-visible over the fresh control.
Draft acceptance remained active from 68.9% to 78.3% in the sampled logs.

All 15 answers compiled with MSVC C++20 `/W4 /WX`, executed, and passed their
assertions. Output token counts and source hashes matched the fresh control.

## Real-use matrix

- H579 cold streamed short request: 319.661 tok/s generation-only
- H580 warm non-streamed short request: 328.812 tok/s decode
- H581 warm streamed 13.6k-token request: 300.204 tok/s generation-only
- H582 cold non-streamed 135.1k-token request: 214.345 tok/s decode after
  63104 ms prompt processing

All four programs compiled warning-clean and passed. The short, medium, and
near-maximum source hashes matched the prior qualified control. Every finalist
and matrix run returned VRAM from model residency to exactly 409 MiB.

H583 launched through `run-qwen.bat`, verified the expected server executable
and command line, completed a sampled request, stopped the exact server, reset
the core and memory locks, restored automatic fan control and zero core
offset, and returned VRAM to 409 MiB.

H584 began with MSI Afterburner stopped. The launcher started it and the exact
server, then stopped both after server termination and again returned VRAM to
409 MiB with clocks at 1695/9751 MHz.

The launcher uses `macm-control.exe` only while hardware tuning is enabled.
`ENABLE_HARDWARE_TUNING=0` disables the fan and offset path, and the existing
clock, fan, offset, Afterburner, and helper paths remain caller-overridable.
