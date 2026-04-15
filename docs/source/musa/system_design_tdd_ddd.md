# MUSA Port System Design 

## Purpose

Define an implementation architecture that supports CUDA and MUSA backends with minimal API churn and test-first delivery.

## Design Principles

- Keep existing CUDA behavior as the reference implementation.
- Introduce backend abstraction at boundaries, not in domain logic.
- Deliver in small vertical slices validated by tests before expansion.
- Preserve public API contracts unless explicitly versioned.

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
- Runtime Adapter: wrapper layer for stream/memory/event operations.
- Feature Gate: compile-time or runtime switch for unsupported capability.
- MVP Vertical Slice: smallest end-to-end user-visible function with tests.

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
