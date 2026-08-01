# Qwen3.6 MTP real-use campaign

Target identity: `qwen36_35b_a3b_mtp_q3km` in `../model-targets.json`.
No Qwen3.6 27B result, engine, hot-vocabulary map, n-gram setting, vision
configuration, or 65,536-context measurement is evidence for this campaign.
The shared working tree contains later 27B changes and is not the provenance
source for the promoted 35B engine. The packaged engine and CUDA DLL hashes in
the target manifest are authoritative until a clean 35B-only source build is
reconstructed and requalified.

2026-08-01 continuation target: improve the qualified production-like streamed
chat median by at least 5 tok/s without changing the model, quant, sampling,
context, output cap, or quality gate.

Real-use control RW001: 184.89 tok/s streamed end-to-end, 199.71 tok/s server
decode, and 171.28 ms TTFT across seeds 101, 202, 303, 404, and 505.

Promoted R002: MTP p-min 0.20 plus target/draft polling disabled. Five raw
streamed end-to-end results were 198.01, 188.25, 187.70, 192.31, and 191.42
tok/s, median 191.42 tok/s. Server decode median was 207.89 tok/s and TTFT
median was 133.12 ms. This is +6.53 tok/s (+3.53%) versus RW001. All five
answers compiled with MSVC C++20 `/W4 /WX`, executed, and passed their
assertions. Draft acceptance remained active at 81.7% to 86.6%, with mean
accepted lengths from 4.27 to 4.43. VRAM returned exactly to the 731 MiB
pre-run baseline. The production launcher now carries these two settings.

Repaired-source candidate K001: the later mixed 27B/35B working tree initially
failed 1 of 1,210 focused CUDA backend cases for Q6_K expert routing. A narrow
fallback guard restored 1,210 of 1,210 passes. The rebuilt engine then reached
198.89 tok/s streamed end-to-end and 216.82 tok/s server decode across five
seeds. All five programs compiled warning-clean and passed. This is not a
promoted source build because the pre-existing working tree still combines
uncommitted changes from both model campaigns.

The real-use matrix also passed: a cached 13,597-token streamed request reached
183.44 tok/s end-to-end; a cold non-streamed request at the same length had
4,554.66 ms prompt time and 211.90 tok/s decode; and a cold 32,497-token request
had 11,768.13 ms prompt time and 181.50 tok/s decode. Each response remained a
warning-clean passing C++20 program. Nsight Systems P020 captured the finalist;
quantized matrix-vector kernels remained the dominant GPU cost.

Target: median sampled generation speed >= 215 tok/s across five rotating seeds.

Fixed contract: Qwen3.6-35B-A3B MTP UD-Q3_K_M, CUDA, context 150000, one request, 512 output limit, reasoning off, temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, batch 2048, microbatch 512, F16 KV, MTP depth 4, backend sampling.

Host: Windows 11 Pro, Intel i9-10900KF (10C/20T), RTX 3090 24 GiB, driver 610.62. Repository commit 40b740ad05c531b9d57aca6698c3ed553a9e784c.

Promoted winner: engines/b10079-mtp-215tps. Five measured seeds: 220.58, 216.49, 212.80, 186.20, and 220.12 tok/s. Median 216.49 tok/s. Peak 73 C, 271 W, and 20,783 MiB VRAM. All five generated C++20 programs compiled with MSVC `/W4 /WX`, executed successfully, and passed their assertions.

Improvement over the original official B001 median of 171.54 tok/s: +44.95 tok/s (+26.20%). Improvement over the prior 200.19 tok/s qualification: +16.30 tok/s (+8.14%).

Retained stack: synchronized-hidden-state removal, Q8_1 quantization at 128 threads, direct CUDA SSM convolution state with MTP rollback snapshots, quantized beta-projection sigmoid fusion, persistent alias-safe Q8_1 activation reuse, direct runtime-index GDN state gathering, three/one warps for the Q6_K one/five-column shapes, four warps for Q8_0 five-column verification, one fused MoE row per block for IQ3_S gate/up projections, a dual IQ3_S dot product that reuses Q8 activations, four MoE rows per block for unfused IQ3_XXS, eight for IQ4_XS, and exact CUB 64x4 router sorting.

Artifacts: ../Q006-iq3-dual-rpb1-five.stderr.log and Q006-iq3-dual-rpb1-five-response-1.json through Q006-iq3-dual-rpb1-five-response-6.json. The launcher is ../../Qwen3.6-35B-A3B-MTP-GGUF/run-qwen.bat.
