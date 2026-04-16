# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
# =============================================================================

# Backend selection: CUDA (default) or MUSA
set(CUVS_GPU_BACKEND "CUDA" CACHE STRING "GPU backend: CUDA or MUSA")
set_property(CACHE CUVS_GPU_BACKEND PROPERTY STRINGS "CUDA" "MUSA")

string(TOUPPER "${CUVS_GPU_BACKEND}" CUVS_GPU_BACKEND)

if(NOT CUVS_GPU_BACKEND STREQUAL "CUDA" AND NOT CUVS_GPU_BACKEND STREQUAL "MUSA")
  message(FATAL_ERROR
    "Invalid CUVS_GPU_BACKEND='${CUVS_GPU_BACKEND}'. Supported values: CUDA, MUSA"
  )
endif()

message(STATUS "cuVS: GPU backend = ${CUVS_GPU_BACKEND}")

if(CUVS_GPU_BACKEND STREQUAL "CUDA")
  set(CUVS_BACKEND_IS_CUDA ON)
  set(CUVS_BACKEND_IS_MUSA OFF)
elseif(CUVS_GPU_BACKEND STREQUAL "MUSA")
  set(CUVS_BACKEND_IS_CUDA OFF)
  set(CUVS_BACKEND_IS_MUSA ON)
endif()

# Backend-neutral alias targets are created after toolkit discovery.
# This function wraps that step so callers just call cuvs_create_backend_aliases().
function(cuvs_create_backend_aliases)
  if(CUVS_BACKEND_IS_CUDA)
    # Alias CUDA toolkit targets to backend-neutral names.
    # Callers link against cuvs_backend::runtime etc.
    if(NOT TARGET cuvs_backend::runtime)
      add_library(cuvs_backend_runtime INTERFACE)
      target_link_libraries(cuvs_backend_runtime INTERFACE CUDA::cudart)
      add_library(cuvs_backend::runtime ALIAS cuvs_backend_runtime)
    endif()

    if(NOT TARGET cuvs_backend::cublas AND TARGET CUDA::cublas${_ctk_static_suffix})
      add_library(cuvs_backend_blas INTERFACE)
      target_link_libraries(cuvs_backend_blas INTERFACE CUDA::cublas${_ctk_static_suffix})
      add_library(cuvs_backend::blas ALIAS cuvs_backend_blas)
    endif()

    if(NOT TARGET cuvs_backend::cusolver AND TARGET CUDA::cusolver${_ctk_static_suffix})
      add_library(cuvs_backend_solver INTERFACE)
      target_link_libraries(cuvs_backend_solver INTERFACE CUDA::cusolver${_ctk_static_suffix})
      add_library(cuvs_backend::solver ALIAS cuvs_backend_solver)
    endif()

    if(NOT TARGET cuvs_backend::cusparse AND TARGET CUDA::cusparse${_ctk_static_suffix})
      add_library(cuvs_backend_sparse INTERFACE)
      target_link_libraries(cuvs_backend_sparse INTERFACE CUDA::cusparse${_ctk_static_suffix})
      add_library(cuvs_backend::sparse ALIAS cuvs_backend_sparse)
    endif()

    if(NOT TARGET cuvs_backend::curand AND TARGET CUDA::curand${_ctk_static_suffix})
      add_library(cuvs_backend_rand INTERFACE)
      target_link_libraries(cuvs_backend_rand INTERFACE CUDA::curand${_ctk_static_suffix})
      add_library(cuvs_backend::rand ALIAS cuvs_backend_rand)
    endif()
  elseif(CUVS_BACKEND_IS_MUSA)
    # MUSA backend: create stub alias targets.
    # Real MUSA targets (MUSA::musart, mublas, etc.) will be wired once
    # the MUSA toolkit CMake integration is available.
    if(NOT TARGET cuvs_backend::runtime)
      add_library(cuvs_backend_runtime INTERFACE)
      # TODO(musa): target_link_libraries(cuvs_backend_runtime INTERFACE MUSA::musart)
      add_library(cuvs_backend::runtime ALIAS cuvs_backend_runtime)
    endif()

    if(NOT TARGET cuvs_backend::blas)
      add_library(cuvs_backend_blas INTERFACE)
      add_library(cuvs_backend::blas ALIAS cuvs_backend_blas)
    endif()

    if(NOT TARGET cuvs_backend::solver)
      add_library(cuvs_backend_solver INTERFACE)
      add_library(cuvs_backend::solver ALIAS cuvs_backend_solver)
    endif()

    if(NOT TARGET cuvs_backend::sparse)
      add_library(cuvs_backend_sparse INTERFACE)
      add_library(cuvs_backend::sparse ALIAS cuvs_backend_sparse)
    endif()

    if(NOT TARGET cuvs_backend::rand)
      add_library(cuvs_backend_rand INTERFACE)
      add_library(cuvs_backend::rand ALIAS cuvs_backend_rand)
    endif()
  endif()
endfunction()

# Packaging: set library/header/namespace names based on backend.
include(${CMAKE_CURRENT_LIST_DIR}/ConfigureMusvPackaging.cmake)

# Feature gate helper: use to skip modules not yet ported to MUSA.
# Usage: cuvs_feature_gate_musa(<feature_name>)
#   Sets <feature_name>_AVAILABLE to OFF when backend is MUSA and
#   prints an informational message.
function(cuvs_feature_gate_musa feature_name)
  if(CUVS_BACKEND_IS_MUSA)
    set(${feature_name}_AVAILABLE OFF PARENT_SCOPE)
    message(STATUS "cuVS: Feature '${feature_name}' is not yet available on MUSA backend - skipped")
  else()
    set(${feature_name}_AVAILABLE ON PARENT_SCOPE)
  endif()
endfunction()
