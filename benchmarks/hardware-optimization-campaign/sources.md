# Sources

No external performance claim has been promoted. Current changes are based on local profiling and paired benchmarks against llama.cpp b10079.

- 2026-07-21: https://github.com/ggml-org/llama.cpp/issues/23903 - reports increased MTP compute-buffer footprint after backend sampling was introduced and names PR 23287 as the prime suspect. Applicability to RTX 3090 throughput is unverified; motivates R001.
- 2026-07-21: https://github.com/ggml-org/llama.cpp/pull/20700 - WIP FastMTP prototype reports the full vocabulary projection as its largest draft bottleneck and uses a row view to trim draft logits. Its 32K quality claim is not accepted as evidence; K005 tests a conservative 65K view locally with exact-output gates.
- 2026-07-21: https://cdn.discordapp.com/attachments/438532573807771649/1529351342777303111/message.txt - user-supplied private ROCmFPX campaign report. Portable mechanisms tested locally were direct SSM convolution state, recurrent projection fusion, and staged Q8 activation reuse. AMD-specific wave64, ROCmFP4, HIP launch, and workgroup conclusions were not transferred to CUDA.
- 2026-08-01: https://docs.nvidia.com/nsight-systems/UserGuide/ - current Nsight Systems guidance on CUDA graph tracing, Windows WDDM tracing, and profiling overhead. Used to keep profiler results diagnostic rather than benchmark evidence.
- 2026-08-01: https://github.com/ggml-org/llama.cpp/discussions/23738 - adaptive MTP depth report. Different Apple hardware and therefore unverified locally; reinforced testing MTP controls only through matched local runs.
- 2026-08-01: https://github.com/ggml-org/llama.cpp/issues/23184 - proposed pipelined MTP/ngram speculation for repetitive workloads. Not used because the fixed coding prompt and current independent implementations do not establish an equivalent safe gain.
