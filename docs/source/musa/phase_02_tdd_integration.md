# MUSA MVP Phase 02 Integration (TDD)

## Scope

This phase implements the **integration wiring** described in the MVP system design:

- wire backend selection into top-level and C API CMake
- register the new contract tests into build targets
- keep CUDA behavior unchanged
- keep MUSA path feature-gated so configure succeeds without full toolkit integration

## TDD Execution Record

### Red

Expected failures before integration:

1. New adapter test source was not registered in `cpp/tests/CMakeLists.txt`.
2. New C API lifecycle test source was not registered in `c/tests/CMakeLists.txt`.
3. Build scripts did not import `ConfigureBackend.cmake`, so `CUVS_GPU_BACKEND` had no effect.
4. C API tests always linked `CUDA::cudart`, which is not backend-gated.

### Green

Implemented wiring changes:

1. **Backend CMake integrated in C++ build**
   - `cpp/CMakeLists.txt`
   - Added `include(cmake/modules/ConfigureBackend.cmake)` early.
   - CUDA language/toolkit initialization now runs only when `CUVS_BACKEND_IS_CUDA`.
   - Added `cuvs_create_backend_aliases()` after backend/cuda flag setup.
   - MUSA phase gate currently forces `BUILD_CPU_ONLY=ON` to keep configure path stable.

2. **Backend CMake integrated in C API build**
   - `c/CMakeLists.txt`
   - Added `include(../cpp/cmake/modules/ConfigureBackend.cmake)`.
   - Guarded `ConfigureCUDA.cmake` include behind `CUVS_BACKEND_IS_CUDA`.
   - Guarded CUDA language enablement in tests behind `CUVS_BACKEND_IS_CUDA`.
   - MUSA phase gate currently forces `BUILD_TESTS=OFF` in C API project.

3. **Registered new contract tests**
   - `cpp/tests/CMakeLists.txt`
     - Added `BACKEND_ADAPTER_TEST` target for `core/backend/test_runtime_adapter.cu`.
   - `c/tests/CMakeLists.txt`
     - Added `C_API_LIFECYCLE_TEST` target for `core/test_c_api_resource_lifecycle.cu`.
     - Guarded `CUDA::cudart` linkage for `cuvs_c_test` behind `CUVS_BACKEND_IS_CUDA`.

4. **Compile fix in backend macro header**
   - `cpp/include/cuvs/core/backend/macros.hpp`
   - Added missing `#include <stdexcept>` for thrown `std::runtime_error`.

### Refactor

- No functional refactor beyond integration wiring in this phase.
- The phase intentionally keeps behavior additive and low-risk.

## Files Changed

- `cpp/CMakeLists.txt`
- `c/CMakeLists.txt`
- `cpp/tests/CMakeLists.txt`
- `c/tests/CMakeLists.txt`
- `cpp/include/cuvs/core/backend/macros.hpp`
- `docs/source/musa/phase_02_tdd_integration.md` (this log)

## Verification Checklist

- [x] Backend selector included by both C++ and C API CMake entrypoints
- [x] CUDA-only setup guarded by backend selection
- [x] New adapter test target registered
- [x] New C API lifecycle test target registered
- [x] CUDA-only link in C tests guarded
- [x] Markdown implementation record added

## Next Phase Candidate

Phase 03 should migrate the first production call sites (resource/stream helpers) from direct CUDA symbols to the new backend adapter interfaces, then run the new contract tests as merge gates.
