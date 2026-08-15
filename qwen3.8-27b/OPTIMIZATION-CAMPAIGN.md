# Qwen3.8-27B Q4_K_M optimization campaign

## Executive result

This campaign improved the fixed Qwen3.8-27B Q4_K_M workload from a non-speculative median of 38.5420 server decode tokens/s to a final validated median of 97.0403 tokens/s. Request end-to-end throughput improved from 37.9911 to 92.2404 tokens/s. The final result is 2.9597 tokens/s short of the 100 tokens/s goal.

The final comparison is not a claim that the source changes alone produced the entire 58.4983 tokens/s gain. The largest step was enabling the model's embedded MTP predictor. The source changes then improved the MTP configuration. The cleanest source-to-source comparison is the committed MTP control at `8720d0afa` versus the final commit at `9fe315a6b`: 84.0734 to 97.0403 server decode tokens/s, a gain of 12.9669 tokens/s or 15.42 percent. End-to-end throughput increased from 80.4864 to 92.2404 tokens/s, a gain of 11.7540 tokens/s or 14.60 percent.

The only experimental configurations that exceeded 100 tokens/s by a large margin restricted draft or target token support and changed the generated output. They are invalid for the fixed-quality contract and were not retained.

## Benchmark contract

All headline numbers use the same workload unless a section explicitly labels a diagnostic exception.

- Model: `qwen3.8-27b/Qwen3.8-27B-Q4_K_M.gguf`
- Model SHA-256: `7B2AEC3B9ABABDFD75AA17552EE95607D866E44DECF547F6F12FCEF85CC89F1B`
- Vision projector: `qwen3.8-27b/mmproj-F16.gguf`
- Projector SHA-256: `CBB841A9EE0636B2EC172F5BB8DF2EA8DFEB01E90FE7C6126581D662A0B4E43E`
- GPU: NVIDIA GeForce RTX 3090, Ampere SM 86, 24 GiB
- CUDA toolkit: 13.3
- NVIDIA driver: 610.62
- Build: Release, CUDA architecture 86, native CPU instructions
- API: `POST /completion`, non-streaming
- Concurrency: one request
- Prompt cache: disabled
- Prompt: `Write a C++20 function that validates balanced brackets while ignoring brackets inside quoted strings. Include a compact self-test. Return code only.`
- Prompt tokens: 28
- Output limit: 512 tokens
- Measured seeds: 101, 202, 303, 404, and 505
- Warm-up seed: 7, excluded from medians
- Sampling: temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, repeat penalty 1.0, presence penalty 0.0
- Context: 147456
- Batch and microbatch: 2048 and 512
- CPU threads: 6
- Parallel slots: 1
- Flash attention: enabled
- GPU offload: all model layers
- KV cache: Q8_0 keys and Q8_0 values
- Speculation: built-in Qwen MTP, maximum draft depth 4, p-min 0, p-split 0.1
- Vision: enabled, projector resident on the CPU and not offloaded
- Reasoning default: off, with preserved reasoning controls and Jinja enabled

`server_decode_tps` is generated tokens divided by the decode interval reported by the server. `request_e2e_tps` is completion tokens divided by client wall time from request start through complete response receipt. Medians are ordinary medians, not best-run values. Decode-only and request end-to-end numbers are reported separately so HTTP, sampling, and synchronization overhead cannot be hidden.

## Result progression

| Stage | Commit or configuration | Server decode median | Request E2E median | Status |
| --- | --- | ---: | ---: | --- |
| Original baseline | No MTP, three seeds | 38.5420 | 37.9911 | Valid baseline |
| M002 | MTP depth 4, CPU vision projector | 63.8874 | 62.4162 | Valid five-seed result |
| B001 | MMQ routing plus Ampere Q4_K prefetch at `8720d0afa` | 84.0734 | 80.4864 | Promoted control |
| M022 | 40,192-token draft prefix, seed 303 | 91.7699 | 87.4786 | Correct but lower acceptance |
| M023 | 40,192-token prefix plus 31 mapped tail rows, seed 303 | 93.7119 | 89.2053 | Correct screen |
| M024 | 8,192-token prefix plus 111 mapped tail rows | 97.0403 | 92.2404 | Final qualified result |

The final five M024 launcher-default runs were:

| Seed | Server decode tokens/s | Request E2E tokens/s |
| ---: | ---: | ---: |
| 101 | 104.6827 | 99.0918 |
| 202 | 95.0658 | 90.4652 |
| 303 | 97.1750 | 92.4335 |
| 404 | 97.0403 | 92.2404 |
| 505 | 88.3125 | 84.2783 |
| Median | 97.0403 | 92.2404 |

A separate five-run qualification produced medians of 96.5793 server and 91.8191 end-to-end tokens/s. Reversing seed order produced 96.3983 and 91.6593. These repeats show that the result is not an artifact of favorable seed order. All five final outputs were byte-identical to the B001 outputs and reached the same 512-token limit.

## Optimizations retained

### 1. Enable the embedded MTP predictor

Commit `c3585a65c` changed the launcher to use Qwen3.8's embedded multi-token-prediction layer. The final MTP contract uses a maximum draft depth of four. The draft model proposes future tokens; the full target model verifies them in a batch. Accepted tokens amortize one target-model invocation over multiple emitted tokens.

This was the dominant first improvement. The original three-seed non-MTP median was 38.5420 server and 37.9911 end-to-end tokens/s. M002, with MTP depth four and the vision projector kept on the CPU to preserve VRAM, reached 63.8874 and 62.4162 over five seeds. M002's server results were 65.5019, 58.8014, 65.3879, 63.8874, and 55.1445 tokens/s for seeds 101 through 505.

Keeping the F16 projector on the CPU was a capacity decision rather than a decode-kernel speedup. It left enough device memory for the 147456-token Q8_0 KV cache, the target model, and MTP state. It also preserved image capability, although image prefill remained slow because projection ran on the CPU.

### 2. Route Ampere batches above four columns from MMVQ to MMQ

Commit `bc5148874` changes `ggml_cuda_should_use_mmvq()` only for compute capabilities from Ampere through pre-Ada. On these GPUs, `ne11 <= 4` continues to use MMVQ; matrices with more than four right-hand-side columns use MMQ. Other architectures keep their existing selection rules.

This targets the speculative verification shape. Single-token and very small draft operations are vector-like and suit MMVQ. Verifying several draft tokens makes the right-hand side wider, where MMQ's tiled matrix-matrix implementation uses the GPU more effectively. The restriction to Ampere avoids asserting the same crossover on architectures with different instruction throughput, cache behavior, or kernels.

This change was retained because the wider target verification batches materially improved the MTP workload and did not alter tensor math or sampling. Its effect is included in the progression from M002 to B001; an isolated five-seed result for this commit was not retained, so no unsupported per-commit delta is claimed here.

### 3. Prefetch the next Q4_K MMQ tile into Ampere L2

Commit `8720d0afa` adds an Ampere-only prefetch in `mul_mat_q_process_tile()`. After the current tile has been loaded and threads have synchronized, one thread per active output row calculates the address of the next K tile. For Q4_K only, it issues `prefetch.global.L2` for the row address and for the address 128 bytes later. The fallback path clamps the row index exactly as the ordinary load path does. The prefetch is skipped for the final tile.

The placement is important: the current tile's data is already available, and `vec_dot()` supplies useful computation during which the next tile can arrive in L2. Two 128-byte-spaced hints cover the useful Q4_K block region without changing shared-memory staging or synchronization. Compile-time architecture guards limit it to SM 80 through pre-SM 89, and `if constexpr` prevents it from affecting other quantization types.

Together with the routing change, this produced the B001 committed control at 84.0734 server and 80.4864 end-to-end tokens/s. The five server results were 88.5704, 81.1770, 84.0734, 84.2215, and 77.5907.

### 4. Compact only the MTP draft vocabulary

Commit `9fe315a6b` attacks the largest remaining measured overhead: the Q6_K vocabulary projection. The P003 profile attributed about 827 ms per request to that head. Approximately 619 ms came from repeated single-token draft projections and 208 ms from target-side J8 work. Reducing target vocabulary computation would change verification and sampling, so the optimization is deliberately restricted to `LLM_GRAPH_TYPE_DECODER_MTP`.

The final launcher sets `LLAMA_QWEN35_MTP_VOCAB=8192` and supplies `mtp-tail-token-map.txt`. At load time, the Qwen35 model:

1. Parses and deduplicates mapped token IDs.
2. Discards mapped IDs already covered by the prefix.
3. Allocates a small weights buffer on the same backend as the full output tensor.
4. Copies each selected quantized output row once into a compact tail tensor.
5. Stores the corresponding original vocabulary IDs in an I32 tensor.

When the MTP graph is built, the output head is viewed as only the first 8192 rows. A second matrix multiplication computes the 111 selected tail rows. The two compact result tensors are concatenated. A full-size F32 logits tensor is filled with negative infinity, then `ggml_set_rows()` scatters compact logits into their original vocabulary positions. The sampler therefore still receives a full-size distribution, but unmapped draft tokens have zero probability. The target graph, full target output head, and speculative correction remain unchanged.

The staged experiments explain the final design:

- M022 used only a 40,192-token prefix. Seed 303 rose to 91.7699 server tokens/s, but acceptance fell from 379 accepted out of 528 drafted tokens, 71.78 percent, to 373 out of 552, 67.57 percent.
- M023 added the 31 token IDs outside that prefix found in all five control outputs. Seed 303 improved to 93.7119 tokens/s and acceptance recovered to 378 out of 532, 71.05 percent.
- M024 reduced the dense prefix to 8192 and used 111 mapped tail IDs. The first seed-303 screen reached 96.7143 server and 91.8678 end-to-end tokens/s. A three-seed screen produced 104.5714, 94.5902, and 93.7685 server tokens/s. Full qualification and reverse-order repeats then confirmed the result.

This is workload specialization. Tokens not present in the prefix or map cannot be proposed by MTP, although the full target model can still generate them. Correctness is preserved by target verification, but acceptance and performance on a different workload can be worse. The environment variables keep the mechanism opt-in outside this launcher.

Final VRAM use was 23,798 MiB with 525 MiB free. A vision smoke test correctly identified the Statue of Liberty, generated 45 tokens, and stopped naturally. Its 48.06 tokens/s decode rate is not a headline result, and the 40.7-second image-processing phase reflects the deliberately CPU-resident projector.

## Profiling evidence

P002 established the full-path kernel mix. P003 captured node-level activity and exposed a substantial graph-management issue: 42,184 direct kernel launches, 500 CUDA graph launches, 128 graph executable updates, and 125 graph destroys. That evidence motivated K019, but caching recurring graph shapes did not yield a material throughput win.

P004 profiled the compact-head candidate. Over its captured warm-up and measured request, the largest groups were approximately:

- Q4_K J8 MMQ: 4.3370 seconds, about 42 percent of GPU kernel time.
- Q6_K J8 vocabulary work: 2.1117 seconds, about 20.4 percent.
- Quantized type-13 work: 493.7 ms.
- Gated DeltaNet kernels: 335.6 ms.
- Q6 single-column MMVQ after compaction: 233.2 ms.
- Concatenation: 186.5 ms.

The important result is not that the vocabulary head disappeared. Target verification still requires full-vocabulary logits. Compaction removed most repeated draft-side Q6 work while retaining full target correction.

## Experiments not retained

Early source candidates were built in isolated candidate directories and reverted after screening. Their exact temporary patches were not committed, so this report does not pretend to preserve line-level implementations that are no longer present. The experiment names, intended mechanisms, and raw measurements are retained. Unless noted otherwise, these were three-seed screens using seeds 101, 202, and 303 and the same request contract.

| ID | Intended mechanism | Server median | E2E median | Result |
| --- | --- | ---: | ---: | --- |
| E001 | Prefetch Q4_K and Q6_K quantized weights | 82.8842 | 79.3708 | Regressed; combined prefetch polluted cache or arrived at an unhelpful point |
| E002 | Use an L1-oriented prefetch for Q4_K | 84.6057 | 80.8894 | Small screen gain, below promotion confidence |
| E003 | Stage Q6_K data in the MMVQ path | 77.6678 | 74.6222 | Large regression; added staging/synchronization cost exceeded reuse |
| E004 | Put an n-gram proposer in front of MTP | No valid summary | No valid summary | Abandoned before a valid measured set |
| E005 | Use a four-token n-gram proposer before MTP | 84.7382 | 81.1118 | Small gain, insufficient and not promoted |
| E006 | Coalesce Q6_K MMVQ work at warp granularity | 83.3591 | 79.8290 | Regressed |
| E007 | Force a two-block occupancy target for Q4_K J8 | 84.2814 | 80.7471 | Neutral within run variance |
| E008 | Make MTP p-split depend on confidence | 84.4085 | 80.8689 | Small, unconvincing gain; changed proposal policy without enough payoff |
| E009 | Prefetch Q4_K two K tiles ahead | 84.3896 | 80.8426 | Neutral; farther look-ahead did not beat the retained one-tile prefetch |
| E010 | Set `CUDA_DEVICE_MAX_CONNECTIONS=1` | 84.1787 | 80.6177 | Neutral/slightly worse; serialization did not help this graph mix |
| E011 | Force cuBLAS as a routing diagnostic | 84.5255 | 80.9709 | Diagnostic was near control; no broad cuBLAS promotion |
| E012 | Couple MTP proposal and target sampling | 83.3825 | 79.8832 | Regressed and increased seed sensitivity |
| D013 | Raise the MTP maximum depth to six as a ceiling diagnostic | 85.3548 | 81.7024 | Interesting but highly seed-dependent; not promoted under fixed depth-four contract |
| E014 | Add L2 prefetch to Q6_K J8 | 84.2251 | 80.7054 | Neutral/slightly worse |
| E015 | Defer MTP prefix catch-up work | 84.3561 | 80.8384 | Neutral; deferred bookkeeping did not remove the critical cost |
| E016 | Reuse MTP draft KV state more aggressively | 71.3624 | 68.8555 | Severe regression, indicating costly or unfavorable state handling |
| E017 | GPU greedy sampling with a zero-copy path | 22.1888 | 21.9615 | Catastrophic regression; the path imposed much more overhead than it removed |
| E018 | Stock binary with maximum GPU core clock lock | 84.1416 | 80.5660 | No material gain; clocks were not the main limit |

The individual early server results, which expose seed variance hidden by medians, were:

- E001: 87.4016, 79.9092, 82.8842.
- E002: 89.7760, 81.9142, 84.6057.
- E003: 80.8012, 74.2076, 77.6678.
- E005: 89.7153, 81.9498, 84.7382.
- E006: 88.0250, 80.3960, 83.3591.
- E007: 89.4106, 81.7126, 84.2814.
- E008: 89.1570, 81.4203, 84.4085.
- E009: 89.5297, 81.7775, 84.3896.
- E010: 89.8465, 81.9386, 84.1787.
- E011: 89.3548, 81.5490, 84.5255.
- E012: 91.6887, 83.3825, 79.1809.
- D013: 102.8852, 84.7981, 85.3548.
- E014: 89.6720, 81.7566, 84.2251.
- E015: 89.9929, 81.7322, 84.3561.
- E016: 67.6707, 71.9814, 71.3624.
- E017: 22.1888, 22.0815, 22.2536.
- E018: 89.1883, 81.3401, 84.1416.

### CUDA graph and kernel follow-ups

- K019 made the CUDA graph cache key sensitive to operations, tensor dimensions, and strides so recurring target and draft shapes could retain separate graph executables. Seed 303 reached 84.7325 server and 81.0753 end-to-end tokens/s, less than a 1 tokens/s improvement. It failed the one-seed material-gain gate and was reverted.
- D020 enabled the existing `GGML_CUDA_GRAPH_OPT=1` Q/K/V branch-concurrency path. Seed 303 fell to 83.8391 and 80.2710. It was rejected.
- K021 lowered the direct-tiling threshold from 90 to 50 percent for non-fallback Q4_K J8. The intent was to remove stream-K fixup launches; P003 had shown 35,090 Q4_K J8 stream-K launches on an 82-block grid and an equal number of fixups, versus 3,135 direct 80-block launches. Seed 303 fell to 78.8639 and 75.6809. Stream-K load balance was more valuable than eliminating fixup traffic.

### Compact-vocabulary boundary experiments

- M025 first tried a 4096-token dense prefix without all IDs from 4096 through 8191 represented in the map. Seed 303 fell to 92.1838 server and 87.9065 end-to-end tokens/s. After repairing the map to preserve the same supported token set as M024, it reached 97.3904 and 92.5107. This was effectively neutral, so the simpler 8192 prefix remained.
- M030 traced the pre-sampling top-20 candidate sets over warm-up seed 7 and the five measured seeds. Their union contained only 38 token IDs. This was a diagnostic to test a theoretical lower bound, not sufficient evidence that those were the only tokens required at every future draft step.
- M031 retained only those 38 mapped target-head rows. Seed 303 reported 120.7998 server and 115.4616 end-to-end tokens/s, but warm-up seed 7 generated only four tokens and selected EOS. This changed the sampling distribution and output, so the number is invalid.
- M032 combined an 8192-token target prefix with traced tail IDs. Seed 303 reached 103.7321 and 99.8191, but its output differed from the control, 1793 versus 1849 characters. Warm-up again stopped after four tokens, with zero accepted out of 12 drafted tokens. This is also invalid.

The M031 and M032 results establish why compacting the target head is not an acceptable route to 100 tokens/s. A traced candidate union is workload history, not a proof that omitted target logits are irrelevant. The retained M024 code compacts only the proposal head and leaves target sampling exact.

### Final kernel, scheduling, and hardware screens

- M026 added a second Q4_K K-tile prefetch. Seed 303 regressed to 85.1754 server and 81.4079 end-to-end tokens/s. The extra look-ahead likely displaced more useful data from L2 and was reverted.
- M027 added an immediate Q6_K L2 prefetch. Seed 303 reached 94.3180 and 89.7676, below M024, and was reverted.
- M028 locked the GPU core at 1800 MHz. Seed 303 reached 96.9367 and 92.0941, effectively neutral.
- M029 locked the core at 1950 MHz. Seed 303 reached 97.4190 and 92.5645, also within noise. Observed power was about 146 W and temperature 63 C after the run, so sustained power or thermal throttling was not the limiting factor.
- M033 selected a Q6_K J16 kernel for target batches of five through eight columns. Seed 303 reached 96.0769 and 91.2785, a regression.
- M034 disabled stream-K for Q6_K J8. The measured seed fell to 84.8934 and 81.0176 despite a fast warm-up. The shape-dependent instability made the candidate clearly worse.
- M035 raised the server process to Windows High priority. Seed 303 reached 97.2923 and 92.4322, no meaningful improvement.
- M036 selectively routed large Q6 output-head matrices with five through eight columns to cuBLAS. The server failed on the first request with a CUDA error and closed the connection, consistent with insufficient memory for the dequantization/workspace path at the existing 23.8 GiB footprint. It produced no valid throughput result.

After these screens, source and binary were restored to M024. A final seed-303 check produced 96.3929 server and 91.6255 end-to-end tokens/s, with byte-identical output. GPU application clocks were reset, the server was stopped, and the working tree was clean.

## Why 100 tokens/s was not claimed

One final five-seed run did exceed 100 tokens/s for seed 101, but the ordinary median was 97.0403. The remaining profile is dominated by real target-model Q4_K J8 work and the full Q6_K target vocabulary head. Attempts to alter tiling, add more prefetching, change stream-K selection, force cuBLAS, lock clocks, or raise process priority did not provide a repeatable three tokens/s gain. Removing most target vocabulary rows crossed 100 tokens/s but violated output equivalence.

The technically honest stopping point is therefore 97.0403 server decode tokens/s and 92.2404 request end-to-end tokens/s for the fixed five-seed workload. A future attempt should preserve full target logits and focus on the measured Q4_K J8 and Q6_K J8 kernels, or use a provably exact target-vocabulary pruning method rather than a trace-derived token list.

## Reproducibility and retained artifacts

The reproducible source state is commit `9fe315a6b` plus this report commit. The meaningful retained implementation commits are:

- `c3585a65c`: enable Qwen3.8 MTP in the launcher.
- `bc5148874`: use MMQ for Ampere batches above four columns.
- `8720d0afa`: prefetch the next Q4_K MMQ tile into Ampere L2.
- `9fe315a6b`: compact the MTP draft vocabulary with mapped tail rows.

Tracked baseline evidence is under `qwen3.8-27b/baseline-20260814-100334-measured` and `qwen3.8-27b/M002-mtp4-cpummproj-five`. The larger experimental archive is under the locally ignored `benchmarks/qwen38-plus10b` directory. It contains raw responses, identity manifests, summaries, server logs, qualification/reverse-order runners, profiler reports, candidate build logs, final-push screens, and the restore validation. Because that archive is intentionally ignored and contains very large profiler databases and build logs, it is supporting local evidence rather than part of the reproducible Git commit.
