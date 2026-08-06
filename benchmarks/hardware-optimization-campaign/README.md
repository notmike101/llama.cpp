# Qwen3.6 MTP real-use campaign

## 2026-08-06 ngram-mod priming promotion

The promoted profile combines the qualified Q8_0 six-column row-warp and
IQ4_XS four-row CUDA paths with `draft-mtp,ngram-mod`. The ngram-mod cache
learns one request before drafting, using lookup length 7 and draft range 1-5.
This avoids cold self-drafting while leaving the default ngram-mod behavior
unchanged unless `--spec-ngram-mod-n-prime` is set.

The matched five-seed stream medians were 332.049 server and 302.768 client
TPS cold, versus 288.271 and 265.648 for control. Representative warm medians
were 335.034 and 313.285, versus 283.083 and 262.707. Cold and warm nonstream,
unique and repeated prompts, 13,597- and 135,097-token occupied contexts, and
128- and 512-token caps all exceeded their matched control by at least 15 TPS
for both server decode and client-visible throughput. The near-max client
median was 140.000 versus 121.981 TPS.

All matched outputs were byte-identical. Thirty 512-token candidate programs
compiled with MSVC C++20 `/W4 /WX`, ran, and printed `All tests passed.` The
parser-normal no-tools and parser-bypass unused-tool cells returned exact
`Hello` and stopped naturally for all seeds. Native structured tool formatting
remains the existing unsupported model path. Raw non-MTP and llama-bench
diagnostics stayed flat, confirming that the gain comes from request-level
speculative reuse rather than raw decode.

## 2026-08-05 new +15 tok/s campaign

Authoritative metric: sampled single-user generation speed. For non-streaming
cells this is server decode TPS plus request end-to-end TPS; for streaming
cells it is server decode TPS plus client stream-total TPS and TTFT. Success
requires an ordinary five-seed median at least 15 tok/s above a fresh matched
control in every required served-request cell, not only in a decode diagnostic.

Fixed workload: `/v1/chat/completions`, exact
`Qwen3.6-35B-A3B-UD-Q3_K_M.gguf` with its integrated Q4_0 NextN tensors,
CUDA0 full offload, context 150000, one slot and one request, batch 2048,
microbatch 512, F16 target and draft KV, FlashAttention, no mmap, backend
sampling, reasoning off, temperature 0.6, top-k 20, top-p 0.95, min-p 0.0,
rotating seeds 101/202/303/404/505, and the existing warning-clean C++20
compile/run quality gate. The production profile starts at MTP depth 5,
p-min 0.16, p-split 0.10, eight target/draft threads, the 40,192-token draft
head, ranked-1,575 target map, normal parser path, and 512 output tokens.

Required promotion matrix: short unique and exact-repeat prompts in both
streaming and non-streaming modes; medium and 135,097-token occupied contexts;
128- and 512-token caps; parser-normal and parser-bypass exact-output cells;
no-tools and unused-tool payloads (with the existing native structured-tool
limitation recorded separately); natural stop; raw non-MTP fallback;
`llama-bench` prompt/decode diagnostics; quality, identity, MTP acceptance,
memory, process cleanup, and cold/warm checks. Prompt cache state and effective
request settings must be recorded, and all finalist cells use five qualifying
seeds. The current Windows session is RDP, so the fresh RDP control is the
campaign baseline unless an independently authorized console run is performed.

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

Target: median sampled generation speed >= 220 tok/s across five rotating seeds.

Fixed contract: Qwen3.6-35B-A3B MTP UD-Q3_K_M, CUDA, context 150000, one request, 512 output limit, reasoning off, temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, batch 2048, microbatch 512, F16 KV, MTP depth 5, backend sampling.

Host: Windows 11 Pro, Intel i9-10900KF (10C/20T), RTX 3090 24 GiB, driver 610.62. Repository commit 40b740ad05c531b9d57aca6698c3ed553a9e784c.

Promoted winner: engines/b10079-mtp-215tps. Five measured seeds: 220.58, 216.49, 212.80, 186.20, and 220.12 tok/s. Median 216.49 tok/s. Peak 73 C, 271 W, and 20,783 MiB VRAM. All five generated C++20 programs compiled with MSVC `/W4 /WX`, executed successfully, and passed their assertions.

Improvement over the original official B001 median of 171.54 tok/s: +44.95 tok/s (+26.20%). Improvement over the prior 200.19 tok/s qualification: +16.30 tok/s (+8.14%).

Retained stack: synchronized-hidden-state removal, Q8_1 quantization at 128 threads, direct CUDA SSM convolution state with MTP rollback snapshots, quantized beta-projection sigmoid fusion, persistent alias-safe Q8_1 activation reuse, direct runtime-index GDN state gathering, three/one warps for the Q6_K one/five-column shapes, four warps for Q8_0 five-column verification, one fused MoE row per block for IQ3_S gate/up projections, a dual IQ3_S dot product that reuses Q8 activations, four MoE rows per block for unfused IQ3_XXS, eight for IQ4_XS, and exact CUB 64x4 router sorting.

Artifacts: ../Q006-iq3-dual-rpb1-five.stderr.log and Q006-iq3-dual-rpb1-five-response-1.json through Q006-iq3-dual-rpb1-five-response-6.json. The launcher is ../../Qwen3.6-35B-A3B-MTP-GGUF/run-qwen.bat.

## 2026-08-01 current stable control

The current production launcher was measured again before tuning. Unlocked
five-seed medians were 188.51 and 197.41 tok/s, confirming material boost and
power drift. With reversible stock-limit clock locks at 1800 MHz core and 9751
MHz memory, the fixed five-seed streamed end-to-end median was 195.91 tok/s
(197.95, 185.71, 195.91, 197.95, 194.02). Server decode median was 212.29
tok/s and TTFT median was 130.62 ms. All five generated programs compiled with
MSVC C++20 `/W4 /WX`, executed, and passed. The paired +5 target is therefore
200.91 tok/s under locked comparison conditions, followed by unlocked
production validation.

No configuration candidate qualified. `--no-host` reached 196.11, p-min 0.25
reached 184.16, microbatch 256 reached 196.96 on three seeds, microbatch 1024
reached 191.89, CUDA graph optimization reached 190.69, p-split 0 reached
195.83 on five seeds, draft n-min 1/2 reached 193.63/188.76, and a 1950 MHz
clock lock reached 191.54 on five seeds. The mixed current-source engine and
the later K718 engine also regressed. Independent MTP plus ngram-mod reached
155.27 and changed trajectories, matching upstream reports that the two
strategies are not pipelined.

Trace inspection corrected the apparent sorting opportunity: the 1.6%
`k_argsort` kernel sorts the 256-expert MoE router, while actual vocabulary
top-k totals only about 0.3%. A follow-up SM86 launch-bounds experiment on the
dominant Q8_0 five-column kernel forced higher occupancy but regressed from an
adjacent 195.41 tok/s control to 191.78 tok/s. It was removed. GPU and memory
clock locks were reset and no server remains.

Further locked-clock screens also rejected Q8_0 warp-first reduction (186.40
tok/s), draft p-min 0.19/0.21 (193.28/197.18), `--no-host` plus p-min 0.21
(193.67), and 5% polling (192.62). Shortening the recurrent prompt checkpoint
tail from four tokens to one did not reduce its 52-61 ms fixed processing cost,
changed sampled trajectories, and reached 192.53 tok/s, so it was restored.

## 2026-08-02 device-checkpoint qualification

The promoted profile keeps one metadata-guarded recurrent checkpoint shadow on
device for the single-slot server, skips the exact duplicate save after restore,
uses `--no-host`, and locks the RTX 3090 at the stock-supported 1905 MHz core and
9751 MHz memory clocks. Three complete five-seed streamed batches measured
208.95, 198.50, and 199.04 tok/s medians. The ordinary median over all 15 raw
runs was 202.15 tok/s, +6.23 tok/s over B070's exact 195.912 tok/s baseline.

All fixed-seed programs were byte-identical across repeats and passed MSVC
C++20 `/W4 /WX` compile and runtime checks. Draft acceptance remained
81.742%-86.643%. Warm/cold, streamed/non-streamed, 13,597-token, and
135,097-token validations passed, with VRAM returning exactly to baseline.
The launcher enables the device shadow only for its one-slot profile and resets
the reversible clock locks when the server exits.

## 2026-08-02 zero draft cutoff qualification

The promoted depth-five profile was re-established from three new five-seed
batches before screening further changes. Removing the MTP draft probability
cutoff increased the ordinary median from 210.51 to 217.25 tok/s across the
same 15 streamed generation measurements, a 6.74 tok/s gain. The three
candidate batch medians were 223.51, 216.76, and 217.25 tok/s.

Each fixed-seed output was byte-identical across candidate repeats and passed
MSVC C++20 `/W4 /WX` compilation and execution. Warm non-streamed, cold
streamed, 13,597-token warm streamed, and 135,097-token cold non-streamed
requests also passed. Validation draft acceptance was 67.0%-78.9%, and every
run returned VRAM to its pre-run value. The launcher now defaults the MTP
draft probability cutoff to zero while retaining caller override support.

## 2026-08-02 depth-five qualification

A fresh run of the promoted depth-four profile measured 204.01 tok/s streamed
end-to-end. Increasing MTP depth to five and using a 1935 MHz core lock measured
three five-seed batches at 209.45, 210.64, and 207.23 tok/s. The ordinary median
of all 15 raw runs was 208.36 tok/s, +6.22 tok/s over the previously qualified
202.15 tok/s result. A 1950 MHz lock and a 1980 MHz lock did not improve the
result, and process priority and CPU affinity candidates were rejected.

Every fixed-seed output was byte-identical across the three repeats and passed
MSVC C++20 `/W4 /WX` compilation and execution. Warm non-streamed, cold
streamed, 13,597-token warm streamed, and 135,097-token cold non-streamed runs
also compiled and passed. MTP remained active with 71.0%-78.9% acceptance in
the validation matrix, and VRAM returned exactly to 490 MiB after every run.

## 2026-08-03 MoE draft-vocabulary qualification

The A3B MTP graph now limits its draft LM-head projection to the first 65,536
tokens and scatters those logits into the unchanged 248,320-token output. The
target model continues to verify the full vocabulary. Three five-seed streamed
batches measured 238.354, 236.269, and 236.196 tok/s generation-only. The
ordinary 15-run median was 236.269 tok/s, with a 223.156 tok/s stream-total
median and 95.538 ms TTFT median. This is +17.346 tok/s over the fresh 218.923
tok/s generation baseline and +17.500 tok/s over its 205.656 stream-total
baseline.

All 15 fixed-seed answers matched the control hashes and passed MSVC C++20
`/W4 /WX` compilation and execution. Warm non-streamed, cold streamed,
13,597-token warm streamed, and 135,097-token cold non-streamed validation also
passed. Nsight Systems measured the sequential Q6_K draft projection falling
from about 67 ms to 17 ms per 128-token trace. VRAM and clocks returned to the
631 MiB, 1695/9751 MHz idle state after validation.

## 2026-08-03 target fast-sampling qualification

Three fresh five-seed controls re-established the MoE vocabulary winner at an
ordinary 235.369 tok/s generation-only median, 235.326 tok/s server decode,
221.895 tok/s stream total, and 96.713 ms TTFT. This established a 9.631 tok/s
gap to the new 245 tok/s target without relying on historical results.

The qualified sampler first finds the exact top 20 candidates with an AVX2
heap scan, then applies the unchanged top-k, top-p, min-p, temperature, and
distribution sampler chain. It activates only for the fixed neutral-penalty
sampling contract. Three candidate batches measured 254.057, 254.955, and
259.620 tok/s. The ordinary all-15 median was 254.955 tok/s generation-only,
255.030 tok/s server decode, 237.425 tok/s stream total, and 94.788 ms TTFT.

A clean reconstruction removed the rejected no-sync infrastructure and added a
portable scalar fallback for non-AVX2 builds. Its three final five-seed batches
measured 247.726, 248.519, and 247.383 tok/s. The final binary's ordinary
all-15 median was 247.726 tok/s generation-only, 247.758 tok/s server decode,
231.862 tok/s stream total, and 95.825 ms TTFT.

All 15 outputs matched the control hashes and passed MSVC C++20 `/W4 /WX`
compilation and execution. The four-cell warm/cold and long-context matrix also
compiled and passed. The 135,097-token cold request decoded at 164.965 tok/s.
The independent entry-sync removal was rejected, as were a 32,768-token prefix,
depth six, the official external Q4_0 drafter, and Q8_0 six-column MMQ routing.

## 2026-08-03 MSVC AVX2 and 40,960-token draft qualification

A fresh five-seed run reproduced the committed fast-sampling winner at 248.552
tok/s generation-only, 248.629 tok/s server decode, 232.188 tok/s stream total,
and 94.996 ms TTFT. The final MSVC build had been taking the scalar fallback
because this toolchain does not define the GCC-style AVX2 feature macro. A
runtime CPUID/XGETBV gate restored the AVX2 scan without removing the scalar
fallback on unsupported hosts.

The draft-only LM-head prefix was then reduced from 65,536 to 40,960 tokens.
The target verifier and sampler retain the full 248,320-token vocabulary. Three
five-seed batches measured 267.939, 262.756, and 262.243 tok/s. The ordinary
all-15 median was 262.756 tok/s generation-only, 262.819 tok/s server decode,
247.447 tok/s stream total, and 94.575 ms TTFT. This is +15.029 tok/s over the
previous 247.726 tok/s qualification.

All 15 answers matched the control hashes and passed MSVC C++20 `/W4 /WX`
compilation and execution. Warm non-streamed, cold streamed, 13,597-token warm
streamed, and 135,097-token cold non-streamed validation also matched control
hashes and passed. The near-maximum request decoded at 164.778 tok/s after
76,966 ms prompt processing. VRAM returned to its pre-run value after every
run.

## 2026-08-04 new +15 tok/s campaign

Fresh exact-production baseline B1003 used `k424-context-skip5` with context
skipping disabled, the 11,816-token target map, 40,960-token MTP head, depth
five, production sampling, 150,000 context, backend sampling, and the qualified
2190/9751 MHz launcher hardware profile. Five raw generation-only results were
242.843, 281.260, 275.081, 258.429, and 249.816 tok/s. The ordinary median is
258.429 tok/s; server decode is 258.387, stream total is 244.671, and TTFT is
88.627 ms. The fixed target is therefore 273.429 tok/s generation-only.

P1002 attributed 23.0% of CUDA kernel time to Q8_0 six-column verification,
14.8% to fused IQ3_S MoE, and 10.7% to IQ4_XS MoE. CUDA API time was dominated
by `cudaStreamSynchronize` at 63.3%. K511's exact Q8_0 six-column package was
the best kernel candidate. Combined with a frequency-ranked 1,800-token target
map and a 40,192-token draft head, K1016 first reached 273.766 tok/s, but the
reverse and third five-seed batches reached only 271.369 and 269.584. The
ordinary all-15 median does not meet the target, so this stack is not promoted.

Raw ID-truncated 1,200/1,600-token target maps exceeded 288 tok/s but every
response hit the 512-token cap and they were rejected. A 2,376-token map
stopped naturally and reached 265.709; adding a 40,192-token draft head reached
271.187 once. Frequency-ranked maps preserved natural stopping but 1,600 and
1,700-token variants remained below target. K516b IQ4 and K637/K718 CUDA
transplants also regressed. No launcher has been changed. The next theory is
an exact Q8_0 six-column or fused IQ3_S kernel improvement on the K511 host.

## 2026-08-04 K514 promotion

K514 combines the qualified Q8 J6 single-worker kernel with in-place source
reuse. With the frequency-ranked 1,800-token target map and a 40,192-token MTP
head, forward and reverse five-seed medians were 274.246 and 275.906 tok/s. The
combined 10-run median was 275.385 tok/s, 16.956 tok/s above B1003.

All 10 generated C++ programs compiled with MSVC C++20 `/W4 /WX` and passed
their assertions. K1029-K1039 cover cold and warm starts, streaming and
non-streaming requests, 13,597- and 135,097-token occupied contexts, 128- and
512-token limits, exact-output isolation, parser-disabled mode, raw non-MTP
decoding, and llama-bench diagnostics. Structured tool calls remain unsupported
for this model path: the unused-tool request returned HTTP 500 for a native
format mismatch, while plain chat passed.

## 2026-08-04 285 tok/s console promotion

K1097 adds an exact-output 128-byte L2 prefetch hint to the fused IQ3_S CUDA
kernel. On the physical console, the promoted launcher uses eight threads,
draft p-min 0.16, p-split 0.10, the ranked-1,575 target map, and a 40,192-token
MTP head. Three retained five-seed launcher batches produced an ordinary
all-15 generation median of 292.347 tok/s. The sampled quality gate passed
15/15, and the established cold/warm, long-context, instruction-isolation,
short-MTP, and raw fallback matrix completed without resident VRAM leakage.
