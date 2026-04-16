# MUSA MVP Phase 03: C API Stream Neutralization (TDD)

## Goal

Migrate the first production-facing C API stream surface from CUDA-specific types
to backend-neutral types while preserving CUDA ABI compatibility.

## TDD Record

### Red (problem before changes)

- Public C API declared `cuvsStreamSet`/`cuvsStreamGet` with `cudaStream_t`.
- This violated the design rule that backend-specific runtime types should not
  leak through migrated public surfaces.
- Compatibility header `c_api_compat.h` mixed type aliases with function
  declarations and could not be safely reused as a pure type layer.

### Green (implementation)

1. **Type-only compatibility layer**
   - Updated `c/include/cuvs/core/c_api_compat.h` to provide only runtime type
     aliases (no function declarations).

2. **Public C API migrated to neutral stream type**
   - Updated `c/include/cuvs/core/c_api.h`:
     - include `cuvs/core/c_api_compat.h`
     - changed `cuvsStreamSet`/`cuvsStreamGet` signatures to `cuvsStream_t`
     - refreshed docs to use backend-neutral wording.

3. **Implementation signature alignment**
   - Updated `c/src/core/c_api.cpp` function signatures to `cuvsStream_t`.
   - Internal behavior remains unchanged (still mapped through RAFT resources).

4. **Test alignment**
   - Updated `c/tests/core/test_c_api_resource_lifecycle.cu` to use
     `cuvsStream_t` in the stream round-trip test.

### Refactor notes

- This phase intentionally limits scope to the stream boundary and does not yet
  migrate all cross-language binding declarations.
- ABI compatibility for CUDA consumers is preserved because `cuvsStream_t`
  aliases `cudaStream_t` on CUDA builds.

## Files Changed

- `c/include/cuvs/core/c_api_compat.h`
- `c/include/cuvs/core/c_api.h`
- `c/src/core/c_api.cpp`
- `c/tests/core/test_c_api_resource_lifecycle.cu`

## Verification

- Header-level API migration completed for stream set/get.
- C API lifecycle test updated to use the new neutral stream typedef.
- No behavior changes introduced outside type/interface migration.

## Next Step

Phase 04 should migrate binding declaration surfaces (`python`, `rust`, `go`)
from explicit `cudaStream_t` declarations to `cuvsStream_t` where applicable,
then run binding smoke tests.
