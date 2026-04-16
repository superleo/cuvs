# muVS / MUSA Port Project Backlog

## Scope and Goal

This backlog tracks a staged MUSA enablement effort for cuVS, shipping under the
**muVS** product name (`muvs` package / namespace). The goal is to deliver an
initial testable MVP while preserving cuVS (CUDA) stability.

See also:
- `user_scenarios_and_migration.md` — user persona analysis and migration guide
- `system_design_tdd_ddd.md` — architecture, DDD contexts, packaging strategy

## Delivery Milestones

- M0: Baseline CUDA stays green with no regressions.
- M1: MUSA configure and compile plumbing works for a reduced target set.
- M2: Backend-neutral C API resource layer compiles and passes smoke tests.
- M3: First algorithm vertical (single-GPU brute force) builds and tests under MUSA.
- M4: muVS packaging and prefix-rename tooling produces installable muVS artifacts.
- M5: Optional Python muVS smoke path.

## Phase 0 - Baseline and Guardrails

### P0.1 - Branch and release hygiene
- [x] Create integration branch (`musa-port-docs`).
- [ ] Define merge cadence from upstream CUDA branch.
- [ ] Document rollback strategy for MUSA feature gates.

### P0.2 - Baseline observability
- [ ] Capture current CUDA build and test timings.
- [ ] Freeze a minimal benchmark of core tests for later comparison.
- [ ] Add baseline dashboard fields (build success, test pass rate, duration).

### P0.3 - Scope freeze for MVP
- [x] Mark in-scope modules: core resources, C API, brute-force ANN (single GPU).
- [x] Mark deferred modules: MG, SCANN/Vamana/CAGRA advanced paths, JIT-LTO.

## Phase 1 - Build System Backend Abstraction [DONE]

### P1.1 - Backend selector
- [x] Add `CUVS_GPU_BACKEND` CMake option (`CUDA` default, `MUSA` optional).
- [x] Validate backend option in configure step with clear error messages.

### P1.2 - Toolkit target indirection
- [x] Introduce backend-neutral alias targets (runtime, blas, solver, sparse, rand).
- [x] `cuvs_create_backend_aliases()` function implemented.

### P1.3 - Compiler and flags isolation
- [x] Split CUDA-specific flags/tooling into backend-guarded blocks.
- [x] `ConfigureCUDA.cmake` wrapped behind `CUVS_BACKEND_IS_CUDA` guard.
- [x] `cuvs_feature_gate_musa()` helper for unsupported features.

## Phase 2 - Public Surface Decoupling [DONE]

### P2.1 - C API type neutrality
- [x] Introduced `cuvsStream_t` backend-neutral typedef via `c_api_compat.h`.
- [x] Migrated `cuvsStreamSet`/`cuvsStreamGet` to `cuvsStream_t` in header, impl, and tests.
- [x] `c_api.h` now includes `c_api_compat.h` instead of `cuda_runtime.h` directly.

### P2.2 - Error and status model
- [x] `CUVS_BACKEND_TRY` and `CUVS_BACKEND_CHECK_LAST_ERROR` macros implemented.
- [x] Error mapping tests in adapter contract suite.

### P2.3 - Interop contracts
- [x] DLPack-based contracts documented (device type tag changes, layout same).
- [ ] Backend device-type semantics for MVP documented (deferred to Phase 5).

## Phase 3 - Runtime Shim and Low-Level Wrappers [DONE]

### P3.1 - Runtime wrappers
- [x] `cuvs::backend::` namespace with stream, memory, event, device, error wrappers.
- [x] `types.hpp`, `runtime.hpp`, `macros.hpp` headers delivered.

### P3.2 - Macro adaptation
- [x] `CUVS_BACKEND_TRY` routes through backend wrappers.
- [x] Compile-time backend selection via `CUVS_BACKEND_MUSA` define.

### P3.3 - Touchpoint migration
- [x] C API stream surface migrated.
- [ ] Brute-force vertical migration (Phase 5).

## Phase 4 - muVS Packaging and Prefix Rename [DONE]

### P4.1 - Build-time rename tooling
- [x] Implement `rename_cuvs_to_muvs.py` script for header/source/cmake rename.
- [x] Add 33-case test suite validating rename correctness on representative files.

### P4.2 - Compatibility header
- [x] Create `muvs/compat/cuvs_compat.h` mapping 25 `cuvs*` symbols to `muvs*`.
- [x] Test via `TestCompatHeader` that header contains expected `#define` mappings.

### P4.3 - CMake muVS output names
- [x] Add `ConfigureMusvPackaging.cmake` that sets muVS library/target names.
- [x] CMake script-mode test validates both MUSA and CUDA packaging variables.

### P4.4 - User documentation
- [x] Updated migration guide with concrete rename and compat header examples.
- [x] Added quick-start section for building muVS from source.
- [x] TDD record: `docs/source/musa/phase_04_tdd_muvs_packaging.md`.

## Phase 5 - MVP Vertical: Single-GPU Brute Force

### P5.1 - Core algorithm path
- [ ] Compile brute-force index and search path end-to-end.
- [ ] Verify deterministic behavior on small fixed datasets.

### P5.2 - C API path
- [ ] Expose brute-force build/search through C API.
- [ ] Add smoke tests covering resource lifecycle plus one query flow.

### P5.3 - CI target
- [ ] Add one MUSA CI job for MVP subset.
- [ ] Keep CUDA CI required; MUSA CI can begin as non-blocking until stable.

## Phase 6 - Dependency Viability for MVP

### P6.1 - Library mapping
- [ ] Map required CUDA libraries in MVP path to MUSA equivalents.
- [ ] Gate unsupported dependencies behind feature flags.

### P6.2 - RAPIDS stack touchpoints
- [ ] Assess RAFT/RMM interaction points used by MVP only.
- [ ] Create temporary compatibility adapters if direct support is unavailable.

### P6.3 - Link closure
- [ ] Verify static/shared link for `libmuvs` MVP target under MUSA mode.
- [ ] Add clear compile-time diagnostics for unsupported modules.

## Phase 7 - Optional Python muVS

### P7.1 - Packaging gates
- [ ] Build `muvs` Python wheel from same source with prefix rename.
- [ ] Gate advanced Python features not yet available on MUSA.

### P7.2 - Python smoke
- [ ] `pip install muvs` + `from muvs.neighbors import brute_force` smoke test.

## Phase 8 - Post-MVP Expansion

### P8.1 - Module expansion order
- [ ] Distance/cluster low-risk paths.
- [ ] Additional neighbors modules.
- [ ] Advanced ANN (SCANN, Vamana, CAGRA).
- [ ] Multi-GPU and NCCL-dependent features.

### P8.2 - Hardening
- [ ] Convert MUSA CI from non-blocking to required for supported subset.
- [ ] Add performance parity goals and tracking.

## Risk Register (Top Items)

- Dependency compatibility gaps (RAFT/RMM/CUTLASS/CUB/Thrust/NCCL equivalents).
- Build toolchain assumptions that are CUDA-only.
- Hidden CUDA types leaking through public headers and bindings.
- Scope creep into advanced modules before MVP closure.
- Prefix rename correctness across all languages and build artifacts.

## Definition of Done (MVP)

- `CUVS_GPU_BACKEND=MUSA` configures and builds selected `libmuvs` targets.
- Core C API resource lifecycle smoke tests pass under muVS names.
- Brute-force single-GPU tests pass for a curated deterministic subset.
- CUDA default build remains green (cuVS unchanged).
- `rename_cuvs_to_muvs.py` produces valid muVS headers that compile.
- Compatibility header maps `cuvs*` to `muvs*` correctly.
