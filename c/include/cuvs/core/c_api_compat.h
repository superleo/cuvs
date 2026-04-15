/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

/**
 * @file c_api_compat.h
 * @brief Backend-neutral stream type for the cuVS C API.
 *
 * Including this header gives you `cuvsStream_t` which resolves to the
 * appropriate GPU runtime stream type based on the active backend.
 *
 * Existing code can continue to include c_api.h which still exposes
 * cudaStream_t directly for full backward compatibility on CUDA.
 */

#ifdef CUVS_BACKEND_MUSA
#include <musa_runtime.h>
typedef musaStream_t cuvsStream_t;
#else
#include <cuda_runtime.h>
typedef cudaStream_t cuvsStream_t;
#endif

#include <dlpack/dlpack.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Set a GPU stream on cuvsResources_t.
 *        Backend-neutral version: accepts cuvsStream_t.
 */
cuvsError_t cuvsStreamSet(cuvsResources_t res, cuvsStream_t stream);

/**
 * @brief Get the GPU stream from a cuvsResources_t.
 *        Backend-neutral version: returns cuvsStream_t.
 */
cuvsError_t cuvsStreamGet(cuvsResources_t res, cuvsStream_t* stream);

#ifdef __cplusplus
}
#endif
