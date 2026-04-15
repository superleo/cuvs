/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <cuvs/core/backend/types.hpp>
#include <cstddef>

/**
 * Backend-neutral wrappers for GPU runtime operations.
 *
 * Each function maps 1:1 to either a CUDA or MUSA runtime call depending
 * on the compile-time backend selection.  The naming convention follows the
 * cuVS ubiquitous language: cuvs::backend::<verb>.
 */

namespace cuvs::backend {

// ---------------------------------------------------------------------------
// Stream lifecycle
// ---------------------------------------------------------------------------

inline cuvsRtError_t stream_create(cuvsStream_t* stream)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaStreamCreate(stream);
#else
  return cudaStreamCreate(stream);
#endif
}

inline cuvsRtError_t stream_create_non_blocking(cuvsStream_t* stream)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaStreamCreateWithFlags(stream, musaStreamNonBlocking);
#else
  return cudaStreamCreateWithFlags(stream, cudaStreamNonBlocking);
#endif
}

inline cuvsRtError_t stream_synchronize(cuvsStream_t stream)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaStreamSynchronize(stream);
#else
  return cudaStreamSynchronize(stream);
#endif
}

inline cuvsRtError_t stream_destroy(cuvsStream_t stream)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaStreamDestroy(stream);
#else
  return cudaStreamDestroy(stream);
#endif
}

// ---------------------------------------------------------------------------
// Device memory
// ---------------------------------------------------------------------------

inline cuvsRtError_t device_malloc(void** ptr, size_t bytes)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaMalloc(ptr, bytes);
#else
  return cudaMalloc(ptr, bytes);
#endif
}

inline cuvsRtError_t device_free(void* ptr)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaFree(ptr);
#else
  return cudaFree(ptr);
#endif
}

// ---------------------------------------------------------------------------
// Memory copy (sync)
// ---------------------------------------------------------------------------

enum class memcpy_kind {
  host_to_device,
  device_to_host,
  device_to_device,
  host_to_host,
};

inline cuvsRtError_t memcpy_sync(void* dst, const void* src, size_t bytes, memcpy_kind kind)
{
#if defined(CUVS_BACKEND_MUSA)
  musaMemcpyKind mk;
  switch (kind) {
    case memcpy_kind::host_to_device:   mk = musaMemcpyHostToDevice;   break;
    case memcpy_kind::device_to_host:   mk = musaMemcpyDeviceToHost;   break;
    case memcpy_kind::device_to_device: mk = musaMemcpyDeviceToDevice; break;
    case memcpy_kind::host_to_host:     mk = musaMemcpyHostToHost;     break;
  }
  return musaMemcpy(dst, src, bytes, mk);
#else
  cudaMemcpyKind ck;
  switch (kind) {
    case memcpy_kind::host_to_device:   ck = cudaMemcpyHostToDevice;   break;
    case memcpy_kind::device_to_host:   ck = cudaMemcpyDeviceToHost;   break;
    case memcpy_kind::device_to_device: ck = cudaMemcpyDeviceToDevice; break;
    case memcpy_kind::host_to_host:     ck = cudaMemcpyHostToHost;     break;
  }
  return cudaMemcpy(dst, src, bytes, ck);
#endif
}

// ---------------------------------------------------------------------------
// Memory copy (async)
// ---------------------------------------------------------------------------

inline cuvsRtError_t memcpy_async(
  void* dst, const void* src, size_t bytes, memcpy_kind kind, cuvsStream_t stream)
{
#if defined(CUVS_BACKEND_MUSA)
  musaMemcpyKind mk;
  switch (kind) {
    case memcpy_kind::host_to_device:   mk = musaMemcpyHostToDevice;   break;
    case memcpy_kind::device_to_host:   mk = musaMemcpyDeviceToHost;   break;
    case memcpy_kind::device_to_device: mk = musaMemcpyDeviceToDevice; break;
    case memcpy_kind::host_to_host:     mk = musaMemcpyHostToHost;     break;
  }
  return musaMemcpyAsync(dst, src, bytes, mk, stream);
#else
  cudaMemcpyKind ck;
  switch (kind) {
    case memcpy_kind::host_to_device:   ck = cudaMemcpyHostToDevice;   break;
    case memcpy_kind::device_to_host:   ck = cudaMemcpyDeviceToHost;   break;
    case memcpy_kind::device_to_device: ck = cudaMemcpyDeviceToDevice; break;
    case memcpy_kind::host_to_host:     ck = cudaMemcpyHostToHost;     break;
  }
  return cudaMemcpyAsync(dst, src, bytes, ck, stream);
#endif
}

// ---------------------------------------------------------------------------
// Event lifecycle
// ---------------------------------------------------------------------------

inline cuvsRtError_t event_create(cuvsEvent_t* event)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaEventCreate(event);
#else
  return cudaEventCreate(event);
#endif
}

inline cuvsRtError_t event_record(cuvsEvent_t event, cuvsStream_t stream)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaEventRecord(event, stream);
#else
  return cudaEventRecord(event, stream);
#endif
}

inline cuvsRtError_t event_synchronize(cuvsEvent_t event)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaEventSynchronize(event);
#else
  return cudaEventSynchronize(event);
#endif
}

inline cuvsRtError_t event_destroy(cuvsEvent_t event)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaEventDestroy(event);
#else
  return cudaEventDestroy(event);
#endif
}

// ---------------------------------------------------------------------------
// Error utilities
// ---------------------------------------------------------------------------

inline const char* get_error_string(cuvsRtError_t err)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaGetErrorString(err);
#else
  return cudaGetErrorString(err);
#endif
}

inline cuvsRtError_t get_last_error()
{
#if defined(CUVS_BACKEND_MUSA)
  return musaGetLastError();
#else
  return cudaGetLastError();
#endif
}

constexpr cuvsRtError_t rt_success =
#if defined(CUVS_BACKEND_MUSA)
  musaSuccess;
#else
  cudaSuccess;
#endif

// ---------------------------------------------------------------------------
// Device management
// ---------------------------------------------------------------------------

inline cuvsRtError_t get_device(int* device_id)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaGetDevice(device_id);
#else
  return cudaGetDevice(device_id);
#endif
}

inline cuvsRtError_t set_device(int device_id)
{
#if defined(CUVS_BACKEND_MUSA)
  return musaSetDevice(device_id);
#else
  return cudaSetDevice(device_id);
#endif
}

inline cuvsRtError_t device_synchronize()
{
#if defined(CUVS_BACKEND_MUSA)
  return musaDeviceSynchronize();
#else
  return cudaDeviceSynchronize();
#endif
}

}  // namespace cuvs::backend
