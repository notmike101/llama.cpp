# Qwen3.6 27B MTP RTX 3090 campaign

Target identity: `qwen36_27b_mtp_q4km` in `../model-targets.json`. Results in
this campaign do not transfer to Qwen3.6 35B-A3B MTP without a separate matched
35B experiment. In particular, the 32,791-row hot-token head, n-gram stack,
vision residency, Q4_K kernel changes, 65,536 context, and MTP depth 8 are
27B-specific evidence.

Goal: reach at least 150 tok/s median sampled single-user generation
throughput through `qwen3.6-27b-mtp/run-qwen.bat`.

Fixed contract: Qwen3.6-27B Q4_K_M MTP, CUDA, one request, 512 output tokens,
reasoning off, temperature 0.6, top-k 20, top-p 0.95, min-p 0.0, F16 KV,
backend sampling, vision-capable production launcher, and all model/context
buffers resident in RTX 3090 VRAM.

Host: Windows 11 Pro, Intel i9-10900KF, RTX 3090 24 GiB, NVIDIA driver 610.62,
CUDA 13.3 runtime/toolkit, repository commit
40b740ad05c531b9d57aca6698c3ed553a9e784c.

Promoted production profile: vision-resident Q4_K_M, context 65536,
`ngram-mod,draft-mtp`, n-gram min/max/match 4/8/24, MTP depth 8, p-min 0.338,
backend sampling, F16 target/draft KV, batch 2048, microbatch 512, and 10
target/draft threads. The MTP assistant materializes a deterministic
32791-row persistent hot-token head from the existing unchanged GGUF, and
target/draft polling is disabled. The CUDA Q4_K J=16 stream-K tiling threshold
is 50% on the RTX 3090. Windows High performance power mode is active.

Matched baseline: 71.03 tok/s median at MTP depth 4.

Qualified launcher result: 125.54 tok/s median across the first five
randomized quality-passing runs from L153 (runs 2, 4, 6, 8, and 9), a gain of
54.51 tok/s (+76.7%) over the matched 71.03 tok/s baseline. Their raw speeds
were 116.27, 125.54, 111.41, 128.85, and 148.65 tok/s. Every retained C++20
program compiled under MSVC `/W4 /WX`, executed, and printed `All tests
passed`. Peak text-run GPU memory was 23732 MiB. V003 launched through the
production batch file, correctly described the Statue of Liberty and
Manhattan skyline, and peaked at 23800 MiB. Post-run VRAM returned to 582 MiB.

Promoted launcher: `qwen3.6-27b-mtp/run-qwen.bat`.

130 tok/s qualification: L199 exercised the exact launcher with ten random
seeds. Its first five strict MSVC compile/runtime quality passes measured
135.04, 112.48, 138.95, 138.83, and 121.70 tok/s, median 135.04 tok/s. A
sixth quality pass measured 138.15 tok/s. The all-seed raw median was 127.39
tok/s. V200 passed vision through the exact launcher, peaking at 23852 MiB;
post-run VRAM returned to 637 MiB. The packaged engine is
`engines/b10079-mtp-tile50`, and its `ggml-cuda.dll` SHA-256 is
`36B55D62429C973D2DF95D6776D2565315791300CE15A1A6C91290388FFB4D59`.

140 tok/s qualification: K400 exercised the full 65536 context with five
fixed random seeds. Four outputs passed strict MSVC `/W4 /WX` compilation and
runtime validation; their speeds were 123.77, 141.23, 142.78, and 136.64
tok/s, for a 141.23 tok/s upper-median. K410 independently replayed the same
contract and reached a 141.07 tok/s strict-pass upper-median. Raw five-seed
medians were 137.26 and 136.59. Peak text VRAM was 23892 MiB.

The promoted engine is `engines/b10079-mtp-hot32791`. Its `llama.dll`
SHA-256 is
`305ED844A6FA5D45ADD84AE45B277933F41DE05B79AB3B21DBEC74000128D9A5`;
its byte-identical production `ggml-cuda.dll` remains
`36B55D62429C973D2DF95D6776D2565315791300CE15A1A6C91290388FFB4D59`.
The map SHA-256 is
`6CDF31DA08CC365B0BE3589F43412C9F6EEEBE28D8D1B90569BA251260D326D2`.
V416 passed vision through the no-override launcher and peaked at 23968 MiB.

145 tok/s qualification: K434 kept the exact Q4_K_M GGUF, 32791-row
persistent MTP head, sampler parameters, and randomized fixed seeds. It
selects the target top 20 directly from raw host logits, then uses the existing
sampler chain unchanged. Four strict MSVC `/W4 /WX` compile/runtime quality
passes measured 129.36, 147.18, 148.36, and 144.44 tok/s, for a 147.18 tok/s
upper-median. The all-five raw median was 144.44 tok/s. V439 passed vision
through the no-override launcher, peaked at 23973 MiB, and released VRAM to
621 MiB. K441 replayed the final guarded production DLL: its four strict
passes measured 128.59, 146.34, 146.47, and 143.07 tok/s, for a 146.34 tok/s
upper-median. V442 then passed vision through that same final guarded engine
at a 23973 MiB peak. The promoted engine is
`engines/b10079-mtp-hot32791-fasttopk`; its `llama-common.dll` SHA-256 is
`7381606E7762375B78F142884EE61358B924789D6DFF0008D5D95D6C3CB1DF7C`.

150 tok/s qualification: K463 added an AVX2 32-logit target top-k scan with
a 1 KiB L1 prefetch and retained the direct accepted hidden-row handoff.
M477 then used MTP p-min 0.30 over the fixed five randomized seeds. The three
strict MSVC `/W4 /WX` compile/runtime quality passes measured 145.88, 150.36,
and 158.84 tok/s, for a true median of 150.36 tok/s. M478 independently
replayed the same binary and seeds; its strict passes measured 146.67, 150.23,
and 160.02 tok/s, for a reproduced median of 150.23 tok/s. The promoted
engine is `engines/b10079-mtp-hot32791-avx2-fasttopk`; its
`llama-common.dll` SHA-256 is
`0B055B6BB98FF8CB96002CE4824AB9DFE6574C3A5C60C5793D5029D61BF3FCFD`.
V479 passed vision through the no-override launcher, correctly described the
Statue of Liberty and Manhattan skyline, reported 23921 MiB during inference,
and released VRAM to 627 MiB.

Seed variance remains material. K401 used ten new cryptographic seeds and
reached 127.60 tok/s raw and strict-pass upper-medians. L412 used five further
no-override launcher seeds and reached 132.42 tok/s. These audits are retained
alongside the reproducible qualification rather than hidden.

140 tok/s campaign: P201 showed that the dominant decode kernels remain Q4_K
target matmuls, while the MTP head inside the same Q4_K_M GGUF accounts for
about 20% of GPU kernel time. K202 (80 stream-K blocks) reached 108.54 tok/s
median and K203 (Q6_K K=512) reached 116.23; both were reverted. Runtime-only
MTP-head vocabulary views leave `Qwen3.6-27B-Q4_K_M.gguf` unchanged. The
32K, 48K, 72K, and 96K views reached 122.09, 123.20, 128.81, and 131.12
tok/s raw medians. The 65K view remains strongest at 134.16 tok/s in A204;
depth 9 reached 130.53. At 65K, p-min 0.30 and 0.35 reached 134.05 and
130.71. Reversing the draft order reached 121.35. A post-MTP n-gram extension
prototype hit a target output-capacity assertion on its second request and
was removed. A 2-warp Q6_K single-column kernel reached 120.57 and was
reverted to the proven 3-warp shape. No 140 tok/s candidate has been promoted.
Coupled target/draft sampling reached 97.14 and was removed. An opt-in lazy
MTP KV catch-up prototype peaked at 189.47 tok/s, but its MTP-8 randomized
median was only 133.59 tok/s and one of the five measured outputs failed the
strict runtime assertion gate. MTP-4 fell to 121.84 tok/s. The prototype was
removed, the production launcher remained untouched, and idle VRAM returned
to 651 MiB.
K225 found no gain from lowering only the Q6_K J16 tiling threshold, at
133.15 tok/s median. K226 halved that kernel's output-row tile and regressed
to 99.47. Linear depth-aware MTP confidence schedules reached only 102.31 and
93.40. Depth 7 reached 104.10, and Q8_0 draft-only KV reached 107.71 while
the required target KV remained F16. All were rejected; no launcher setting
was changed. Raising the n-gram minimum to 3 reached 124.48, and doubling
the Q4_K five-column MMVQ kernel to 4 warps reached 110.64. Both were
rejected. Reducing the Q4_K four-column MMVQ kernel from 4 to 2 warps reached
119.80 and was also rejected; the CUDA source was restored. The intermediate
65K p-min 0.28 point reached only 115.88 and was rejected.
An 1800 MHz graphics-clock diagnostic was unavailable to the current Windows
user, so clocks were not changed. Guarded 32-bit indexing for the recurrent
F32 copy hotspot reached 131.69 and was rejected; the source was restored.
A reproducible 32,768-entry hot-token map is ready. It covers every one of
9,795,447 tokens observed across 1,280 in-tree source files and explicitly
includes Qwen text and vision control IDs. Its SHA-256 is
`3A03B39A633C92FCA00E9750BF6FFF491B9D1D881A9214753B7C6C2573EF64E4`.
The existing Q4_K_M GGUF remains unchanged. CUDA mapped-row projection work
was approved and tested at both 32K and 65K widths, but reached only 106.09
and 111.32 tok/s medians. A correctness-safe accepted-prefix lazy catch-up
reached 107.64 tok/s, p-min 0.40 reached 111.70, and n-gram maximum 10 reached
95.53. All runtime/source candidates were rejected and removed; the qualified
135.04 tok/s production launcher remains unchanged. An exact-launcher
recheck of the 65K/p-min-0.30 combination reached only 115.73 tok/s across
five new random seeds, so those launcher edits were reverted.
H314 continuous telemetry found intermittent 1425-1635 MHz throttling at up
to 328 W and 78 C, but acceptance still explained the seed ordering. MTP
assistant top-8, repeated input-upload reuse, p-split 0.15, assistant p-min
0.20, and CUDA_DEVICE_MAX_CONNECTIONS=1 reached 128.66, 115.75 (one-seed
smoke), 127.77, 128.16, and 127.84 tok/s respectively. All were rejected and
restored. The next architectural target is reducing the correctness-required
eight-head catch-up GPU work itself without skipping recurrent state updates.
An exact C222 seed replay on production was valid and reached 116.34 tok/s
median. Correctness-staged lazy catch-up reached 118.15 tok/s when flushed
every round and 92.00 tok/s with a 16-row cadence; both were removed. Extending
recursive MTP depth to 12 reached 86.62 tok/s and was rejected. The current
Windows user still cannot lock GPU clocks. No 140 tok/s candidate has been
promoted; the existing Q4_K_M launcher and engine remain unchanged.
K324 preserved the exact three-warp internal Q6_K arithmetic while processing
two vocabulary rows sequentially per block. Its paired 127.93 tok/s median
trailed the 129.12 production control, so it was removed.
K325 routed only Q4_K J16 to the existing tensor-core path and reached
114.71 tok/s on the paired smoke seed versus 116.52 production. MMQ routing
was restored.
L326 made no changes and requalified the exact production batch file on ten
fresh random seeds. Six strict compile/runtime passes had a 130.33 tok/s
median; the raw median was 125.21. The qualified L199 135.04 tok/s launcher
remains the production winner and was not modified.
E327 screened the existing later-campaign 215 tok/s engine without modifying
production. It reached 115.00 tok/s on the paired seed versus 116.52 for the
tile50 engine, so it was rejected immediately.
E328 screened the distinct 190-era engine at 115.33 tok/s versus 116.52
production. It was rejected without expansion. Remaining existing packages
are already measured or CUDA-identical duplicates.
K329 vectorized the dominant Q4_K J16 activation-tile copy without changing
arithmetic. It preserved exact acceptance but reached 115.49 tok/s versus
116.52 production, so the scalar copy was restored.
K330 tested L2-only CUDA global-load caching and fell to 93.11 tok/s with
lower acceptance. Default caching and the original build configuration were
restored.
K331 tested the generic shared-memory fragment loader on only the dominant
Q4_K J16 A tile. Its lane mapping was incompatible: draft acceptance fell to
zero and throughput collapsed to 18.34 tok/s. The source was restored; the
production launcher and engine were never modified.
K332 halved the dominant Q4_K J16 hot-loop barriers using a second shared Y
tile, but the added shared memory reduced occupancy and throughput to 96.17
tok/s. It was rejected as a standalone change; the follow-up tested the same
barrier reduction with a smaller row tile to restore shared-memory headroom.
The compensating path did not survive correctness. K333's invalid eight-warp
I=96 mapping caused an illegal CUDA access. K334 used the coherent six-warp
mapping and reached 123.62 tok/s, but emitted only reasoning markup and slash
garbage. Both were rejected and the entire dual-buffer branch was restored.
K335 removed repeated synchronized target-embedding row access, but an exact
current-source control beat it 96.49 to 95.04 tok/s. The production package
reached 115.53 on that seed with a different acceptance path, revealing that
the remaining unsynchronized draft-embedding source override is not represented
by the promoted binary and is the next controlled reconciliation target.
K336-K337 isolated that divergence: a full current build remained near 96.8
tok/s, while replacing only `llama-common.dll` on byte-identical production
binaries reproduced production at 115.83 tok/s and exact acceptance. K338 used
that valid hybrid to remove repeated target synchronization and reached 116.18,
only +0.36 tok/s; it was rejected as noise. Future host experiments use the
surgical production hybrid.
K339's capacity-safe MTP-to-ngram pipeline was inactive on the controlled
coding workload and reached 116.09 tok/s. K340 isolated the no-sync draft
embedding read on production and preserved exact acceptance, but its five-seed
128.82 tok/s median trailed the established 129.12 control. Neither was
promoted; production remains the qualified 135.04 tok/s launcher.
K341 tested an MTP top1-top2 probability-margin stop in the same surgical
hybrid. It reached only 83.76 tok/s against a same-seed 117.08 production
control despite healthy acceptance, so it was removed without expansion.
K342 forced two-block occupancy for the dominant Q4_K J16 verifier kernel.
Register pressure changed draft numerics and reduced throughput to 95.57
tok/s, so the original one-block launch bound was restored.
R343 swept four nearby lower contexts to test an upstream report of
context-boundary MTP acceptance changes. Acceptance was identical throughout
and the best arm reached 116.61 tok/s versus 117.08 at production's 65536, so
the launcher remains unchanged.
K344 enabled host LTO only in a synchronized surgical common-library hybrid.
It retained exact acceptance but reached 116.15 tok/s versus the 117.08
control. LTO was disabled again and nothing was promoted.
K345 removed redundant sorting of the backend MTP shortlist and preserved
exact output, but reached only 116.67 tok/s versus 117.08 control. The change
was reverted.
K346 replaced per-step indexed hot-vocabulary projection with a persistent
contiguous 32768-token Q6_K draft head gathered in VRAM from the unchanged
GGUF. It fit safely at 23823 MiB, but paired-seed acceptance fell to 0.67784
and throughput was only 116.40 tok/s. The opt-in source path was removed.
R347-R350 found that disabling target and draft CPU polling preserved exact
output and improved a fresh paired median from 119.82 to 121.28 tok/s. The
gain is useful stacking evidence but too small for standalone promotion.
K351-K352 tested persistent full-vocabulary Q6_K MTP-head grids at four and
32 blocks per SM. They reached only 89.43 and 98.71 tok/s, so the source path
was removed and production remains unchanged.
D353 showed eighth-position cumulative MTP acceptance of only 31.2%, but K354
proved that dynamically stopping at seven still selects the slow seven-token
verifier graph and collapses throughput to 68.38 tok/s. That source change was
removed.
M355 forcing eight drafts via speculative p-min zero reduced acceptance and
reached 105.86 tok/s. K356 verifier-only padding also failed to isolate a gain
through the divergent full server build and reached 100.03 tok/s; it was
removed.
P357 matched traces located the exact discontinuity: nine-column verification
uses Q4_K J16 MMQ, while eight columns falls into Q4_K J8 MMVQ. K358 proved
the compute diagnosis by improving an identical depth-seven seed from 64.37
to 90.22 tok/s when J8 was forced through MMQ. The MMQ reduction order changed
acceptance, however, and the actual depth-eight randomized median regressed
from 115.83 to 113.52. Extending MMQ to columns two through eight fell to
104.67. Both source hooks were removed; production remains unchanged. The
next safe arm is tuning the existing J8 MMVQ launch shape while preserving its
numerical behavior.
K361-K363 then swept that MMVQ launch between one, two, and four warps using a
matched current-source control. Two warps remained best at 114.82 tok/s;
four reached 112.04 and one reached 110.54. The original source setting was
restored.
K364 preserved exact acceptance by splitting J8 into two four-column,
two-warp launches, but reached only 114.22 versus the matched 114.82 control.
The structural split was removed.

160 tok/s qualification: M522 selected MTP p-min 0.338 while retaining the
existing Qwen3.6-27B Q4_K_M GGUF, engine binaries, 32791-row persistent MTP
head, context 65536, vision projector, and required sampling parameters.
Three strict compile/runtime passes measured 171.14, 144.44, and 175.31
tok/s, median 171.14. M523 reproduced the same paths at 171.15, 146.50, and
175.99 tok/s, median 171.15.

L524 then exercised the promoted `qwen3.6-27b-mtp/run-qwen.bat` with no
runtime overrides. Its strict passes measured 171.38, 146.53, and 178.16
tok/s, median 171.38. Peak text VRAM was 23976 MiB. V525 passed vision through
that same launcher, correctly described the Statue of Liberty and Manhattan
skyline, contained no reasoning text, and peaked at 24044 MiB. The exact
Q4_K_M GGUF SHA-256 is
`A7CBD3ECC0E3F9B333EDEE61AE66BC87ED713C5D49587A8355814722ED329E0F`;
the F16 projector SHA-256 is
`EACF610D1EE4BD5ED0197A0777DD8F4FCEB8EEFA27009067C7D496CB68FBDE45`.

## 2026-07-31 current-host audit

The exact K718 production launcher was rechecked on the current RTX 3090 with
the required 65536 context, Q4_K_M GGUF, F16 projector, MTP depth 8, and
`ngram-mod,draft-mtp`. The fixed warmup plus five measured samples were
114.49, 135.08, 171.97, 145.16, and 178.85 tok/s (ordinary median 145.16).
After a cooled replay they were 115.90, 136.56, 173.12, 147.54, and 179.26
tok/s (ordinary median 147.54). GPU clocks stayed at 1695 MHz, so the shortfall
was not thermal throttling.

The historical K743 and K744 artifacts recorded ordinary five-seed medians of
152.55 and 152.99 tok/s, but their binaries are not present for identity
replay. Their headline 180 tok/s values used a strict subset of the seeds and
are not used as the current result. K718 remains the production launcher; no
unverified package was promoted.

Controlled checks rejected p-min 0.30/0.35, CUDA queue counts 1/16, CPU
threads 9/11, high priority, the older hot-map engine, and clean or hybrid
rebuilds that changed speculative acceptance or failed the backend-sampling
contract. The fixed quality script also rejects the current seed set: run 1
omits the required output and run 2 fails an assertion. Those failures are
retained rather than hidden.

The exact launcher identity was verified through `/health`, `/v1/models`, the
port owner command line, executable SHA-256, and loaded module hashes. A
client-visible three-seed `/completion` run measured a 92.62 tok/s server
decode median and 88.57 tok/s request end-to-end median; one streamed request
measured 54.62 tok/s total. These are real-use measurements, not replacements
for the fixed decode contract.

The continuation checks added six more data points. Twelve target/draft
threads reached 146.05 tok/s, the historical K573 Q4 fatbin transplant reached
142.75 tok/s, and resetting the graphics and memory clock controls before a
fresh K718 run reached 146.06 tok/s. A narrow p-min 0.337/0.3375 sweep reached
145.73 and 146.57 tok/s respectively. A clean-host/production-CUDA hybrid was
rejected at 131.24 tok/s because its MTP acceptance path changed. None of
these isolated artifacts is selected by `run-qwen.bat`.

The only remaining path with enough headroom is the previously documented
exact-host nine-copy rollback graph fusion. That requires invasive binary/host
work and was not applied without explicit user confirmation. K718 remains the
safe launcher, and all experimental servers were stopped after measurement.

The isolated K883 current-API host-revert build completed, but transplanting
K718's device fatbins failed at model load with a named-symbol error. Its
matching clean-host DLL did load, yet the authoritative p-min 0.338 replay
reached only 145.81 tok/s and failed the quality script on run 1. A one-seed
p-min 0.25 diagnostic reached 158.74 tok/s but changed MTP acceptance and was
outside the frozen contract. The paired K718 p-min 0.338 control with the same
pdl0 compatibility environment reached 146.08 tok/s. K883 is rejected and no
experimental engine is selected by the launcher.

The final safe runtime screen, exact K718 with `--mmap`, measured 137.76 tok/s
on the protected seed and was rejected. The production launcher still uses
`--no-mmap` and no model process is resident after measurements.

The remaining built-in graph scheduler screen, `GGML_CUDA_GRAPH_OPT=1` on
exact K718, measured 138.94 tok/s on the protected seed and was rejected.

The archived K831 fusion package with its old SSM direct-state-disabled
setting reached 146.98 tok/s on the protected seed and was also rejected.

The isolated K829 convolution rollback-fusion package reached 134.62 tok/s on
the protected seed and was rejected.

K833's clean-host q4/q6 fusion package reached 134.63 tok/s and was rejected;
K836's b9190 host-fusion package crashed during startup and was rejected.

Disabling K718's rollback-fusion environment toggle produced 138.11 tok/s on
the protected seed with unchanged acceptance, so it is diagnostic only and
the production launcher remains unchanged.
