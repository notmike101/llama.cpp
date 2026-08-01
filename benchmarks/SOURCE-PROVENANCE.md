# Qwen3.6 optimization source provenance

The repository working tree is shared by two different optimization targets.
It must not be treated as one cumulative, mutually beneficial stack.

## 35B-A3B MTP target

The authoritative target is `qwen36_35b_a3b_mtp_q3km` from
`model-targets.json`. Its promoted package is `engines/b10079-mtp-215tps`.
The 35B qualification document records changes in these files:

```text
common/speculative.cpp
ggml/src/ggml-cuda/argsort.cu
ggml/src/ggml-cuda/common.cuh
ggml/src/ggml-cuda/gated_delta_net.cu
ggml/src/ggml-cuda/gated_delta_net.cuh
ggml/src/ggml-cuda/ggml-cuda.cu
ggml/src/ggml-cuda/mmvq.cu
ggml/src/ggml-cuda/quantize.cuh
ggml/src/ggml-cuda/ssm-conv.cu
ggml/src/ggml-cuda/vecdotq.cuh
src/llama-context.cpp
src/llama-ext.h
src/llama-graph.cpp
src/models/qwen35moe.cpp
```

Even these shared files may contain later 27B edits in the current tree. The
list is an audit boundary, not proof that current source reproduces the engine.
The packaged binary and DLL hashes remain authoritative.

## 27B MTP target

The authoritative target is `qwen36_27b_mtp_q4km`. Its evidence includes
Q4_K-specific kernels, the 32,791-token persistent MTP head, n-gram drafting,
vision residency, 65,536 context, and MTP depth 8. None transfers to 35B
without a new experiment using the exact 35B target manifest.

## Mixed working tree

The current dirty tree includes later changes outside the recorded 35B set,
including sampler, n-gram, Q4_K/MMQ, copy-fusion, and model-plumbing work. A
new 35B build from this tree is `mixed-unverified`, regardless of whether it
loads the model. It can become a 35B candidate only after:

1. an isolated build directory and complete binary/DLL hashes;
2. the 35B model hash and 150,000-context identity check;
3. matched output and MTP acceptance validation against the packaged control;
4. the complete 35B real-use quality matrix;
5. a qualifying ordinary all-run median.
