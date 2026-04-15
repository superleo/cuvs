/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <cuvs/core/backend/runtime.hpp>
#include <cstdio>
#include <cstdlib>

/**
 * Backend-neutral error-checking macros.
 *
 * These mirror the RAFT_CUDA_TRY / CHECK_CUDA pattern but dispatch through
 * the cuvs::backend adapter so the same call site compiles on both CUDA and
 * MUSA.
 */

#define CUVS_BACKEND_TRY(call)                                                        \
  do {                                                                                 \
    cuvsRtError_t _cuvs_err = (call);                                                  \
    if (_cuvs_err != cuvs::backend::rt_success) {                                      \
      fprintf(stderr,                                                                  \
              "cuVS backend error @ %s:%d : %s\n",                                     \
              __FILE__,                                                                 \
              __LINE__,                                                                 \
              cuvs::backend::get_error_string(_cuvs_err));                              \
      throw std::runtime_error(cuvs::backend::get_error_string(_cuvs_err));            \
    }                                                                                  \
  } while (0)

#define CUVS_BACKEND_CHECK_LAST_ERROR()                                                \
  do {                                                                                 \
    cuvsRtError_t _cuvs_err = cuvs::backend::get_last_error();                         \
    if (_cuvs_err != cuvs::backend::rt_success) {                                      \
      fprintf(stderr,                                                                  \
              "cuVS backend error @ %s:%d : %s\n",                                     \
              __FILE__,                                                                 \
              __LINE__,                                                                 \
              cuvs::backend::get_error_string(_cuvs_err));                              \
      throw std::runtime_error(cuvs::backend::get_error_string(_cuvs_err));            \
    }                                                                                  \
  } while (0)
