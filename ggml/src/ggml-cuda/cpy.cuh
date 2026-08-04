#include "common.cuh"

#define CUDA_CPY_BLOCK_SIZE 64

void ggml_cuda_cpy(ggml_backend_cuda_context & ctx, const ggml_tensor * src0, ggml_tensor * src1);

void ggml_cuda_cpy_f32_rollback(ggml_backend_cuda_context & ctx,
        const ggml_tensor * src0, ggml_tensor * dst0,
        int slots, int repeated_src0, int64_t dst_slot_stride);

void ggml_cuda_dup(ggml_backend_cuda_context & ctx, ggml_tensor * dst);
