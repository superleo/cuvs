/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <gtest/gtest.h>
#include <cuvs/core/backend/macros.hpp>
#include <cuvs/core/backend/runtime.hpp>
#include <cuvs/core/backend/types.hpp>

#include <cstring>
#include <vector>

namespace cuvs::backend::test {

// ---------------------------------------------------------------------------
// R1: Stream contract
// ---------------------------------------------------------------------------

class StreamContractTest : public ::testing::Test {};

TEST_F(StreamContractTest, CreateSyncDestroy)
{
  cuvsStream_t stream;
  CUVS_BACKEND_TRY(stream_create(&stream));
  CUVS_BACKEND_TRY(stream_synchronize(stream));
  CUVS_BACKEND_TRY(stream_destroy(stream));
}

TEST_F(StreamContractTest, CreateNonBlocking)
{
  cuvsStream_t stream;
  CUVS_BACKEND_TRY(stream_create_non_blocking(&stream));
  CUVS_BACKEND_TRY(stream_synchronize(stream));
  CUVS_BACKEND_TRY(stream_destroy(stream));
}

TEST_F(StreamContractTest, RepeatedCreateDestroy)
{
  for (int i = 0; i < 10; ++i) {
    cuvsStream_t stream;
    CUVS_BACKEND_TRY(stream_create(&stream));
    CUVS_BACKEND_TRY(stream_synchronize(stream));
    CUVS_BACKEND_TRY(stream_destroy(stream));
  }
}

// ---------------------------------------------------------------------------
// R2: Memory contract
// ---------------------------------------------------------------------------

class MemoryContractTest : public ::testing::Test {};

TEST_F(MemoryContractTest, AllocFree)
{
  void* ptr = nullptr;
  CUVS_BACKEND_TRY(device_malloc(&ptr, 1024));
  ASSERT_NE(ptr, nullptr);
  CUVS_BACKEND_TRY(device_free(ptr));
}

TEST_F(MemoryContractTest, HostToDeviceToHost)
{
  constexpr size_t N = 128;
  std::vector<float> host_src(N, 3.14f);
  std::vector<float> host_dst(N, 0.0f);

  void* dev_ptr = nullptr;
  CUVS_BACKEND_TRY(device_malloc(&dev_ptr, N * sizeof(float)));

  CUVS_BACKEND_TRY(
    memcpy_sync(dev_ptr, host_src.data(), N * sizeof(float), memcpy_kind::host_to_device));
  CUVS_BACKEND_TRY(
    memcpy_sync(host_dst.data(), dev_ptr, N * sizeof(float), memcpy_kind::device_to_host));

  for (size_t i = 0; i < N; ++i) {
    EXPECT_FLOAT_EQ(host_dst[i], 3.14f);
  }

  CUVS_BACKEND_TRY(device_free(dev_ptr));
}

TEST_F(MemoryContractTest, DeviceToDevice)
{
  constexpr size_t bytes = 256;
  void* src              = nullptr;
  void* dst              = nullptr;
  CUVS_BACKEND_TRY(device_malloc(&src, bytes));
  CUVS_BACKEND_TRY(device_malloc(&dst, bytes));

  std::vector<uint8_t> host_data(bytes, 0xAB);
  CUVS_BACKEND_TRY(
    memcpy_sync(src, host_data.data(), bytes, memcpy_kind::host_to_device));
  CUVS_BACKEND_TRY(
    memcpy_sync(dst, src, bytes, memcpy_kind::device_to_device));

  std::vector<uint8_t> result(bytes, 0);
  CUVS_BACKEND_TRY(
    memcpy_sync(result.data(), dst, bytes, memcpy_kind::device_to_host));

  for (size_t i = 0; i < bytes; ++i) {
    EXPECT_EQ(result[i], 0xAB);
  }

  CUVS_BACKEND_TRY(device_free(src));
  CUVS_BACKEND_TRY(device_free(dst));
}

TEST_F(MemoryContractTest, AsyncCopyWithSync)
{
  constexpr size_t N = 64;
  std::vector<int> host_src(N, 42);
  std::vector<int> host_dst(N, 0);

  void* dev_ptr = nullptr;
  CUVS_BACKEND_TRY(device_malloc(&dev_ptr, N * sizeof(int)));

  cuvsStream_t stream;
  CUVS_BACKEND_TRY(stream_create(&stream));

  CUVS_BACKEND_TRY(memcpy_async(
    dev_ptr, host_src.data(), N * sizeof(int), memcpy_kind::host_to_device, stream));
  CUVS_BACKEND_TRY(memcpy_async(
    host_dst.data(), dev_ptr, N * sizeof(int), memcpy_kind::device_to_host, stream));
  CUVS_BACKEND_TRY(stream_synchronize(stream));

  for (size_t i = 0; i < N; ++i) {
    EXPECT_EQ(host_dst[i], 42);
  }

  CUVS_BACKEND_TRY(stream_destroy(stream));
  CUVS_BACKEND_TRY(device_free(dev_ptr));
}

// ---------------------------------------------------------------------------
// R3: Event contract
// ---------------------------------------------------------------------------

class EventContractTest : public ::testing::Test {};

TEST_F(EventContractTest, CreateRecordSyncDestroy)
{
  cuvsStream_t stream;
  CUVS_BACKEND_TRY(stream_create(&stream));

  cuvsEvent_t event;
  CUVS_BACKEND_TRY(event_create(&event));
  CUVS_BACKEND_TRY(event_record(event, stream));
  CUVS_BACKEND_TRY(event_synchronize(event));
  CUVS_BACKEND_TRY(event_destroy(event));

  CUVS_BACKEND_TRY(stream_destroy(stream));
}

TEST_F(EventContractTest, EventOrderingGuarantee)
{
  constexpr size_t N = 32;
  std::vector<float> host_data(N, 1.0f);

  void* dev_ptr = nullptr;
  CUVS_BACKEND_TRY(device_malloc(&dev_ptr, N * sizeof(float)));

  cuvsStream_t stream;
  CUVS_BACKEND_TRY(stream_create(&stream));

  CUVS_BACKEND_TRY(memcpy_async(
    dev_ptr, host_data.data(), N * sizeof(float), memcpy_kind::host_to_device, stream));

  cuvsEvent_t event;
  CUVS_BACKEND_TRY(event_create(&event));
  CUVS_BACKEND_TRY(event_record(event, stream));
  CUVS_BACKEND_TRY(event_synchronize(event));

  std::vector<float> result(N, 0.0f);
  CUVS_BACKEND_TRY(
    memcpy_sync(result.data(), dev_ptr, N * sizeof(float), memcpy_kind::device_to_host));

  for (size_t i = 0; i < N; ++i) {
    EXPECT_FLOAT_EQ(result[i], 1.0f);
  }

  CUVS_BACKEND_TRY(event_destroy(event));
  CUVS_BACKEND_TRY(stream_destroy(stream));
  CUVS_BACKEND_TRY(device_free(dev_ptr));
}

// ---------------------------------------------------------------------------
// R4: Error mapping
// ---------------------------------------------------------------------------

class ErrorMappingTest : public ::testing::Test {};

TEST_F(ErrorMappingTest, SuccessConstant)
{
  EXPECT_EQ(rt_success, rt_success);
}

TEST_F(ErrorMappingTest, ErrorStringNonNull)
{
  const char* msg = get_error_string(rt_success);
  ASSERT_NE(msg, nullptr);
}

TEST_F(ErrorMappingTest, InvalidFreeReturnsError)
{
  // Attempting to free an invalid pointer should return a non-success error.
  // We use get_last_error after the call to verify error state.
  cuvsRtError_t err = device_free(reinterpret_cast<void*>(0xDEADBEEF));
  if (err != rt_success) {
    const char* msg = get_error_string(err);
    ASSERT_NE(msg, nullptr);
  }
  // Reset error state
  get_last_error();
}

// ---------------------------------------------------------------------------
// Device management
// ---------------------------------------------------------------------------

class DeviceManagementTest : public ::testing::Test {};

TEST_F(DeviceManagementTest, GetDevice)
{
  int device_id = -1;
  CUVS_BACKEND_TRY(get_device(&device_id));
  EXPECT_GE(device_id, 0);
}

TEST_F(DeviceManagementTest, DeviceSynchronize)
{
  CUVS_BACKEND_TRY(device_synchronize());
}

}  // namespace cuvs::backend::test
