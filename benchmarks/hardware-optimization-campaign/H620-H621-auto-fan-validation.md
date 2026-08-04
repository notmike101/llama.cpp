# Qwen MTP automatic fan validation

Date: 2026-08-03

## Change

The production launcher now selects automatic GPU fan control by default. Set
`GPU_FAN_MODE=fixed` to retain the existing `GPU_FAN` percentage override for
controlled benchmark work.

## Matched served comparison

H620 and H621 used the same Qwen3.6-35B-A3B-UD-Q3_K_M model, promoted engine,
CUDA graph path, clocks, +100 MHz core offset, MTP settings, five seeds,
streamed API route, sampling, prompt, and 512-token cap. Fan mode was the only
independent variable.

| Metric | Fixed 100% | Automatic |
| --- | ---: | ---: |
| Stream generation-only median | 297.175 tok/s | 298.382 tok/s |
| Stream-total median | 266.361 tok/s | 272.915 tok/s |
| Server decode median | 297.112 tok/s | 298.408 tok/s |
| TTFT median | 119.610 ms | 108.197 ms |
| Median sampled fan | 100% | 35% |
| Maximum core temperature | 71 C | 77 C |

The automatic run's 98% peak fan sample occurred during the initial transition
from the preceding fixed-fan control. Its median was 35%. All six generated
programs in each arm were byte-identical across arms, compiled with MSVC C++20
`/W4 /WX`, executed, and printed `All tests passed.`

## Launcher validation

The edited launcher loaded the exact promoted server and model, retained one
HTTP worker, and completed a sampled served request. Fan speed remained at 41%
through the request instead of switching to 100%. Stopping the exact server
returned through launcher cleanup, stopped Afterburner, reset the clocks,
released model VRAM, and left no inference or profiler process running.
