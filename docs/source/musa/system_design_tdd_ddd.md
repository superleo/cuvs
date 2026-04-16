# MUSA Port System Design 

## Purpose

Define an implementation architecture that supports CUDA and MUSA backends with minimal API churn and test-first delivery, while providing a clear migration path for every user persona.

## User-Facing Strategy

The full user-scenario analysis and migration guide lives in:
`docs/source/musa/user_scenarios_and_migration.md`

Key decisions that shape the system design:

- **Separate package identity**: the MUSA build ships as **muVS** (`muvs` package,
  `muvs::` namespace, `#include <muvs/...>`) to avoid confusion with cuVS on
  NVIDIA hardware.
- **Same source tree**: muVS is a build configuration of the cuVS repository, not a
  fork. The `CUVS_GPU_BACKEND` flag selects the backend at compile time.
- **Mechanical migration for users**: switching from cuVS to muVS is a prefix rename
  (`cuvs` → `muvs`, `cuda` → `musa`) plus relinking. Algorithm APIs, parameter
  semantics, and data formats are identical.
- **No mixed-backend process**: cuVS and muVS cannot coexist in one process. Users
  pick one per deployment.

## Design Principles

- Keep existing CUDA behavior as the reference implementation.
- Introduce backend abstraction at boundaries, not in domain logic.
- Deliver in small vertical slices validated by tests before expansion.
- Preserve public API contracts unless explicitly versioned.
- Ship muVS as a distinct package so CUDA users see zero change.

## DDD Framing

## Bounded Contexts

### 1) API Boundary Context
- Concern: stable C/C++/binding contracts and error model.
- Artifacts: public headers, C API handles, status codes.
- Rule: no backend-specific runtime types in public contracts.

### 2) Execution Backend Context
- Concern: stream, memory, event, and runtime call mechanics.
- Artifacts: backend wrappers, adapter interfaces, macro bridges.
- Rule: only this context knows raw backend runtime names.

### 3) Algorithm Domain Context
- Concern: ANN and distance/cluster domain logic and kernels.
- Artifacts: brute-force and later algorithm families.
- Rule: algorithms depend on abstractions from Execution Backend context.

### 4) Integration Context
- Concern: CMake, packaging, CI, and language bindings.
- Artifacts: backend selection, target mapping, test matrix.
- Rule: unsupported capabilities are feature-gated and explicit.

## Ubiquitous Language

- Backend: GPU runtime family (`CUDA` or `MUSA`).
- cuVS: the CUDA-backend build, shipped under the `cuvs` name.
- muVS: the MUSA-backend build, shipped under the `muvs` name.
- Runtime Adapter: wrapper layer for stream/memory/event operations.
- Feature Gate: compile-time or runtime switch for unsupported capability.
- MVP Vertical Slice: smallest end-to-end user-visible function with tests.
- Prefix Rename: the mechanical `cuvs` → `muvs` transformation applied to
  headers, namespaces, symbols, and package names during MUSA build.

## Target Architecture

## Layered Overview

1. Public APIs (C++ and C) call domain services.
2. Domain services request execution resources through backend-neutral interfaces.
3. Runtime adapter resolves to CUDA or MUSA concrete implementation.
4. Build and packaging choose backend and available features.

## Core Interfaces (Conceptual)

- `GpuRuntime`: stream/event lifecycle, memory operations, synchronization.
- `GpuBlas` / `GpuSolver` (optional by module): math library bridge.
- `ResourceContext`: backend-neutral resource owner used by C API and C++ entry points.

Concrete adapters:
- `CudaRuntimeAdapter`
- `MusaRuntimeAdapter`

## Dependency Direction

- Domain code -> interfaces only.
- Adapters -> vendor runtimes and toolkit libraries.
- Public API layer -> domain services and resource abstractions.
- Build system wires concrete adapter based on selected backend.

## Test Strategy

## Test Pyramid for Porting

### Unit tests
- Runtime adapter contract tests (stream/memory/event semantics).
- Error mapping tests (backend errors -> cuVS status codes).

### Component tests
- C API resource lifecycle tests through real adapter.
- Brute-force build/search component tests on fixed input.

### Integration tests
- Build/link tests for selected targets under `CUDA` and `MUSA`.
- End-to-end smoke tests from public API boundary.

## Red-Green-Refactor Workflow

1. **Red**: write failing test for one thin behavior (for example stream sync wrapper).
2. **Green**: implement minimal adapter behavior for selected backend.
3. **Refactor**: remove duplication and improve abstractions while tests stay green.

## Contract-First Tests (must exist before broad migration)

- Adapter contract tests for:
  - stream create/sync/destroy
  - device memory alloc/free
  - memcpy host<->device and device<->device
  - basic event record/sync
- C API contract tests for:
  - resource create/destroy
  - stream set/get semantics
  - deterministic brute-force query flow in MVP

## Migration Pattern (per module)

1. Add or expand tests for expected behavior.
2. Introduce backend-neutral interface usage in module.
3. Move direct runtime calls behind adapter.
4. Keep feature-gated fallback for unsupported paths.
5. Run dual-backend test subset; merge only if both pass required gates.

## Packaging Architecture

### Build-time output mapping

When `CUVS_GPU_BACKEND=MUSA`:
- Library: `libmuvs.so` / `libmuvs_c.so`
- Headers installed under: `include/muvs/`
- Python package: `muvs`
- CMake export: `find_package(muvs)`
- C API prefix: `muvs*` / `MUVS_*`
- C++ namespace: `muvs::`

When `CUVS_GPU_BACKEND=CUDA` (default, unchanged):
- Library: `libcuvs.so` / `libcuvs_c.so`
- Headers installed under: `include/cuvs/`
- Python package: `cuvs`
- CMake export: `find_package(cuvs)`
- C API prefix: `cuvs*` / `CUVS_*`
- C++ namespace: `cuvs::`

### Implementation strategy for prefix rename

The rename is applied at build/packaging time, not in source:
1. Source continues to use `cuvs` names as the canonical spelling.
2. A build-time transform (CMake configure_file or script) generates `muvs`
   headers, library names, and Python package wrappers from the same source.
3. This avoids source-level duplication and keeps a single codebase.

## Non-Goals (MVP)

- Full feature parity across all ANN algorithms.
- Multi-GPU support.
- Performance parity guarantees.
- Rewriting all bindings in phase one.

## Architectural Decisions (ADRs to record)

- ADR-001: Backend selection mechanism and default behavior.
- ADR-002: Public C API type neutrality policy.
- ADR-003: Runtime adapter interface surface and error model.
- ADR-004: Feature-gate policy for unsupported modules.
- ADR-005: CI gating policy for CUDA and MUSA.
- ADR-006: Separate package identity (muVS) for MUSA builds.
- ADR-007: Build-time prefix rename strategy (source stays `cuvs`, output `muvs`).

## MVP System Boundaries

Included:
- Core resource management.
- Single-GPU brute-force ANN path.
- Minimal C API coverage and smoke tests.

Excluded:
- Advanced ANN modules.
- Multi-GPU paths.
- CUDA-specific JIT/LTO optimizations.

## Observability and Quality Gates

- Build gates:
  - CUDA full baseline remains required.
  - MUSA MVP subset required once stable.
- Test gates:
  - Adapter contract tests required.
  - MVP brute-force deterministic tests required.
- Quality gates:
  - No backend-specific types in public C API for migrated surfaces.
  - New module migrations require tests added first (TDD enforcement).
