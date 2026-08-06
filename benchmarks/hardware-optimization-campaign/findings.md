# Durable Findings

Read this file before every continuation of this campaign. Preserve superseded findings and link corrections to raw evidence and commits.

## Current production invariants

- Target model: `Qwen3.6-35B-A3B-UD-Q3_K_M.gguf` through the Qwen MTP production launcher.
- Required sampling: temperature `0.6`, top-k `20`, top-p `0.95`, min-p `0.0`, reasoning off.
- Verify sampling in the live request or slot. Launcher arguments and `/props` alone are insufficient because clients can override them.
- Context layer skipping is disabled by default. Enable `ENABLE_CONTEXT_SKIP5=1` only for an explicitly accepted approximate-performance experiment.
- The launcher currently uses content-only chat parsing to contain the PEG-native malformed-output failure. This prevents structured API `tool_calls`; do not claim structured tool support without a separate parser fix and validation.
- The UI default output cap is 4096. A caller can override it, so natural EOS/stop behavior remains a required test.
- Use automatic fan control and verify idle clocks, power, temperature, and fan behavior. Stop the exact server PID and verify VRAM and helper-process cleanup after tests.
- The current Codex session is RDP and cannot change NVIDIA application clocks without elevation. Do not compare its unlocked results with the earlier physical-console qualification. The production launcher also cannot apply its 9751 MHz memory lock from this unelevated session, so current-session controls must remain unlocked and paired.

## Accumulated mainline improvements

This is the stable commit index to inspect before repeating an experiment. The detailed measurements and rejected arms remain in `README.md`, `results.tsv`, and `theories.md`.

| Commit | Improvement | Current status |
| --- | --- | --- |
| `62bac409d` | Separate and qualify Qwen MTP targets | Retained |
| `2567f41f9` | Qualify full GPU/no-host operation | Retained |
| `793f2fb0c` | Reuse recurrent checkpoints on device | Retained |
| `4845d4f2a` | Increase MTP draft depth | Retained |
| `f95f2dfab` | Remove the server MTP draft cutoff | Retained |
| `f8d3fc4db` | Trim the MTP draft vocabulary | Retained with launcher/runtime guard |
| `243ef6d08` | Accelerate the fixed top-k sampling path | Retained |
| `766205674` | Restore AVX2 sampling on MSVC | Retained |
| `c111a7b37` | Compact mapped target logits | Retained |
| `ecb3cf41d` | Add middle-layer skip mode | Retained as experimental, disabled by default |
| `9e1cb7125` | Gate layer skipping by prompt length | Retained as experimental, insufficient as a fidelity guarantee |
| `232221f80` | Qualify 2145 MHz launcher operation | Superseded by later clock qualification |
| `e6e17a82f` | Qualify cooled 2190 MHz launcher operation | Retained |
| `89520c51f` | Qualify CUDA graph Qwen MTP launch | Retained |
| `20ee74c28` | Wait for fan-control cleanup | Retained |
| `6a5f37af2` | Replace fixed fan speed with automatic control | Retained |
| `33d6e2795` | Stabilize instruction responses and effective UI defaults | Retained, with structured-tool tradeoff documented below |

## F001 - Historical speed was not a current correctness baseline

**Failure:** Optimization continued from historical performance results without first re-establishing a stable production behavior baseline.

**Correction:** Treat historical winners as candidate configurations only. Re-run the current production launcher, verify identity, and establish cold/new plus warm/cache-hit controls before changing anything.

**Reusable rule:** Never inherit stability from an earlier campaign or decode-only result.

## F002 - Declared temperature did not prove effective temperature

**Failure:** Server defaults were treated as proof that real requests used the required sampling.

**Correction:** Add UI defaults and inspect both `/props` and live `/slots` or equivalent request state. Preserve request payloads because API clients may override server defaults.

**Stable configuration:** `Qwen3.6-35B-A3B-MTP-GGUF/qwen-ui-config.json`.

## F003 - Performance shortcuts passed narrow tests but threatened fidelity

**Failure:** Context-dependent layer skipping was enabled in the production launcher after performance validation that did not cover long multi-turn instruction following.

**Correction:** Disable context skipping by default and require explicit opt-in. Treat layer skipping and other approximation changes as quality changes, not ordinary tuning flags.

**Disproved assumption:** A prompt-token threshold alone is not a sufficient safety gate for an approximate model path.

## F004 - The visible prompt was not the actual request

**User-visible failure:** The visible instruction `Do nothing except say 'Hello'.` produced malformed text and continued generating.

**Captured production request:** Approximately 22,607 prompt tokens, tool/grammar parsing enabled, temperature 0.6, and `max_tokens=32000`. The server warned that backend sampling was incompatible with grammar and disabled it. Generation continued for more than 17,600 tokens before the exact process was stopped.

**Evidence:** `D625-live-user-repro/LAUNCHER-ERR.txt` and the live slot captures from that run.

**Reusable rule:** Reproduce the complete client payload, not only the visible final message. Include history, tools, parser/grammar, output cap, streaming, and request overrides.

## F005 - Long context was not the cause; parser/tool mode was

**Isolation:** A 21,708-token multi-turn request without tools returned exactly `Hello` and stopped after two tokens. Adding an unused tool schema activated PEG-native parsing and produced HTTP 500: `The model produced output that does not match the expected peg-native format`.

**Correction:** `--skip-chat-parsing` made the otherwise identical 21,950-token/tool-schema request return exactly `Hello` and stop after two tokens.

**Validation:** Five seeds with a 32,000-token allowance all returned exactly `Hello`, finish reason `stop`, two completion tokens. The actual production launcher independently passed a 21,952-token request.

**Evidence:** `Q627-long-history-no-tools`, `Q628-long-history-tools`, `Q629-long-history-tools-content-parser`, `Q630-content-parser-five-seed-full-cap`, and `Q631-production-launcher`.

**Capability tradeoff:** Content-only parsing does not create structured API `tool_calls`. A future structured-tool fix must repair or replace the parser path, then repeat no-tool, unused-tool, real-tool, long-context, exact-output, and natural-stop cells.

**Stable commit:** `33d6e2795` (`server: stabilize Qwen instruction responses`).

## F006 - Short exact answers cannot establish throughput

**Failure pattern:** A two-token response yields unstable or meaningless decode TPS.

**Correction:** Benchmark the same corrected production path with a representative long response and report server decode, prompt processing, and client-visible end-to-end rates separately.

**Measured corrected flow:** Five 512-token runs with a 19,956-token history, unused tool schema, temperature 0.6, and content-only parsing produced median server decode `125.38 tok/s` (range `108.94-189.96`). Cold prompt processing was `2480.50 tok/s`; warm client-visible output throughput was approximately `117.9 tok/s`.

**Evidence:** `Q632-content-only-real-flow-benchmark/SUMMARY.json`.

## Required pre-promotion checklist

1. Re-establish the current launcher baseline experimentally.
2. Verify PID, executable, binary/model hashes, alias, full command line, and effective request settings.
3. Preserve the exact payload and first generated text.
4. Test cold/new, warm/cache-hit, short, medium, long, streamed, and non-streamed paths.
5. Test exact-output and natural-stop behavior with both no tools and an unused tool schema.
6. Test a real structured tool call if tool execution is in scope.
7. Use at least five seeds for a finalist and retain all qualifying runs.
8. Validate quality and capability preservation, not merely throughput or HTTP success.
9. Test loaded-idle thermals/fan behavior and exact-process cleanup.
10. Update this file with the decision, evidence, tradeoffs, and stable commit.
