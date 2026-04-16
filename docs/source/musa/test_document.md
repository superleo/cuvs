# MUSA Port MVP Test Document

## Purpose

Detailed specification of every test case delivered in the MVP, mapping each to the test plan, the system design contracts, and the acceptance criteria.

## Test Inventory Summary

| Suite | File | Cases | Plan Ref |
|---|---|---|---|
| Backend Adapter Contract | `cpp/tests/core/backend/test_runtime_adapter.cu` | 16 | L2 (R1-R4) |
| C API Resource Lifecycle | `c/tests/core/test_c_api_resource_lifecycle.cu` | 8 | L3 (C1) |
| Rename Script | `tools/musa/test_rename_cuvs_to_muvs.py` | 33 | L5 (P1) |
| CMake Packaging | `tools/musa/test_cmake_muvs_packaging.cmake` | 2 | L5 (P2) |
| **Total** | | **59** | |

---

## Suite 1: Backend Adapter Contract Tests

**File:** `cpp/tests/core/backend/test_runtime_adapter.cu`
**Namespace:** `cuvs::backend::test`
**Link deps:** GTest, `cuvs::backend` headers (header-only), GPU runtime

### R1: Stream Contract

| # | Test Case | Description | Validates |
|---|---|---|---|
| 1 | `StreamContractTest.CreateSyncDestroy` | Create stream, sync, destroy | Basic lifecycle correctness |
| 2 | `StreamContractTest.CreateNonBlocking` | Create with non-blocking flag, sync, destroy | Flag passthrough to backend |
| 3 | `StreamContractTest.RepeatedCreateDestroy` | 10 iterations of create/sync/destroy | Resource leak detection |

**Pass criteria:** No runtime error thrown; no GPU error state after each test.

### R2: Memory Contract

| # | Test Case | Description | Validates |
|---|---|---|---|
| 4 | `MemoryContractTest.AllocFree` | Allocate 1KB, verify non-null, free | Basic alloc/free path |
| 5 | `MemoryContractTest.HostToDeviceToHost` | Copy 128 floats H2D then D2H, check values | Round-trip data integrity |
| 6 | `MemoryContractTest.DeviceToDevice` | Copy 256 bytes D2D, read back to host | D2D correctness |
| 7 | `MemoryContractTest.AsyncCopyWithSync` | Async H2D + D2H on explicit stream, sync, check | Async path + sync correctness |

**Pass criteria:** All copied data matches expected values exactly.

### R3: Event Contract

| # | Test Case | Description | Validates |
|---|---|---|---|
| 8 | `EventContractTest.CreateRecordSyncDestroy` | Full event lifecycle on a stream | Basic event operations |
| 9 | `EventContractTest.EventOrderingGuarantee` | Async copy -> event record -> event sync -> read back | Event enforces completion ordering |

**Pass criteria:** Data read after event sync matches written data.

### R4: Error Mapping

| # | Test Case | Description | Validates |
|---|---|---|---|
| 10 | `ErrorMappingTest.SuccessConstant` | `rt_success == rt_success` | Constant well-defined |
| 11 | `ErrorMappingTest.ErrorStringNonNull` | `get_error_string(rt_success)` is non-null | String lookup works |
| 12 | `ErrorMappingTest.InvalidFreeReturnsError` | Free of 0xDEADBEEF produces detectable error | Error propagation from backend |

**Pass criteria:** Assertions hold; no crash on invalid-free detection.

### Device Management

| # | Test Case | Description | Validates |
|---|---|---|---|
| 13 | `DeviceManagementTest.GetDevice` | Query device id, expect >= 0 | Device query correctness |
| 14 | `DeviceManagementTest.DeviceSynchronize` | Call device_synchronize() | Sync path works |

**Pass criteria:** No runtime error; device ID is non-negative.

### Macro Self-Test (implicit)

All tests above use `CUVS_BACKEND_TRY` for every runtime call. This implicitly validates the error macro on every invocation.

---

## Suite 2: C API Resource Lifecycle Tests

**File:** `c/tests/core/test_c_api_resource_lifecycle.cu`
**Link deps:** GTest, `cuvs::c_api`, CUDA runtime, `cuvs::cuvs`

### C1: Resource Lifecycle

| # | Test Case | Description | Plan Ref | Validates |
|---|---|---|---|---|
| 15 | `CreateAndDestroy` | `cuvsResourcesCreate` + `cuvsResourcesDestroy` | C1 | Basic handle lifecycle |
| 16 | `SetGetStream` | Create stream, set on resource, get back, compare | C1 | Stream round-trip identity |
| 17 | `StreamSync` | Create resource, call `cuvsStreamSync` | C1 | Sync through C API |
| 18 | `GetDeviceId` | `cuvsDeviceIdGet`, check >= 0 | C1 | Device query |
| 19 | `RMMAllocAndFree` | `cuvsRMMAlloc` 1KB + `cuvsRMMFree` | C1 | Memory via C API |
| 20 | `VersionGet` | `cuvsVersionGet`, check non-zero sum | C1 | Version plumbing |
| 21 | `ErrorTextClearOnSuccess` | After success, `cuvsGetLastErrorText()` is NULL | C1 | Error state hygiene |
| 22 | `LogLevelRoundTrip` | Set WARN, get back, restore | C1 | Log config |

**Pass criteria:** All `ASSERT_EQ` on `CUVS_SUCCESS`; no unexpected error text.

---

## Test Execution Matrix

### CUDA Backend (primary, required)

```bash
# Configure
cmake -S cpp -B build-cuda -DCUVS_GPU_BACKEND=CUDA -DBUILD_TESTS=ON

# Build test targets
cmake --build build-cuda --target BACKEND_ADAPTER_TEST C_API_LIFECYCLE_TEST

# Run
ctest --test-dir build-cuda --output-on-failure -R "BACKEND_ADAPTER_TEST|C_API_LIFECYCLE_TEST"
```

### MUSA Backend (future, non-blocking)

```bash
# Configure (requires MUSA toolkit)
cmake -S cpp -B build-musa -DCUVS_GPU_BACKEND=MUSA -DBUILD_TESTS=ON

# Build adapter tests only (C API tests need RAFT/RMM MUSA port)
cmake --build build-musa --target BACKEND_ADAPTER_TEST

# Run
ctest --test-dir build-musa --output-on-failure -R "BACKEND_ADAPTER_TEST"
```

---

## Coverage Analysis

### Adapter API Coverage

| API Function | Test Case(s) |
|---|---|
| `stream_create` | 1, 3, 7, 8, 9 |
| `stream_create_non_blocking` | 2 |
| `stream_synchronize` | 1, 2, 3, 7 |
| `stream_destroy` | 1, 2, 3, 7, 8, 9 |
| `device_malloc` | 4, 5, 6, 7, 9 |
| `device_free` | 4, 5, 6, 7, 9, 12 |
| `memcpy_sync` (H2D) | 5, 6, 9 |
| `memcpy_sync` (D2H) | 5, 6, 9 |
| `memcpy_sync` (D2D) | 6 |
| `memcpy_async` (H2D) | 7, 9 |
| `memcpy_async` (D2H) | 7 |
| `event_create` | 8, 9 |
| `event_record` | 8, 9 |
| `event_synchronize` | 8, 9 |
| `event_destroy` | 8, 9 |
| `get_error_string` | 11, 12 |
| `get_last_error` | 12 |
| `rt_success` | 10 |
| `get_device` | 13 |
| `device_synchronize` | 14 |

**Coverage:** 20/20 adapter functions exercised = **100%**

### C API Coverage

| C API Function | Test Case(s) |
|---|---|
| `cuvsResourcesCreate` | 15, 16, 17, 18, 19, 21, 22 |
| `cuvsResourcesDestroy` | 15, 16, 17, 18, 19, 21 |
| `cuvsStreamSet` | 16 |
| `cuvsStreamGet` | 16 |
| `cuvsStreamSync` | 17 |
| `cuvsDeviceIdGet` | 18 |
| `cuvsRMMAlloc` | 19 |
| `cuvsRMMFree` | 19 |
| `cuvsVersionGet` | 20 |
| `cuvsGetLastErrorText` | 21 |
| `cuvsSetLogLevel` | 22 |
| `cuvsGetLogLevel` | 22 |

**Coverage:** 12/12 targeted C API functions exercised = **100%**

---

## Suite 3: Rename Script Tests (Phase 4)

**File:** `tools/musa/test_rename_cuvs_to_muvs.py`
**Framework:** Python `unittest`
**Dependencies:** Python 3.8+, no external packages

### P1: Content Renaming

| # | Test Case | Description | Validates |
|---|---|---|---|
| 23 | `test_include_directive_header_path` | `#include <cuvs/...>` → `#include <muvs/...>` | Header include transform |
| 24 | `test_include_directive_cpp_header` | Same for `.hpp` path | Extension-agnostic |
| 25 | `test_namespace_declaration` | `namespace cuvs::` → `namespace muvs::` | C++ namespace |
| 26 | `test_namespace_closing_comment` | `// namespace cuvs::` → `// namespace muvs::` | Comment rename |
| 27 | `test_qualified_name` | `cuvs::neighbors::` → `muvs::neighbors::` | Fully qualified name |
| 28 | `test_c_api_function_prefix` | `cuvsResourcesCreate` → `muvsResourcesCreate` | C API function |
| 29 | `test_c_api_enum_values` | `CUVS_ERROR` → `MUVS_ERROR` | Enum value |
| 30 | `test_cmake_find_package` | `find_package(cuvs)` → `find_package(muvs)` | CMake integration |
| 31 | `test_cmake_target_link` | `cuvs::cuvs` → `muvs::muvs` | CMake target |
| 32 | `test_library_name` | `libcuvs` → `libmuvs` | Library name |
| 33 | `test_python_import` | `from cuvs.` → `from muvs.` | Python import |
| 34 | `test_python_import_direct` | `import cuvs` → `import muvs` | Direct import |
| 35 | `test_macro_prefix` | `CUVS_BACKEND_TRY` → `MUVS_BACKEND_TRY` | Macro rename |
| 36 | `test_macro_ifdef` | `CUVS_BACKEND_MUSA` → `MUVS_BACKEND_MUSA` | Preprocessor |
| 37 | `test_doxygen_group` | `cuVS` → `muVS` in docs | Branding |
| 38 | `test_no_false_positive_on_cuda` | `cuda*` tokens preserved | No false rename |
| 39 | `test_no_false_positive_on_raft` | `raft` tokens preserved | No false rename |
| 40 | `test_no_false_positive_on_unrelated_words` | Regular words preserved | Precision |
| 41 | `test_preserves_cuda_backend_musa_define_value` | `CUVS_BACKEND_MUSA` → `MUVS_BACKEND_MUSA` | Macro name |
| 42 | `test_multiline_content` | Full multi-line C header rename | End-to-end content |
| 43 | `test_spdx_header_preserved` | NVIDIA copyright untouched | Copyright safety |
| 44 | `test_link_flag` | `-lcuvs` → `-lmuvs` | Linker flag |

### P1: Path Renaming

| # | Test Case | Description | Validates |
|---|---|---|---|
| 45 | `test_header_path` | `include/cuvs/` → `include/muvs/` | Include dir |
| 46 | `test_library_filename` | `libcuvs.so` → `libmuvs.so` | Library file |
| 47 | `test_c_library_filename` | `libcuvs_c.so` → `libmuvs_c.so` | C API library |
| 48 | `test_cmake_config` | `cuvs-config.cmake` → `muvs-config.cmake` | CMake config |
| 49 | `test_python_package_dir` | `python/cuvs/` → `python/muvs/` | Python pkg |
| 50 | `test_no_rename_unrelated` | `raft/core/` preserved | No false rename |

### P1: Tree Rename (Integration)

| # | Test Case | Description | Validates |
|---|---|---|---|
| 51 | `test_end_to_end_header_rename` | Rename complete header in temp tree | Full pipeline |
| 52 | `test_end_to_end_cmake_rename` | Rename CMakeLists.txt in temp tree | CMake pipeline |
| 53 | `test_end_to_end_python_rename` | Rename Python package in temp tree | Python pipeline |
| 54 | `test_binary_file_copied_unchanged` | Binary data passes through unchanged | Binary safety |

### P1: Compatibility Header

| # | Test Case | Description | Validates |
|---|---|---|---|
| 55 | `test_compat_header_content` | Generated header has `#define` mappings | Compat generation |

**Pass criteria:** All assertions pass, no false positives.

---

## Suite 4: CMake Packaging Tests (Phase 4)

**File:** `tools/musa/test_cmake_muvs_packaging.cmake`
**Framework:** CMake script mode (`cmake -P`)
**Dependencies:** CMake 3.26+

| # | Test Case | Backend | Validates |
|---|---|---|---|
| 56-61 | 6 MUSA variable assertions | MUSA | All naming vars = `muvs` |
| 62-67 | 6 CUDA variable assertions | CUDA | All naming vars = `cuvs` (regression) |

**Pass criteria:** All `assert_equal` checks pass.

---

## Defect Handling

If any test fails:

1. Record the failing test name, backend, error message, and GPU info.
2. Triage by severity (S0-S3 per test plan defect model).
3. S0/S1: block merge, fix immediately.
4. S2: file issue, can defer if feature-gated.
5. S3: backlog.

## Regression Policy

- These tests run on every PR touching `cpp/include/cuvs/core/backend/`, `cpp/cmake/modules/Configure*.cmake`, `c/include/cuvs/core/c_api*.h`, or `tools/musa/`.
- Nightly: run full CUDA + MUSA (when available) suite.
- Golden data: not applicable for adapter tests (behavior contracts only).
