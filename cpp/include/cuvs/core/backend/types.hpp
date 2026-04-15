/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

/**
 * Backend-neutral type aliases for GPU runtime primitives.
 *
 * Under CUDA these resolve to the native CUDA types. Under MUSA they resolve
 * to the MUSA equivalents (which are ABI-compatible by design).
 *
 * Domain code should include this header and use the cuvs_* typedefs instead
 * of including cuda_runtime.h / musa_runtime.h directly.
 */

#if defined(CUVS_BACKEND_MUSA)

#include <musa_runtime.h>
typedef musaStream_t  cuvsStream_t;
typedef musaError_t   cuvsRtError_t;
typedef musaEvent_t   cuvsEvent_t;

#else  // default: CUDA

#include <cuda_runtime.h>
typedef cudaStream_t  cuvsStream_t;
typedef cudaError_t   cuvsRtError_t;
typedef cudaEvent_t   cuvsEvent_t;

#endif
