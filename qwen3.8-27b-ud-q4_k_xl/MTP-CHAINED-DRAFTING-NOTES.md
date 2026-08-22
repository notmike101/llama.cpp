# MTP chained drafting + token rollback fix (upstream PR #27173)

## What this is

Integration of upstream llama.cpp PR https://github.com/ggml-org/llama.cpp/pull/27173
("speculative : draft performance improvement (+10% t/s with deeper draft depth
possible with this) + token rollback bugfix") into this branch, on top of upstream
commit `947fd9bb2`. The PR is open (not merged upstream) as of 2026-08-19.

Two independent changes:

1. Chained MTP drafting (the performance part). Normally the draft model runs one
   decode per draft token (n_max sequential decodes per round). With chained
   drafting, a single decode builds a graph that chains n_tokens MTP steps
   in-graph: each step's input (token + hidden state) is the previous step's
   in-graph argmax and normalized hidden state. One decode drafts n_max tokens, so
   a round with n_max=4 saves 3 evals. The chain samples greedily in-graph and
   emits [token id, top prob] per step, so no host sampling pass runs over the
   draft logits and the full-width logits transfer is avoided.

2. Token rollback bugfix (the correctness part). In the gated-delta-net conv state
   update, the slot loop bound was clamped to the current batch width, so deeper
   slots were overwritten with clamped duplicates of the last slot. A rollback that
   returns to an earlier, larger batch's position then read the wrong conv state.
   The fix bounds the loop to min(n_rs_seq, n_tok) so deeper slots keep the content
   an earlier larger batch wrote.

Supporting infrastructure (needed for the chain to run under the meta backend and
to keep alternating draft/verify shapes fast):

- Per-shape scheduler pool (LLAMA_SCHED_POOL=N): each recurring small decode shape
  (up to 32 tokens) keeps its own scheduler and cached graph, so alternating shapes
  reuse warm allocations, splits, and backend graph plans instead of re-splitting
  through one scheduler.
- Meta-backend shadow fingerprints: detect recycled tensor structs. The pool
  alternates graphs, so a tensor struct can be reused at the same address for a
  different tensor; pointer identity alone can no longer prove a plan is valid.
- Allreduce kernel-slot path (ggml_cuda_ar_kernel_slot): no host synchronization for
  the chunked kernel path. The in-kernel arrival handshake already serializes reuse
  of the 2-slot staging ring, so the host can enqueue a full token of subgraphs and
  reductions ahead of the GPUs.
- Mirror output head (LLAMA_META_MIRROR_OUTPUT=1): keep the output head whole on
  every device (mirrored instead of vocab-split) so backend sampling can run under
  the meta backend. Costs one extra head copy of VRAM per device.

## Files changed

Chained drafting:

- `src/llama-cparams.h` - `mtp_chain` cparam
- `src/llama-ext.h` - `llama_set_mtp_chain()` API
- `src/llama-context.h` - `set_mtp_chain()`, `sched_slot` pool, `sched_active`,
  `graph_reserve()` `sched_use` arg
- `src/llama-context.cpp` - pool lookup/alloc, `set_mtp_chain`, result readback via
  `sched_active`
- `src/models/qwen35.cpp` - in-graph chain: the MTP block, in-graph argmax +
  softmax prob + get_rows to feed the next step, sub-head, catch-up rows
- `common/speculative.cpp` - `chain_graph` driver: one chained decode for a single
  drafting sequence, catch-up row deferral

Supporting infrastructure:

- `ggml/src/ggml-backend-meta.cpp` - shadow fingerprints for recycled tensor structs
- `ggml/src/ggml-cuda/allreduce.cu` - `ggml_cuda_ar_kernel_slot` (no-host-sync slot)
- `src/llama-model.cpp` - `LLAMA_META_MIRROR_OUTPUT`
- `src/llama-graph.h` - `mtp_chain` in the topology check, `LLAMA_GRAPH_RESULT_DEBUG`

Token rollback bugfix:

- `src/models/delta-net-base.cpp` - conv-state slot bound `K = min(n_rs_seq, n_tok) + 1`

11 files, 1081 insertions, 124 deletions. The RWKV7 fusion files from PR #27267
(`ggml-cuda.cu`, `wkv.cu`, `wkv.cuh`, `test-backend-ops.cpp`) are separate and
untouched by this.

## Relevance to this branch

This branch already runs MTP (draft-n-max 4) from the q4_k_m port. Chained drafting
replaces the 4 sequential draft decodes with 1 in-graph chain. Combined with the
RWKV7 output fusion (PR #27267), it should show up in generation tok/s. The
conv-state rollback fix is a correctness fix that matters whenever a speculative
round is rejected and the position rolls back.

## Enable flags (all off by default)

Chained drafting is opt-in via env vars. The launcher (`run-qwen.bat`) does not set
them; add them to A/B test:

```
set LLAMA_SPEC_CHAIN=1            # enable chained drafting
set LLAMA_SCHED_POOL=4            # per-shape scheduler pool (4 slots; max 16)
set LLAMA_SPEC_CHAIN_SUB=32768    # sub-head width for the chain (0 = full head)
set LLAMA_META_MIRROR_OUTPUT=1    # mirror output head (for backend sampling)
```

The gate is presence-based, not value-based: `chain_graph` is set when
`getenv("LLAMA_SPEC_CHAIN") != nullptr` (speculative.cpp), so the var set to ANY
value (including `0`) enables the chain. `LLAMA_SPEC_CHAIN=0` does NOT disable it.
To disable the chain, UNSET the var entirely. This bit us: the "chain off" A/B run
below that set `LLAMA_SPEC_CHAIN=0` was actually chain-on.

`LLAMA_SPEC_CHAIN_SUB` narrows the draft head to the leading vocabulary range
(drafting rarely picks rare tokens). The target's full-vocab verify still decides
acceptance, so it only narrows what gets drafted, never what gets committed. The
emitted probability normalizes over the sub-head only, so it reads slightly high
against `--spec-draft-p-min`.

## Verification status

- [x] Code integrated (11 files)
- [x] All 169 objects in the build graph compile clean (CUDA 13.3, MSVC 19.44,
      SM86, Release); zero compile errors
- [ ] Link `ggml-base.dll` / `ggml-cuda.dll` / `llama-server.exe` - blocked while
      the running `llama-server.exe` holds `bin\ggml-base.dll` open
- [ ] Benchmark: restart server, A/B chained drafting on/off

## Finishing the build after the server restart

All objects are already compiled; only the final links are pending. After the old
server is stopped, run:

```
cd C:\llama-cpp-src\build-qwen38-ud-q4-k-xl
rebuild-server.bat
```

This links the DLLs and `llama-server.exe` in one pass (no recompilation).

## A/B benchmark plan

Baseline is the current running server (PR #27267 only, sequential drafts). Method:
`/metrics` cumulative counters `tokens_predicted_total` and
`tokens_predicted_seconds_total`, delta across each request.

1. restart server, no new env vars -> sequential-draft baseline
2. `set LLAMA_SPEC_CHAIN=1`, restart -> chained drafting
3. `set LLAMA_SPEC_CHAIN=1` + `set LLAMA_SCHED_POOL=4`, restart -> chain + pool

Compare generation tok/s and MTP acceptance (accepted tokens per verification step)
across the three. Watch for a quality regression from the sub-head
(`LLAMA_SPEC_CHAIN_SUB`) and confirm the rollback fix does not change accepted
output.

## Benchmark results

Method: /metrics deltas around two fresh prompts, the same two used for every A/B
run. P1 = C++ fib memoization (max_tokens 400), P2 = B-tree explanation
(max_tokens 512). Throughput = visible completion tokens / generation seconds
(`llamacpp:tokens_predicted_total` and `llamacpp:tokens_predicted_seconds_total`
deltas). acc/verify = accepted draft tokens / proposed draft tokens
(`llamacpp:spec_decode_num_accepted_tokens_total` / `..._num_draft_tokens_total`).

Note: in this build `tokens_predicted_total` counts visible completion tokens (its
delta matched the request `completion_tokens` exactly), so the throughput below is
the rate the user experiences, not the draft-token rate.

### Baseline - chained drafting OFF (2026-08-19)

Build: PR #27267 (RWKV7 fusion) + PR #27173 (rollback fix active, chain gated off).
No new env vars.

| Run | Visible | Gen time | Throughput | Draft | Accepted | acc/verify |
|---|---:|---:|---:|---:|---:|---:|
| P1 fib | 400 | 7.26 s | 55.1 tok/s | 631 | 241 | 0.38 |
| P2 btree | 512 | 12.20 s | 42.0 tok/s | 1061 | 245 | 0.23 |
| Combined | 912 | 19.45 s | 46.9 tok/s | 1692 | 486 | 0.29 |

### Chained drafting ON, n_max=4 (2026-08-19)

`LLAMA_SPEC_CHAIN=1`, same build, same two prompts. Three runs (one run each is
noisy; the spread below is larger than the baseline-vs-chained gap).

| Run | Visible | Gen time | Throughput | Draft | Accepted | acc/verify |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 912 | 19.94 s | 45.7 tok/s | 1516 | 528 | 0.35 |
| 2 | 912 | 20.84 s | 43.8 tok/s | 1656 | 494 | 0.30 |
| 3 | 912 | 18.77 s | 48.6 tok/s | 1490 | 536 | 0.36 |
| avg | 912 | 19.85 s | 46.0 tok/s | 1554 | 519 | 0.34 |

Chaining is confirmed active (draft tokens fall, acceptance rises vs baseline).
At n_max=4 it is neutral: ~46.0 tok/s vs the 46.9 baseline, within the run-to-run
spread. The chain does more tokens per round (2.38 vs 2.14) but each chained round
costs more than a sequential round, so they cancel. The PR's stated benefit is
deeper draft depth, where sequential drafting's cost grows linearly and the
chain's does not. Next experiment: n_max=8 (or higher) with the chain on.

### Chained ON, n_max=4, THINKING ON (2026-08-19)

The launcher had `--reasoning off` removed (thinking mode now enabled) at some
point after the baseline above. The committed script still has `--reasoning off`;
the README still says "thinking disabled" is the default, so this was a deliberate
change that the notes never captured. Confirmed active: a probe request returns a
non-empty `reasoning_content` field.

Three runs, same two prompts, chain on, thinking on:

| Run | Visible | Gen time | Throughput | Draft | Accepted | acc/verify |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 912 | 15.90 s | 57.3 tok/s | 1422 | 552 | 0.39 |
| 2 | 912 | 16.06 s | 56.8 tok/s | 1433 | 550 | 0.38 |
| 3 | 912 | 15.54 s | 58.7 tok/s | 1393 | 560 | 0.40 |
| avg | 912 | 15.83 s | 57.6 tok/s | 1416 | 554 | 0.39 |

This is +11 tok/s over the thinking-OFF chain-on number (46.0) and +10.7 over the
thinking-OFF baseline (46.9). The confound: thinking mode was turned on at the
same time as the chain was measured, so this jump is NOT a clean chain result.

Why thinking-on raises throughput: reasoning tokens are more predictable than
answer tokens, so the MTP draft is accepted more often. acc/verify rose 0.34 ->
0.39 when thinking was enabled (chain on in both). Higher acceptance = more
tokens per verify round = higher throughput, independent of the chain.

A/B matrix so far (same build, same two prompts):

| thinking | chain | tok/s | note |
|---|---|---:|---|
| off | off | 46.9 | baseline (true chain off, no env var) |
| off | on  | 46.0 | chain on at n_max=4 |
| on  | on  | 57.6 | chain on, thinking on (run A) |
| on  | on  | 59.1 | chain on, thinking on (run B; was mislabeled "off") |
| on  | off | ???  | still missing; true chain off never measured |

The off/off vs off/on pair isolates the chain at n_max=4 with thinking off: 46.9
vs 46.0, a ~0.9 tok/s drag, within the run-to-run spread (neutral to a small
drag). The two thinking-on chain-on numbers (57.6, 59.1) are within noise of each
other. The true chain-off (thinking on) number is still missing, so the chain's
effect at n_max=4 with thinking on is not cleanly isolated.

### Chained ON, n_max=8, THINKING ON (2026-08-19)

`SPEC_DRAFT_N_MAX=8`, chain on, thinking on. Confirmed drafting 8 deep (per-position
acceptance shows positions 0-7). Three runs:

| Run | Visible | Gen time | Throughput | Draft | Accepted | acc/verify |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 912 | 18.90 s | 48.3 tok/s | 2424 | 605 | 0.25 |
| 2 | 912 | 19.50 s | 46.8 tok/s | 2667 | 574 | 0.22 |
| 3 | 912 | 19.12 s | 47.7 tok/s | 2589 | 582 | 0.22 |
| avg | 912 | 19.17 s | 47.6 tok/s | 2560 | 587 | 0.23 |

n_max=8 is WORSE than n_max=4 (47.6 vs 57.6). Deeper drafting hurts on this model:
the per-position acceptance decays fast (position 7 is ~32% of position 0), so the
extra positions 4-7 are accepted too rarely to pay for the larger draft-token count
(~2500 vs ~1416) and the larger per-round verify cost. The chain makes drafting 8
tokens cheap, but it cannot overcome the falling acceptance plus the growing verify
cost.

### Mislabeled "Chained OFF", n_max=4, THINKING ON (2026-08-19) - actually CHAIN ON

This run set `LLAMA_SPEC_CHAIN=0`, intended as "chain off". But the gate is
presence-based (see Enable flags), so `LLAMA_SPEC_CHAIN=0` still enables the chain.
This run was therefore CHAIN ON, not chain off. The 59.1 below is a chain-on
number. n_max=4, thinking on. Three runs:

| Run | Visible | Gen time | Throughput | Draft | Accepted | acc/verify |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 912 | 15.09 s | 60.4 tok/s | 1347 | 571 | 0.42 |
| 2 | 912 | 15.36 s | 59.4 tok/s | 1381 | 563 | 0.41 |
| 3 | 912 | 15.90 s | 57.4 tok/s | 1436 | 550 | 0.38 |
| avg | 912 | 15.45 s | 59.1 tok/s | 1388 | 561 | 0.40 |

This is a chain-on number (59.1), in line with the other chain-on thinking-on
number (57.6). The 59.1 vs 57.6 gap is run-to-run variance, NOT a chain on/off
difference (both runs were chain on). So this run does not isolate the chain. The
true chain-off (thinking on) number was never measured: the only "chain off"
attempt set `LLAMA_SPEC_CHAIN=0`, which is actually chain on.

### Conclusion

The chain PR does not clearly help this model. At n_max=4 with thinking off it is a
~0.9 tok/s drag (46.9 off vs 46.0 on), within the run-to-run spread, so neutral to
a small drag. At n_max=8 it is a clear drag (47.6 vs the 57.6/59.1 chain-on numbers
at n_max=4): deeper drafting hurts because per-position acceptance decays fast. The
+12 tok/s over the original 46.9 baseline comes from enabling thinking mode, which
raises MTP acceptance on the more predictable reasoning tokens, not from the chain.

The chain also has a correctness bug (see Known issues below): the deferred
catch-up path can desync the draft KV cache from the target on a sequence rewind,
triggering an M-RoPE position error and a failed decode. That is why the launcher
now leaves the chain OFF by default (LLAMA_SPEC_CHAIN unset).

Best measured config: n_max=4, thinking on, chain off (unset). The true chain-off
thinking-on number is still unmeasured, but the chain is at best neutral and has a
bug, so leaving it off is the safe choice. Keep the PR code in the tree, because the
conv-state rollback fix in delta-net-base.cpp is a correctness fix that applies to
sequential drafting too and is worth keeping.

## Known issues

### M-RoPE position error in the deferred catch-up path (2026-08-19)

Symptom (intermittent, user-reported):

```
E init: the tokens of sequence 0 in the input batch have inconsistent sequence positions:
 - the last position stored in the memory module ... is X = 59119
 - the tokens for sequence 0 in the input batch have a starting position of Y = 599
 for M-RoPE, it is required that the position satisfies: X < Y
E spec flush_deferr: llama_decode(ctx_dft) deferred flush failed rc=-1
E srv decode: failed to process speculative batch
```

The draft context (ctx_dft) KV cache is at position X=59119, but the deferred flush
batch writes at position Y=599. The M-RoPE check (llama-batch.cpp) requires X < Y,
so the decode fails and the request errors out.

Root cause (high confidence, not yet code-fixed): the deferred catch-up rows are
absorbed into the draft decode, so the draft KV cache is kept in sync with the
target only via the position-rewind trim in process() (speculative.cpp). That trim
rolls back the draft cache (llama_memory_seq_rm) ONLY when there are stale deferred
rows to drop. When the target sequence is rewound (a new request, or a speculative
rollback to an early position) while the defer buffer is empty, the draft cache is
NOT rolled back and stays ahead (at 59119). The next deferred rows (at the new,
earlier position 599) are then flushed into the ahead cache, failing the M-RoPE
check.

This only happens with the chain on (the defer mechanism is gated behind
LLAMA_SPEC_CHAIN). With the chain off (var unset), the catch-up rows are decoded
immediately and the draft cache stays in sync, so the error does not occur.

Mitigation (applied): the launcher no longer sets LLAMA_SPEC_CHAIN, so the chain and
its defer path are off by default. The error is gone.

Proper fix (not yet done): in process(), roll back the draft cache to the incoming
batch's min position whenever the draft cache is ahead of it, not only when there
are stale deferred rows to drop. This needs care to avoid rolling back the
legitimately-ahead draft region (pending drafts from the last draft() call), so it
should be validated before enabling the chain again.

## Rollback

Uncommitted (working tree only). To revert PR #27173 without touching the RWKV7
fusion (PR #27267):

```
git checkout -- common/speculative.cpp ggml/src/ggml-backend-meta.cpp ggml/src/ggml-cuda/allreduce.cu src/llama-context.cpp src/llama-context.h src/llama-cparams.h src/llama-ext.h src/llama-graph.h src/llama-model.cpp src/models/delta-net-base.cpp src/models/qwen35.cpp
```

then rebuild. Or disable at runtime: simply do not set `LLAMA_SPEC_CHAIN` (the
chained path is fully gated). Note the conv-state rollback fix stays in that case,
which is the desired behavior since it is a correctness fix.
