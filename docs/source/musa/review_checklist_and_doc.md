# MUSA Port MVP Review Checklist and Review Document

## Purpose

This document serves as both a review checklist for PR reviewers and a standing review record. Each section has acceptance criteria and a reviewer sign-off field.

---

## Part 1: Review Checklist

### A. Build System (ConfigureBackend.cmake)

- [ ] `CUVS_GPU_BACKEND` cache variable defaults to `CUDA`.
- [ ] Invalid backend value produces a `FATAL_ERROR` with actionable message.
- [ ] `CUVS_BACKEND_IS_CUDA` / `CUVS_BACKEND_IS_MUSA` booleans are correctly set.
- [ ] `cuvs_create_backend_aliases()` creates all five backend-neutral alias targets.
- [ ] CUDA alias targets link to correct `CUDA::` imported targets (with `_static` suffix passthrough).
- [ ] MUSA alias targets are empty `INTERFACE` stubs with TODO comments.
- [ ] `cuvs_feature_gate_musa()` sets `<name>_AVAILABLE` to OFF on MUSA with `STATUS` message.
- [ ] No existing CMake files are modified (additive only in MVP scaffold).

### B. Backend Type Aliases (types.hpp)

- [ ] `#if defined(CUVS_BACKEND_MUSA)` branches to MUSA includes and types.
- [ ] Default (`#else`) resolves to CUDA includes and types.
- [ ] Three types aliased: `cuvsStream_t`, `cuvsRtError_t`, `cuvsEvent_t`.
- [ ] No other headers included beyond the selected runtime header.

### C. Runtime Adapter (runtime.hpp)

- [ ] All functions are in `cuvs::backend` namespace.
- [ ] All functions are `inline` (header-only, zero link overhead).
- [ ] Each function has both CUDA and MUSA branches.
- [ ] `memcpy_kind` enum maps correctly to native enum values on both branches.
- [ ] `rt_success` constexpr constant matches `cudaSuccess` / `musaSuccess`.
- [ ] Stream, memory, memcpy, event, device, and error categories all covered.
- [ ] No raw `cuda*` or `musa*` calls leak outside `#if` blocks.

### D. Error Macros (macros.hpp)

- [ ] `CUVS_BACKEND_TRY` checks against `rt_success` and throws on failure.
- [ ] `CUVS_BACKEND_CHECK_LAST_ERROR` calls `get_last_error()` and throws if non-success.
- [ ] Both macros include file and line in error output.
- [ ] `#include` of `runtime.hpp` is present (no missing dependency).

### E. C API Compatibility (c_api_compat.h)

- [ ] `cuvsStream_t` typedef resolves to `cudaStream_t` or `musaStream_t`.
- [ ] Header does not modify or redefine anything from `c_api.h`.
- [ ] Proper `extern "C"` guards for C++ compilation.
- [ ] SPDX license header present.

### F. Contract Tests (test_runtime_adapter.cu)

- [ ] Test classes map to test plan L2 suites (R1-R4).
- [ ] Stream: create/sync/destroy, non-blocking, repeated lifecycle.
- [ ] Memory: alloc/free, H2D/D2H round-trip, D2D copy, async with sync.
- [ ] Event: create/record/sync/destroy, ordering guarantee.
- [ ] Error: success constant, error string, invalid-free detection.
- [ ] Device: get_device, device_synchronize.
- [ ] All tests use `CUVS_BACKEND_TRY` (eating own dogfood).
- [ ] No raw `cuda*` calls outside the adapter layer.

### G. C API Lifecycle Tests (test_c_api_resource_lifecycle.cu)

- [ ] Tests map to test plan L3-C1.
- [ ] Resource create/destroy tested.
- [ ] Stream set/get round-trip tested.
- [ ] Stream sync tested.
- [ ] Device ID query tested.
- [ ] RMM alloc/free tested.
- [ ] Version get tested.
- [ ] Error text cleared on success tested.
- [ ] Log level round-trip tested.

### H. Documentation

- [ ] Implementation doc (`implementation.md`) covers all new files with rationale.
- [ ] Test document (`test_document.md`) maps every test case to plan IDs.
- [ ] Review checklist (`review_checklist_and_doc.md` — this file) is complete.
- [ ] Backlog updated with checklist items marked if completed.

### I. Code Quality

- [ ] No compiler warnings introduced.
- [ ] No CUDA-specific types in any new public header except gated `#if`.
- [ ] Consistent code style with existing cuVS conventions.
- [ ] SPDX headers on all new files.
- [ ] No debug prints or temporary hacks left in.

---

## Part 2: Review Document

### 2.1 Scope of Review

This review covers the MVP scaffold delivery for MUSA backend enablement:

- 7 new files (3 backend headers, 1 CMake module, 1 C API compat header, 2 test files)
- 3 documentation files (implementation, test document, this review doc)
- 0 existing files modified

### 2.2 Design Alignment

| Design Doc Requirement | Implementation Status |
|---|---|
| Backend selection via CMake option | Delivered in `ConfigureBackend.cmake` |
| Backend-neutral runtime adapter | Delivered in `types.hpp` + `runtime.hpp` + `macros.hpp` |
| No backend types in public API | Delivered via `c_api_compat.h`; original `c_api.h` unchanged |
| Contract-first TDD | Tests delivered before integration wiring |
| DDD bounded context separation | Each file maps to exactly one context |
| Feature gating for unsupported modules | `cuvs_feature_gate_musa()` helper delivered |

### 2.3 Risk Assessment

| Risk | Mitigation | Status |
|---|---|---|
| MUSA runtime headers unavailable | Code compiles under CUDA default; MUSA paths are compile-gated | Mitigated |
| Breaking existing CUDA build | All changes are additive; no existing file modified | Mitigated |
| Incomplete adapter coverage | MVP covers only the five contract categories; future phases extend | Accepted |
| RAFT/RMM not ported to MUSA | C API tests use existing RAFT/RMM under CUDA; MUSA adapter tests use only raw runtime | Accepted |

### 2.4 Open Items for Follow-Up

1. Wire `ConfigureBackend.cmake` into `cpp/CMakeLists.txt` and guard existing CUDA blocks.
2. Register test targets in `cpp/tests/CMakeLists.txt` and `c/tests/CMakeLists.txt`.
3. Migrate brute-force vertical to use `cuvs::backend::` wrappers.
4. Add MUSA CI job (non-blocking) once MUSA toolkit is available.
5. Migrate `c_api.h` stream APIs to use `cuvsStream_t` from `c_api_compat.h`.

### 2.5 Reviewer Sign-Off

| Reviewer | Area | Date | Status |
|---|---|---|---|
| ___________ | Build System | ____-__-__ | [ ] Approved / [ ] Changes Requested |
| ___________ | Backend Adapter | ____-__-__ | [ ] Approved / [ ] Changes Requested |
| ___________ | C API | ____-__-__ | [ ] Approved / [ ] Changes Requested |
| ___________ | Tests | ____-__-__ | [ ] Approved / [ ] Changes Requested |
| ___________ | Documentation | ____-__-__ | [ ] Approved / [ ] Changes Requested |
