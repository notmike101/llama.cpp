# Theories

## K001 - redundant MTP embedding synchronization

The MTP draft sampler already synchronizes the draft context before reading backend sampling results. Reusing the synchronized hidden-state row avoids a second stream synchronization. Combined with an SM86-native CUDA 13 build, the five-seed median improved from 171.54 to 183.43 tok/s. Retained and promoted.

## M001 - raise speculative p-min

Hypothesis: draft continuations just above probability 0.25 are rejected often enough that their draft and target verification cost exceeds accepted-token benefit. Raising p-min should reduce rejected tail work and improve end-to-end sampled TPS without changing target sampling parameters. Compare three seeds first, then five if promising. Reject if output quality, stability, memory, or median regresses.

Result: rejected. At p-min 0.35 the measured runs were 156.52, 183.47, and 172.31 tok/s (median 172.31). Generation trajectories and output lengths changed, and throughput regressed.

## K002 - MSVC whole-program optimization

Hypothesis: the MTP loop is dominated by many small host calls, sampler accessors, and CUDA dispatch/synchronization boundaries. Enabling MSVC interprocedural optimization and LTCG should reduce host overhead without changing graph arithmetic or sampling semantics. Build in a separate directory and compare against K001.

Result: rejected. Static LTCG measured 180.12, 169.13, and 167.70 tok/s (median 169.13).

## R001 - CPU-side MTP draft sampling

Hypothesis: backend draft sampling adds GPU graph work, output buffers, and synchronization for a tiny top-k selection. CPU-side draft sampling may be faster on RTX 3090 while preserving the same greedy draft candidate and target distribution. Motivated by upstream issue 23903, which identifies the backend-sampling transition as a likely source of added MTP compute-buffer cost.

Result: rejected. CPU-side draft sampling measured 187.01, 170.76, and 167.91 tok/s (median 170.76). Acceptance counts were identical, but throughput regressed.

## M002 - MTP depth 3

Hypothesis: the fourth drafted position has insufficient marginal acceptance to repay its draft and target verification cost. Reducing n-max from 4 to 3 may improve end-to-end throughput while preserving target sampling parameters.

Result: rejected. Depth 3 measured 165.35, 168.69, and 168.06 tok/s (median 168.06) and changed generation trajectories. The fourth draft position is profitable.

## P001 - Nsight CUDA critical path

Capture the promoted depth-4/backend-sampling path and rank CUDA kernels, API synchronization, graph launches, and host gaps. Use the result to select the next code or kernel change.

Result: the Q6_K single-column MMVQ kernel is the largest GPU kernel family at 22.7% of kernel time, with 156 calls averaging about 0.55 ms. CUDA API time is dominated by stream synchronization waiting on dependent GPU work.

## K003 - two-warp Q6_K MMVQ on SM86

Hypothesis: Ampere currently uses the generic four-warp launch for single-column Q6_K MMVQ, while the tuned Turing table uses two warps for the same quant shape. Reducing only Q6_K ncols=1 to two warps may improve occupancy/register balance and the dominant projection kernel without changing arithmetic.

Result: rejected. Two warps measured 176.78, 176.99, and 169.26 tok/s (median 176.78), slower than the promoted control.

## K004 - eight-warp Q6_K MMVQ on SM86

Hypothesis: since reducing parallelism regressed, increasing the dominant single-column Q6_K launch from four to eight warps may better saturate Ampere memory bandwidth.

Result: rejected. Eight warps measured 173.63, 170.39, and 165.93 tok/s (median 170.39). The original four-warp launch is locally optimal among adjacent widths.

## P002 - Nsight Compute Q6_K MMVQ

Measure memory throughput, occupancy, instruction mix, and stalls for the dominant original four-warp Q6_K single-column MMVQ kernel before changing its internal work distribution.

Result: blocked by Windows ERR_NVGPUCTRPERM. Nsight Compute connected, but administrator-enabled GPU performance counters are required. The unprivileged Nsight Systems evidence remains valid.

## K005 - 65K FastMTP vocabulary view

Hypothesis: the MTP draft head need not score the entire 151K vocabulary for this coding workload. Restricting only the draft head to the first 65,536 token rows cuts the dominant Q6_K output projection by about 57%, while target verification and target sampling remain full-vocabulary. Promote only if all seed outputs and acceptance counters remain exact.

Result: rejected. The measured runs were 180.80, 172.56, and 168.86 tok/s (median 172.56). Output lengths and acceptance counters were unchanged, but the vocabulary view did not improve throughput. This suggests the initial graph-level trace did not represent replay frequency accurately or this projection is not the limiting repeated work.

## P003 - CUDA graph node trace

Capture CUDA graph nodes rather than only graph launches so kernels executed through graph replay are included in the critical-path ranking. Use the corrected kernel mix to choose the next narrow optimization.

Result: target verification is dominant. Q8_0 five-column MMVQ accounts for 16.0% of GPU kernel time and five-column float matrix-vector work accounts for another 7.2%. Q6_K single-column projection accounts for 13.5%. This corrected replay-aware ranking explains the K005 rejection.

## K006 - four-warp Q8_0 five-column MMVQ

Hypothesis: increasing the dominant Q8_0 five-column kernel from two to four warps may improve Ampere occupancy and latency.

Result: rejected. The measured runs were 181.00, 177.13, and 188.46 tok/s (median 181.00). Peak was 71 C and 248 W.

## K007 - one-warp Q8_0 five-column MMVQ

Hypothesis: the five independent columns already expose sufficient parallelism, so reducing from two warps to one may improve block occupancy and memory scheduling on SM86.

Result: rejected. The measured runs were 164.76, 181.77, and 170.67 tok/s (median 170.67). Peak was 68 C and 242 W. The original two-warp launch is locally optimal.

## R002 - aggressive polling and high worker priority

Hypothesis: polling at 100 and high worker priority may reduce host dispatch gaps around CUDA graph launches and stream synchronization.

Result: rejected. The measured runs were 175.39, 166.52, and 167.11 tok/s (median 167.11). Peak was 69 C and 248 W.

## K008 - one row per block for Q8_0 five-column MMVQ

Hypothesis: the current two-row block assignment may constrain block-level parallelism for the dominant five-column Q8_0 matrices. Keeping two warps but assigning one output row per block may expose more blocks to the 82 SMs.

Result: rejected. The measured runs were 172.56, 167.87, and 167.73 tok/s (median 167.87). Acceptance counters were unchanged. Peak was 69 C and 258 W.

## K009 - four rows per block for Q8_0 five-column MMVQ

Hypothesis: processing four output rows per block may amortize Q8_0 weight access and launch scheduling across additional outputs while retaining the original two-warp width.

Result: rejected. The measured runs were 170.00, 169.52, and 170.44 tok/s (median 170.00). Acceptance counters were unchanged. Peak was 68 C and 246 W. The original two-row assignment is locally optimal.

## K010 - route Q8_0 five-column matrices through MMQ

Hypothesis: Ampere tensor-core MMQ may outperform MMVQ for the dominant five-column Q8_0 target-verification matrices. Bypass MMVQ only for this exact type and width, allowing the existing MMQ selector to choose the next backend.

Result: rejected. The measured runs were 148.92, 160.61, and 161.28 tok/s (median 160.61). Peak was 69 C and 238 W. MMVQ is decisively faster for this shape.

## R003 - CUDA graph optimizer

Hypothesis: the existing opt-in multi-stream graph optimizer may overlap independent MoE work and reduce dispatch gaps.

Result: rejected. The measured runs were 172.49, 166.13, and 163.91 tok/s (median 166.13). Peak was 69 C and 248 W. Concurrent bandwidth-heavy work regressed on this RTX 3090 workload.

## K011 - 128-thread Q8_1 activation quantization

Hypothesis: the 64,798 replayed Q8_1 quantization launches are only 4.0% of GPU time individually but are dispatch-heavy. Reducing the CUDA workgroup from 256 to 128 threads may improve block scheduling for the model's narrow activation rows.

Result: rejected. The measured runs were 172.28, 167.74, and 168.44 tok/s (median 168.44). Acceptance counters were unchanged. Peak was 69 C and 248 W.

## K012 - 64-thread Q8_1 activation quantization

Hypothesis: a 64-thread workgroup may further improve scheduling and matches the narrow winner reported on the AMD campaign, though the CUDA result must be independently measured.

Result: provisional. The measured runs were 175.71, 176.54, and 170.34 tok/s (median 175.71), versus a contemporary promoted control of 176.92, 174.08, and 167.81 (median 174.08). Acceptance counters were exact. The +0.94% median is too small to promote alone but may compose with a larger kernel win.

## K013 - IQ3_XXS VDR4

Hypothesis: the replay-aware trace shows two-token IQ3_XXS routed-expert MMVQ consumes 12.0% of GPU time. Increasing its vector dot ratio from two to four may reduce loop overhead for these expert projections, following the shape-specific VDR lesson from the AMD campaign. Test sampled MTP and reject immediately if arithmetic changes acceptance or throughput regresses.

Result: invalid and rejected. All responses stopped after two generated tokens and draft acceptance was 0/4. The IQ3_XXS vector-dot implementation is not valid at VDR4 without a deeper rewrite.

## K014 - one row per block for two-token IQ3_XXS experts

Hypothesis: retain the valid VDR2 arithmetic but increase block-level parallelism for the 12.0% two-token IQ3_XXS MoE hotspot by assigning one expert output row per block instead of two. Other quant types and non-MoE kernels remain unchanged.

Result: rejected. The measured runs were 174.74, 169.36, and 164.39 tok/s (median 169.36). Acceptance counters were exact. Peak was 72 C and 253 W.

## G001 - direct single-row recurrent state

Hypothesis: when a recurrent context has exactly one state row, one sequence, head zero, no rollback snapshot rows, and no pending zero-fill, GET_ROWS is provably an identity and can be replaced by a view. This should remove redundant gathers in the MTP draft context while leaving the target context's rollback-capable state path unchanged.

Result: rejected. The measured runs were 170.48, 170.44, and 165.00 tok/s (median 170.44). Acceptance counters were exact, but the guarded path did not improve throughput and likely was not active for this MTP graph shape.

## K015 - eight-warp CUDA gated-delta-net

Hypothesis: GDN accounts for 3.3% of replayed GPU time. Increasing its column parallelism from four to eight warps may reduce recurrent-kernel latency, matching the focused AMD result while independently validating the CUDA scheduler.

Result: rejected. After correcting the compile-time launch bound, the measured runs were 173.53, 174.01, and 169.76 tok/s (median 173.53). Acceptance counters were exact. Peak was 72 C and 255 W. Four warps remains faster on SM86.

## R004 - microbatch 2048

Hypothesis: a larger microbatch may improve MTP verification scheduling as reported in the AMD production sweep while preserving target sampling.

Result: rejected. The measured runs were 171.99, 172.48, and 176.76 tok/s (median 172.48), generation trajectories changed, and VRAM rose to 21,992 MiB. It remained within memory limits but did not improve throughput.

## K016 - adjacent CUDA Q8_1 source reuse

Hypothesis: immediately adjacent quantized matrix consumers of the exact same F32 source can share one Q8_1 activation conversion. Reuse is scoped to one CUDA graph and stream, and any intervening compute node invalidates the entry. This ports only the narrow first stage of the supplied AMD strategy.

Result: rejected as a standalone end-to-end optimization. The corrected LIFO-safe implementation measured 181.15, 170.46, and 173.09 tok/s (median 173.09) with exact acceptance. P004 confirmed the mechanism removed 14,917 of 64,798 Q8_1 quantization launches (23.0%) and reduced replayed quantization kernel time from 100.706 ms to 79.871 ms, but this saved only about 0.8% of total GPU kernel time and did not improve the sampled median over K012. Retain the implementation only as an opt-in composition candidate.

## K017 - explicit Q8_0 weight reuse across five MTP columns

Hypothesis: Q8_0 five-column MMVQ consumes 16.7% of replayed GPU time. Loading each Q8_0 fragment once and applying it to all five Q8_1 activation columns should reduce redundant global loads while preserving the original DP4A order exactly.

Result: rejected. The measured runs were 180.89, 172.23, and 168.71 tok/s (median 172.23), versus K016b's 173.09 median on the same stack. Output and acceptance remained exact. The explicit source form did not improve the generated SM86 kernel, indicating NVCC already hoists or caches these weight reads effectively, or the added register lifetime offsets any load reduction. The source change was removed.

## K018 - direct CUDA SSM convolution state

Hypothesis: consume the selected recurrent cache state and new token rows separately, compute the same circular-window convolution, and write all MTP rollback snapshots in the producer kernel. This removes GET_ROWS, CONCAT, and per-snapshot CPY launches for decode and verification batches up to 32 tokens.

Result: promoted. K018c measured 180.43, 178.56, and 178.03 tok/s (median 178.03) on the retained stack. The kernel reproduces `rs_zero`, loads aliased input state before writes, and uses the original snapshot window formula. All generated programs passed. One seed crossed a floating-point sampling boundary, but output quality and MTP acceptance remained valid.

## K019/K020 - recurrent projection fusion

Hypothesis: write the quantized beta projection directly through sigmoid and the alpha projection directly through bias, softplus, and scale, removing recurrent post-op launches.

Result: beta sigmoid fusion retained; alpha fusion rejected. The beta guard improved the same seed from 180.43 to 185.71 tok/s and the three-seed median was 179.82. Adding alpha softplus/scale reduced the guard to 180.19, indicating extra transcendental work and register lifetime in MMVQ outweighed launch savings on SM86.

## K021 - persistent Q8_1 activation reuse

Hypothesis: preserve a converted activation across harmless intervening nodes while invalidating on stream changes, different matrix sources, or any output-memory overlap with the source.

Result: promoted. The guard reached 189.18 tok/s and the three-seed run measured 186.28, 180.24, and 176.98 tok/s (median 180.24). Output and acceptance were valid. The retained implementation remains opt-in and releases the cache at graph completion.

## K022/Q001 - four warps for Q8_0 five-column verification

Hypothesis: the dominant exact Q8_0 five-column verification shape benefits from four warps after graph/state launch overhead is reduced, even though one warp regressed and two warps was the previous local optimum.

Result: promoted and qualified. K022 measured 191.83, 176.50, and 198.45 tok/s (median 191.83). Q001 then measured five rotated seeds at 190.35, 184.41, 199.07, 195.35, and 188.11 tok/s (median 190.35). All five programs compiled under MSVC C++20 with `/W4 /WX`, executed successfully, and printed `All tests passed.` Peak telemetry was 70 C, 253 W, and 20,788 MiB VRAM. The four-warp reduction changes floating-point summation order and therefore sampled trajectories, but quality and acceptance gates passed.

## V008-V011 - retained launch stack

Q6_K single-column three warps and Q6_K five-column one warp were independently useful. Combined with the 128-thread activation quantizer and the retained Q8_0 five-column four-warp kernel, V010 reached 196.83, 190.67, 200.95, 200.40, and 197.72 tok/s (median 197.72). Six CPU threads reduced the median to 194.06, so ten remains the contract.

## K038-K079 - plateau reassessment

Two-entry Q8 reuse, alternate Q6/IQ3/IQ4 rows and warps, quantizer sizes, top-k launch geometry, PDL, CUDA connection policy, CPU affinity, compiler fast math, MMQ substitution, graph parallelism, and altered speculative thresholds did not improve the five-seed stack. Multi-row top-k fusion removed sorts but changed routing arithmetic and was slower for five rows. Direct single-state views changed rollback behavior and were rejected. All losing changes were removed.

## K089 - runtime-index GDN state gather

Hypothesis: the recurrent GET_ROWS immediately feeding GDN can be elided without assuming a fixed cache row. The fused CUDA dispatch reads the runtime I32 row id inside the GDN kernel, then retains the existing direct snapshot-cache output fusion.

Result: provisional. The matcher activated, the established seed trajectory and acceptance counters remained exact, and the first measured guard reached 185.58 tok/s during the campaign's lower sustained-power period. This removes one state-gather launch per GDN layer. It requires a cooled five-seed qualification before promotion.

## V012-V014/Q002 - quant-specific MoE row scheduling

The runtime-index GDN gather was retained after a five-seed exact-output run. Profiling the resulting stack showed that four MoE rows per block reduced IQ3_XXS latency modestly and IQ4_XS latency substantially. A quant-specific specialization then kept IQ3_XXS at four rows while increasing IQ4_XS to eight. Sixteen IQ4_XS rows regressed to 188.45 tok/s on the matched measured seed and was removed.

The retained eight/four specialization first measured a 198.53 tok/s five-seed median. A clean repeat qualification measured 200.19, 198.69, 205.55, 204.07, and 195.55 tok/s, for a 200.19 median. MTP acceptance remained active, peak telemetry was 71 C, 254 W, and 20,794 MiB, and all five generated programs compiled with MSVC C++20 `/W4 /WX`, ran successfully, and printed `All tests passed.`

## K096-V017 - exact router radix sort

MMF sigmoid fusion, broader Q8 aliasing, IQ4_XS rpb12, IQ3_XXS rpb6, and alternate MoE token-block layouts all regressed and were removed. K102-K104 were invalid because CUDA compilation had failed while the old DLL remained loadable; their apparent gains are discarded.

A valid CUB block radix sort reduced the dominant 256-expert descending argsort from about 11.5 us to 7.16 us at 256x1, 5.67 us at 128x2, and still lower at the retained 64x4 geometry. The 32x8 endpoint was slightly slower. Sorting remains complete and exact, and all established trajectories and MTP acceptance counters match. V017 measured 206.72, 203.53, 208.41, 215.26, and 206.59 tok/s, for a 206.72 median. Peak telemetry was 71 C, 260 W, and 20,748 MiB. This is promoted as an intermediate improvement but does not satisfy the 215 tok/s goal.

## K110-V018 - multi-token MoE GLU fusion

The existing CUDA graph recognizer hard-disabled quantized `MUL_MAT_ID` GLU fusion when the token dimension exceeded one, while the dedicated multi-token MoE kernel ignored fusion arguments. The retained specialization computes the IQ3 gate and up projections in one kernel, preserves each warp reduction order, and applies the existing scalar GLU operation at writeback. It removes the second IQ3 launch and standalone gated activation without changing the sampled trajectories or acceptance counters.

The matched guard reached 216.96 tok/s. V018 measured 210.82, 202.80, 218.70, 217.58, and 207.31 tok/s, for a 210.82 median. Peak telemetry was 71 C, 259 W, and 20,745 MiB. Fused rpb2, fused rpb5, paired split warps, `minBlocksPerSM=2`, and 16 CUDA device connections all regressed. RMSNorm512 changed numerical trajectories, reduced MTP acceptance, and fell to 185.80 tok/s; RMSNorm1024 was restored. The 215 median goal remains open.

## K127-K137 - post-fusion exact and occupancy sweep

Bin-broadcast block width, fused IQ3 rows per block, launch-bound register pressure, process priority, CUDA connection counts, reduced router writes, and GDN block widths were tested against the fixed workload. The IQ3 dual-dot attempt failed MTP acceptance and was removed. Writing only the consumed top-8 router indices remained exact but V019 reached only a 211.53 tok/s median. GDN2 produced a 219.14 guard but V020 reached only 210.41 median; GDN3 failed output quality. All losing source and environment changes were removed. The retained engine remains V018 at a qualified 210.82 tok/s median, and the 215 median goal remains open.

## K138-Q006 - exact IQ3 activation reuse

MoE down-scale and weighted-output reduction fusions were rejected after either invalidating MTP acceptance or failing to improve the repeated median. Profiling then returned attention to the fused IQ3_S gate/up kernel. One output row per block increased available block parallelism, while a corrected dual-dot helper decodes each shared Q8_1 activation fragment once and applies it to independent gate and value accumulators in the original DP4A order.

Q005 cleared the speed threshold but failed quality because one generated test asserted that an unmatched opening bracket was valid. Q006 used five fresh rotating seeds and measured 220.58, 216.49, 212.80, 186.20, and 220.12 tok/s, for a 216.49 median. Every measured C++20 response compiled with MSVC `/W4 /WX`, ran successfully, and passed its assertions. Peak telemetry was 73 C, 271 W, and 20,783 MiB. The exact engine and fixed profile were promoted as `engines/b10079-mtp-215tps`.

## RW001-R002 - production streaming and MTP threshold/polling

RW001 measured the historical promoted engine through streamed
`/v1/chat/completions` with the fixed sampled coding workload. Its five-run
stream-total median was 184.89 tok/s, server decode was 199.71 tok/s, and TTFT
was 171.28 ms. This established the client-visible control that the original
server-decode qualification lacked.

M001/M002 lowered only speculative p-min from 0.25 to 0.20. The full five-run
stream median improved to 189.71 tok/s but missed the strict +5 target by 0.18
tok/s. M003 at 0.18 and M004 at 0.15 did not beat the three-seed p-min 0.20
screen and were rejected.

R001/R002 combined p-min 0.20 with `--poll 0 --spec-draft-poll 0`, reducing
host busy-poll competition on the single-user path. R002 measured 198.01,
188.25, 187.70, 192.31, and 191.42 tok/s streamed end-to-end, for an ordinary
median of 191.42 tok/s. Server decode median was 207.89 tok/s and TTFT median
was 133.12 ms. All five generated programs passed strict MSVC compile and
runtime checks. Draft acceptance stayed between 81.7% and 86.6%. Promote both
runtime settings into the launcher; no source or binary change is required.
# 2026-08-01 continuation after K001

- MTP depth 3, 5, and 6 and host thread counts 8 and 12 did not improve the
  client-visible three-seed median. Depth 4 and ten threads remain the control.
- The Q6_K small-K correctness failure came from using the destination stride
  as the output-row bound. Passing `nrows_x` through the kernel launch restores
  the optimized path and passes 1,210 of 1,210 focused CUDA cases. Nsight P021
  showed that the dominant 248,320-row Q6_K target head does not select this
  small-K specialization, so the repair is correctness-only for this model.
- Draft-only widths of 98,304 and 65,536 rows did not materially improve 35B.
  Target-prefix truncation excluded termination tokens and failed quality.
  Adding the contiguous Qwen special-token tail restored byte-identical output
  but the fill/scatter graph cost reduced throughput to 174.74 tok/s. Both
  target-head experiments were removed.
- `p-split=0` produced a 201.67 tok/s five-seed median once, then 192.32 on an
  immediate identical repeat. Outputs and MTP acceptance were identical, so
  the first result was run variance and is not a winner.
