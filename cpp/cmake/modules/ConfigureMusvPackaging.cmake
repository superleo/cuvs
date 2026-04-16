# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
# =============================================================================

#[=======================================================================[
  ConfigureMusvPackaging.cmake

  When CUVS_GPU_BACKEND=MUSA, this module rewrites the project-level
  naming variables so that all build artifacts use the "muvs" prefix
  instead of "cuvs".

  Variables set (all in PARENT_SCOPE or CACHE):
    CUVS_OUTPUT_NAME          - base library name ("cuvs" or "muvs")
    CUVS_OUTPUT_NAME_C        - C API library name ("cuvs_c" or "muvs_c")
    CUVS_EXPORT_SET           - CMake export set name
    CUVS_INSTALL_INCLUDE_DIR  - header install prefix (include/cuvs or include/muvs)
    CUVS_NAMESPACE            - C++ namespace token ("cuvs" or "muvs")

  Additionally defines a function:
    cuvs_apply_muvs_rename(<target>)
      Sets OUTPUT_NAME on the target to use the muvs prefix.

  A custom target "muvs_generate_renamed_headers" is created when the
  MUSA backend is selected; it invokes the Python rename script to produce
  muvs-prefixed headers in the build tree.
#]=======================================================================]

include_guard(GLOBAL)

# Requires ConfigureBackend.cmake to have been included first.
if(NOT DEFINED CUVS_BACKEND_IS_MUSA)
  message(FATAL_ERROR "ConfigureMusvPackaging.cmake requires ConfigureBackend.cmake")
endif()

# ---------------------------------------------------------------------------
# Naming variables
# ---------------------------------------------------------------------------

if(CUVS_BACKEND_IS_MUSA)
  set(CUVS_OUTPUT_NAME         "muvs"     CACHE INTERNAL "Library base name")
  set(CUVS_OUTPUT_NAME_C       "muvs_c"   CACHE INTERNAL "C API library name")
  set(CUVS_EXPORT_SET          "muvs-exports" CACHE INTERNAL "CMake export set")
  set(CUVS_INSTALL_INCLUDE_DIR "include/muvs" CACHE INTERNAL "Header install dir")
  set(CUVS_NAMESPACE           "muvs"     CACHE INTERNAL "C++ namespace token")
  set(CUVS_PACKAGE_NAME        "muvs"     CACHE INTERNAL "Package name for find_package")

  message(STATUS "muVS packaging: library=${CUVS_OUTPUT_NAME}, "
                 "headers=${CUVS_INSTALL_INCLUDE_DIR}, "
                 "namespace=${CUVS_NAMESPACE}")
else()
  set(CUVS_OUTPUT_NAME         "cuvs"     CACHE INTERNAL "Library base name")
  set(CUVS_OUTPUT_NAME_C       "cuvs_c"   CACHE INTERNAL "C API library name")
  set(CUVS_EXPORT_SET          "cuvs-exports" CACHE INTERNAL "CMake export set")
  set(CUVS_INSTALL_INCLUDE_DIR "include/cuvs" CACHE INTERNAL "Header install dir")
  set(CUVS_NAMESPACE           "cuvs"     CACHE INTERNAL "C++ namespace token")
  set(CUVS_PACKAGE_NAME        "cuvs"     CACHE INTERNAL "Package name for find_package")
endif()

# ---------------------------------------------------------------------------
# Per-target rename helper
# ---------------------------------------------------------------------------

function(cuvs_apply_muvs_rename target_name)
  if(CUVS_BACKEND_IS_MUSA)
    # Rewrite the output filename: libcuvs.so -> libmuvs.so
    get_target_property(_current_output ${target_name} OUTPUT_NAME)
    if(_current_output)
      string(REPLACE "cuvs" "muvs" _new_output "${_current_output}")
    else()
      string(REPLACE "cuvs" "muvs" _new_output "${target_name}")
    endif()
    set_target_properties(${target_name} PROPERTIES OUTPUT_NAME "${_new_output}")
    message(STATUS "muVS rename: ${target_name} -> ${_new_output}")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# Header rename target (generates muvs/ headers from cuvs/ sources)
# ---------------------------------------------------------------------------

# Custom targets require project mode (not cmake -P script mode).
if(CUVS_BACKEND_IS_MUSA AND CMAKE_PROJECT_NAME)
  find_package(Python3 COMPONENTS Interpreter QUIET)
  if(Python3_FOUND)
    set(_rename_script "${CMAKE_CURRENT_LIST_DIR}/../../../tools/musa/rename_cuvs_to_muvs.py")
    get_filename_component(_rename_script "${_rename_script}" ABSOLUTE)

    if(EXISTS "${_rename_script}")
      set(_src_headers "${CMAKE_CURRENT_LIST_DIR}/../../include/cuvs")
      set(_dst_headers "${CMAKE_BINARY_DIR}/include/muvs")
      get_filename_component(_src_headers "${_src_headers}" ABSOLUTE)

      add_custom_target(muvs_generate_renamed_headers
        COMMAND ${Python3_EXECUTABLE} "${_rename_script}"
                --src "${_src_headers}"
                --dst "${_dst_headers}"
        COMMENT "Generating muVS headers from cuVS sources"
        VERBATIM
      )

      # Also generate the compatibility header
      add_custom_target(muvs_generate_compat_header
        COMMAND ${Python3_EXECUTABLE} "${_rename_script}"
                --generate-compat-header
                --dst "${CMAKE_BINARY_DIR}/include"
        COMMENT "Generating muVS compatibility header"
        VERBATIM
      )

      message(STATUS "muVS: header rename targets registered "
                     "(muvs_generate_renamed_headers, muvs_generate_compat_header)")
    else()
      message(WARNING "muVS: rename script not found at ${_rename_script}")
    endif()
  else()
    message(WARNING "muVS: Python3 not found — header rename targets disabled")
  endif()
endif()
