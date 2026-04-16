/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#include <gtest/gtest.h>
#include <cuvs/core/c_api.h>

/**
 * C1: C API resource lifecycle contract tests (from test plan L3).
 */

class CApiResourceLifecycleTest : public ::testing::Test {};

TEST_F(CApiResourceLifecycleTest, CreateAndDestroy)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);
  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, SetGetStream)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);

  cuvsStream_t stream;
  cudaStreamCreate(&stream);

  ASSERT_EQ(cuvsStreamSet(res, stream), CUVS_SUCCESS);

  cuvsStream_t retrieved;
  ASSERT_EQ(cuvsStreamGet(res, &retrieved), CUVS_SUCCESS);
  ASSERT_EQ(retrieved, stream);

  cudaStreamDestroy(stream);
  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, StreamSync)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);
  ASSERT_EQ(cuvsStreamSync(res), CUVS_SUCCESS);
  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, GetDeviceId)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);

  int device_id = -1;
  ASSERT_EQ(cuvsDeviceIdGet(res, &device_id), CUVS_SUCCESS);
  EXPECT_GE(device_id, 0);

  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, RMMAllocAndFree)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);

  void* ptr = nullptr;
  ASSERT_EQ(cuvsRMMAlloc(res, &ptr, 1024), CUVS_SUCCESS);
  ASSERT_NE(ptr, nullptr);
  ASSERT_EQ(cuvsRMMFree(res, ptr, 1024), CUVS_SUCCESS);

  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, VersionGet)
{
  uint16_t major = 0, minor = 0, patch = 0;
  ASSERT_EQ(cuvsVersionGet(&major, &minor, &patch), CUVS_SUCCESS);
  EXPECT_GT(major + minor + patch, 0);
}

TEST_F(CApiResourceLifecycleTest, ErrorTextClearOnSuccess)
{
  cuvsResources_t res;
  ASSERT_EQ(cuvsResourcesCreate(&res), CUVS_SUCCESS);
  const char* err = cuvsGetLastErrorText();
  EXPECT_EQ(err, nullptr);
  ASSERT_EQ(cuvsResourcesDestroy(res), CUVS_SUCCESS);
}

TEST_F(CApiResourceLifecycleTest, LogLevelRoundTrip)
{
  cuvsLogLevel_t original = cuvsGetLogLevel();
  cuvsSetLogLevel(CUVS_LOG_LEVEL_WARN);
  EXPECT_EQ(cuvsGetLogLevel(), CUVS_LOG_LEVEL_WARN);
  cuvsSetLogLevel(original);
}
