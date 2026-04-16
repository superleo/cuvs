# MUSA Port MVP Implementation Guide

## Overview

This document describes the concrete implementation of the cuVS MUSA backend MVP as designed in the system design doc. It covers every new and modified file, explains design rationale, and maps each change to the DDD bounded contexts and TDD contract tests.

## Bounded Context Map (implementation view)

| Bounded Context | Artifacts Delivered | Location |
|---|---|---|
| Integration | `ConfigureBackend.cmake` | `cpp/cmake/modules/` |
| Execution Backend | `types.hpp`, `runtime.hpp`, `macros.hpp` | `cpp/include/cuvs/core/backend/` |
| API Boundary | `c_api_compat.h` | `c/include/cuvs/core/` |
| Algorithm Domain | (no changes in MVP) | — |

## File Inventory

### New Files

| File | Purpose | Context |
|---|---|---|
| `cpp/cmake/modules/ConfigureBackend.cmake` | CMake backend selector, alias targets, feature gates | Integration |
| `cpp/include/cuvs/core/backend/types.hpp` | Backend-neutral type aliases (`cuvsStream_t`, `cuvsRtError_t`, `cuvsEvent_t`) | Execution Backend |
| `cpp/include/cuvs/core/backend/runtime.hpp` | Inline wrapper functions for stream/memory/event/device ops | Execution Backend |
| `cpp/include/cuvs/core/backend/macros.hpp` | `CUVS_BACKEND_TRY` and `CUVS_BACKEND_CHECK_LAST_ERROR` macros | Execution Backend |
| `c/include/cuvs/core/c_api_compat.h` | Backend-neutral `cuvsStream_t` typedef for C consumers | API Boundary |
| `cpp/tests/core/backend/test_runtime_adapter.cu` | Adapter contract tests (L2 from test plan) | Test |
| `c/tests/core/test_c_api_resource_lifecycle.cu` | C API lifecycle smoke tests (L3 from test plan) | Test |

### Existing Files to Modify (integration steps, not done in MVP scaffold)

These modifications are documented here for the integration phase. The MVP scaffold delivers only the new files above; wiring them into the existing CMake and source happens during integration.

| File | Change Required |
|---|---|
| `cpp/CMakeLists.txt` | `include(cmake/modules/ConfigureBackend.cmake)` before `ConfigureCUDA.cmake`; guard CUDA toolkit init behind `CUVS_BACKEND_IS_CUDA`; call `cuvs_create_backend_aliases()` after toolkit discovery |
| `cpp/cmake/modules/ConfigureCUDA.cmake` | Wrap entire body in `if(CUVS_BACKEND_IS_CUDA)` guard |
| `cpp/tests/CMakeLists.txt` | Add `ConfigureTest(NAME BACKEND_ADAPTER_TEST PATH core/backend/test_runtime_adapter.cu)` |
| `c/tests/CMakeLists.txt` | Add `ConfigureTest(NAME C_API_LIFECYCLE_TEST PATH core/test_c_api_resource_lifecycle.cu)` |
| `c/CMakeLists.txt` | In test section, guard `enable_language(CUDA)` with backend check |

## Detailed Design Decisions

### 1. ConfigureBackend.cmake

**ADR-001 implementation.** Introduces `CUVS_GPU_BACKEND` as a cache variable defaulting to `CUDA`. Sets boolean helpers `CUVS_BACKEND_IS_CUDA` / `CUVS_BACKEND_IS_MUSA` for use in generator expressions and `if()` guards throughout the build.

**Target aliases.** The function `cuvs_create_backend_aliases()` creates `INTERFACE` library targets with backend-neutral names:

- `cuvs_backend::runtime` -> `CUDA::cudart` (or future `MUSA::musart`)
- `cuvs_backend::blas` -> `CUDA::cublas[_static]`
- `cuvs_backend::solver` -> `CUDA::cusolver[_static]`
- `cuvs_backend::sparse` -> `CUDA::cusparse[_static]`
- `cuvs_backend::rand` -> `CUDA::curand[_static]`

Under MUSA the stubs are empty `INTERFACE` targets. Real linkage is added once MUSA toolkit CMake support lands.

**Feature gates.** `cuvs_feature_gate_musa(<name>)` sets `<name>_AVAILABLE` to `OFF` on MUSA with an informational log. Use for JIT-LTO, NVTX, and advanced algorithm modules.

### 2. Backend Type Aliases (types.hpp)

Compile-time switch on `CUVS_BACKEND_MUSA` define. When defined, includes `<musa_runtime.h>` and typedefs to MUSA types. Otherwise includes `<cuda_runtime.h>` and typedefs to CUDA types.

Three types are aliased:

- `cuvsStream_t` — stream handle
- `cuvsRtError_t` — runtime error code
- `cuvsEvent_t` — event handle

### 3. Runtime Adapter (runtime.hpp)

Provides `cuvs::backend::` namespace functions covering the five contract categories:

| Category | Functions |
|---|---|
| Stream | `stream_create`, `stream_create_non_blocking`, `stream_synchronize`, `stream_destroy` |
| Memory | `device_malloc`, `device_free` |
| Memcpy | `memcpy_sync`, `memcpy_async` (with `memcpy_kind` enum) |
| Event | `event_create`, `event_record`, `event_synchronize`, `event_destroy` |
| Device | `get_device`, `set_device`, `device_synchronize` |
| Error | `get_error_string`, `get_last_error`, `rt_success` constant |

Each function is an inline wrapper that branches on `CUVS_BACKEND_MUSA` at compile time (zero runtime overhead). The MUSA paths call `musa*` equivalents with identical signatures.

### 4. Error Macros (macros.hpp)

Two macros for migration convenience:

- `CUVS_BACKEND_TRY(call)` — checks return code, throws `std::runtime_error` with backend error string on failure.
- `CUVS_BACKEND_CHECK_LAST_ERROR()` — checks sticky error state via `get_last_error()`.

These replace direct `RAFT_CUDA_TRY` and `CHECK_CUDA` calls in migrated modules. Existing RAFT macros remain for code not yet migrated.

### 5. C API Compatibility Header (c_api_compat.h)

Provides a `cuvsStream_t` typedef for C consumers that resolves to `cudaStream_t` or `musaStream_t`. New C code targeting both backends should include this header instead of `cuda_runtime.h`.

The original `c_api.h` is **not modified** in the MVP to preserve backward compatibility. Future phases will migrate `c_api.h` to use `c_api_compat.h` typedefs directly.

### 6. Contract Tests (test_runtime_adapter.cu)

Maps directly to test plan L2 suites:

| Test Plan ID | Test Class | Cases |
|---|---|---|
| R1: Stream | `StreamContractTest` | `CreateSyncDestroy`, `CreateNonBlocking`, `RepeatedCreateDestroy` |
| R2: Memory | `MemoryContractTest` | `AllocFree`, `HostToDeviceToHost`, `DeviceToDevice`, `AsyncCopyWithSync` |
| R3: Event | `EventContractTest` | `CreateRecordSyncDestroy`, `EventOrderingGuarantee` |
| R4: Error | `ErrorMappingTest` | `SuccessConstant`, `ErrorStringNonNull`, `InvalidFreeReturnsError` |
| Device | `DeviceManagementTest` | `GetDevice`, `DeviceSynchronize` |

### 7. C API Lifecycle Tests (test_c_api_resource_lifecycle.cu)

Maps to test plan L3-C1:

| Test Case | What It Validates |
|---|---|
| `CreateAndDestroy` | Basic resource lifecycle |
| `SetGetStream` | Stream set/get round-trip |
| `StreamSync` | Synchronization through C API |
| `GetDeviceId` | Device ID query |
| `RMMAllocAndFree` | Device memory allocation via RMM |
| `VersionGet` | Version query non-zero |
| `ErrorTextClearOnSuccess` | Error text is NULL after success |
| `LogLevelRoundTrip` | Log level set/get consistency |

## Migration Pattern (for future modules)

When migrating an existing module from raw CUDA to backend-neutral:

1. **Add test first** (TDD red): write a failing test that uses `cuvs::backend::` functions or `CUVS_BACKEND_TRY` for the behavior you need.
2. **Replace direct calls** (TDD green): swap `cudaStreamCreate` -> `cuvs::backend::stream_create` etc. in the source file.
3. **Refactor**: extract common patterns, remove duplication.
4. **Verify**: both CUDA and MUSA (when available) tests pass.

## Build Integration Sequence

To wire the MVP into the existing build (done during integration, not scaffold):

```bash
# 1. Configure with CUDA (default, no change)
cmake -S cpp -B build-cuda

# 2. Configure with MUSA (MVP scaffold mode)
cmake -S cpp -B build-musa -DCUVS_GPU_BACKEND=MUSA

# 3. Build adapter tests only (when test targets are registered)
cmake --build build-cuda --target BACKEND_ADAPTER_TEST

# 4. Run adapter contract tests
ctest --test-dir build-cuda --output-on-failure -R "BACKEND_ADAPTER_TEST"

# 5. Run C API lifecycle tests
ctest --test-dir build-cuda --output-on-failure -R "C_API_LIFECYCLE_TEST"
```

## Acceptance Criteria Traceability

| MVP Criterion | Delivered By |
|---|---|
| `CUVS_GPU_BACKEND=MUSA` accepted in configure | `ConfigureBackend.cmake` validation logic |
| Backend-neutral types compile | `types.hpp` + `runtime.hpp` under both defines |
| Adapter contract tests pass | `test_runtime_adapter.cu` (16 test cases) |
| C API lifecycle tests pass | `test_c_api_resource_lifecycle.cu` (8 test cases) |
| No CUDA types in new public headers | `c_api_compat.h` uses `cuvsStream_t` |
| CUDA default unchanged | All new code is additive; no existing file modified |

## Phase 02 Integration Update

The next phase (integration wiring in TDD) is implemented and recorded in:

- `docs/source/musa/phase_02_tdd_integration.md`

That phase integrates backend-aware CMake guards, registers the two new contract test targets, and documents red/green/refactor steps plus verification outcomes.

## User Scenarios and Migration Guide

A comprehensive user-scenario analysis covering all personas (Python end-user,
C/C++ developer, Rust/Go/Java binding user, build-from-source integrator) and
the separate-package (muVS) strategy is documented in:

- `docs/source/musa/user_scenarios_and_migration.md`

The system design doc has been updated to reference this strategy and include
packaging architecture decisions (ADR-006, ADR-007).

## Phase 03 Stream API Update

The next phase after integration (C API stream neutralization in TDD) is implemented and recorded in:

- `docs/source/musa/phase_03_tdd_c_api_stream_neutralization.md`

That phase migrates the public C API stream set/get boundary from `cudaStream_t` to
backend-neutral `cuvsStream_t`, aligns implementation signatures, and updates lifecycle tests.
