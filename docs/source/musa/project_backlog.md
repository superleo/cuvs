# MUSA Port Project Backlog

## Scope and Goal

This backlog tracks a staged MUSA enablement effort for cuVS with the goal of delivering an initial, testable MVP while preserving CUDA stability.

## Delivery Milestones

- M0: Baseline CUDA stays green with no regressions.
- M1: MUSA configure and compile plumbing works for a reduced target set.
- M2: Backend-neutral C API resource layer compiles and passes smoke tests.
- M3: First algorithm vertical (single-GPU brute force) builds and tests under MUSA.
- M4: Optional Python MVP smoke path.

## Backlog by Phase (Critical Path Ordered)

## Phase 0 - Baseline and Guardrails

### P0.1 - Branch and release hygiene
- [ ] Create and protect long-lived integration branch (`musa-port/main`).
- [ ] Define merge cadence from upstream CUDA branch.
- [ ] Document rollback strategy for MUSA feature gates.

### P0.2 - Baseline observability
- [ ] Capture current CUDA build and test timings.
- [ ] Freeze a minimal benchmark of core tests for later comparison.
- [ ] Add baseline dashboard fields (build success, test pass rate, duration).

### P0.3 - Scope freeze for MVP
- [ ] Mark in-scope modules: core resources, C API, brute-force ANN (single GPU).
- [ ] Mark deferred modules: MG, SCANN/Vamana/CAGRA advanced paths, JIT-LTO.

## Phase 1 - Build System Backend Abstraction

### P1.1 - Backend selector
- [ ] Add `CUVS_GPU_BACKEND` CMake option (`CUDA` default, `MUSA` optional).
- [ ] Validate backend option in configure step with clear error messages.

### P1.2 - Toolkit target indirection
- [ ] Introduce backend-neutral alias targets (runtime, blas, solver, sparse, rand).
- [ ] Replace direct `CUDA::...` usage in top-level linkage with aliases.

### P1.3 - Compiler and flags isolation
- [ ] Split CUDA-specific flags/tooling into backend-guarded blocks.
- [ ] Disable unsupported CUDA-only features under MUSA (for example nvJitLink flow).

## Phase 2 - Public Surface Decoupling

### P2.1 - C API type neutrality
- [ ] Remove direct CUDA type exposure from public C headers.
- [ ] Introduce opaque stream/resource types where needed.

### P2.2 - Error and status model
- [ ] Define backend-neutral error translation in C API boundary.
- [ ] Ensure all backend runtime failures map to existing cuVS C errors.

### P2.3 - Interop contracts
- [ ] Keep DLPack-based contracts unchanged where possible.
- [ ] Document backend device-type semantics for MVP.

## Phase 3 - Runtime Shim and Low-Level Wrappers

### P3.1 - Runtime wrappers
- [ ] Add wrappers for stream lifecycle, memory alloc/free, and memcpy sync/async.
- [ ] Add wrapper for event create/record/sync/destroy as needed by MVP path.

### P3.2 - Macro adaptation
- [ ] Route CUDA try/check macros through backend wrappers in MVP modules.
- [ ] Ensure compile-time backend selection prevents mixed runtime calls.

### P3.3 - Touchpoint migration
- [ ] Migrate only the files required by brute-force vertical and core tests first.
- [ ] Defer broad mechanical replacements until MVP passes.

## Phase 4 - Dependency Viability for MVP

### P4.1 - Library mapping
- [ ] Map required CUDA libraries in MVP path to MUSA equivalents.
- [ ] Gate unsupported dependencies behind feature flags.

### P4.2 - RAPIDS stack touchpoints
- [ ] Assess RAFT/RMM interaction points used by MVP only.
- [ ] Create temporary compatibility adapters if direct support is unavailable.

### P4.3 - Link closure
- [ ] Verify static/shared link for `libcuvs` MVP target under MUSA mode.
- [ ] Add clear compile-time diagnostics for unsupported modules.

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

## Phase 6 - Optional Python MVP

### P6.1 - Packaging gates
- [ ] Remove CUDA-only packaging assumptions from MVP wheel path.
- [ ] Gate advanced Python features not yet available on MUSA.

### P6.2 - Python smoke
- [ ] Add import + brute-force query smoke test in MUSA environment.

## Phase 7 - Post-MVP Expansion

### P7.1 - Module expansion order
- [ ] Distance/cluster low-risk paths.
- [ ] Additional neighbors modules.
- [ ] Advanced ANN (SCANN, Vamana, CAGRA).
- [ ] Multi-GPU and NCCL-dependent features.

### P7.2 - Hardening
- [ ] Convert MUSA CI from non-blocking to required for supported subset.
- [ ] Add performance parity goals and tracking.

## Risk Register (Top Items)

- Dependency compatibility gaps (RAFT/RMM/CUTLASS/CUB/Thrust/NCCL equivalents).
- Build toolchain assumptions that are CUDA-only.
- Hidden CUDA types leaking through public headers and bindings.
- Scope creep into advanced modules before MVP closure.

## Definition of Done (MVP)

- `CUVS_GPU_BACKEND=MUSA` configures and builds selected `libcuvs` targets.
- Core C API resource lifecycle smoke tests pass.
- Brute-force single-GPU tests pass for a curated deterministic subset.
- CUDA default build remains green.
