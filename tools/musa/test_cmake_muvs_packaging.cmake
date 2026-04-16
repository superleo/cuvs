# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
# =============================================================================

#[=======================================================================[
  CMake script-mode test for ConfigureMusvPackaging.cmake

  Run with:
    cmake -DCUVS_GPU_BACKEND=MUSA -P tools/musa/test_cmake_muvs_packaging.cmake
    cmake -DCUVS_GPU_BACKEND=CUDA -P tools/musa/test_cmake_muvs_packaging.cmake

  Asserts that the naming variables are set correctly for each backend.
#]=======================================================================]

cmake_minimum_required(VERSION 3.26)

# Simulate the minimal state ConfigureBackend needs
if(NOT DEFINED CUVS_GPU_BACKEND)
  set(CUVS_GPU_BACKEND "CUDA")
endif()

# Script-mode does not support CACHE variables, so stub them
macro(set_cache_var var val)
  set(${var} "${val}")
endmacro()

# Include the backend selector (which includes packaging)
# We need to provide a project-like context
set(CMAKE_CURRENT_LIST_DIR "${CMAKE_CURRENT_LIST_DIR}/../../cpp/cmake/modules")
include("${CMAKE_CURRENT_LIST_DIR}/ConfigureBackend.cmake")

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

function(assert_equal var expected)
  if(NOT "${${var}}" STREQUAL "${expected}")
    message(FATAL_ERROR "FAIL: ${var} = '${${var}}', expected '${expected}'")
  endif()
  message(STATUS "PASS: ${var} = '${${var}}'")
endfunction()

if(CUVS_GPU_BACKEND STREQUAL "MUSA")
  assert_equal(CUVS_OUTPUT_NAME         "muvs")
  assert_equal(CUVS_OUTPUT_NAME_C       "muvs_c")
  assert_equal(CUVS_EXPORT_SET          "muvs-exports")
  assert_equal(CUVS_INSTALL_INCLUDE_DIR "include/muvs")
  assert_equal(CUVS_NAMESPACE           "muvs")
  assert_equal(CUVS_PACKAGE_NAME        "muvs")
  assert_equal(CUVS_BACKEND_IS_MUSA     "ON")
  assert_equal(CUVS_BACKEND_IS_CUDA     "OFF")
  message(STATUS "All MUSA packaging assertions passed")
elseif(CUVS_GPU_BACKEND STREQUAL "CUDA")
  assert_equal(CUVS_OUTPUT_NAME         "cuvs")
  assert_equal(CUVS_OUTPUT_NAME_C       "cuvs_c")
  assert_equal(CUVS_EXPORT_SET          "cuvs-exports")
  assert_equal(CUVS_INSTALL_INCLUDE_DIR "include/cuvs")
  assert_equal(CUVS_NAMESPACE           "cuvs")
  assert_equal(CUVS_PACKAGE_NAME        "cuvs")
  assert_equal(CUVS_BACKEND_IS_CUDA     "ON")
  assert_equal(CUVS_BACKEND_IS_MUSA     "OFF")
  message(STATUS "All CUDA packaging assertions passed")
else()
  message(FATAL_ERROR "Unexpected backend: ${CUVS_GPU_BACKEND}")
endif()
