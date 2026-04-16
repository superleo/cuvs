/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

/**
 * @file c_api_compat.h
 * @brief Backend-neutral runtime type aliases for the cuVS C API.
 *
 * This header intentionally provides types only. It does not declare API
 * functions so it can be included safely by both public and internal headers.
 */

#ifdef CUVS_BACKEND_MUSA
#include <musa_runtime.h>
typedef musaStream_t cuvsStream_t;
#else
#include <cuda_runtime.h>
typedef cudaStream_t cuvsStream_t;
#endif
