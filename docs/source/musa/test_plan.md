# MUSA Port Test Plan

## Objective

Validate a safe and incremental CUDA-to-MUSA port with a first successful build+test milestone, while protecting existing CUDA behavior.

## Test Scope

In scope for MVP:
- Build/configure in MUSA backend mode for selected targets.
- Core resource and runtime adapter contracts.
- Single-GPU brute-force index/search path.
- C API smoke path for resource lifecycle and one query flow.

Out of scope for MVP:
- Advanced ANN algorithms and multi-GPU features.
- Performance parity and large benchmark suites.
- Full language binding parity.

## Test Environments

- E1: CUDA reference environment (existing baseline).
- E2: MUSA development environment (MVP subset).

Each PR should run:
- CUDA baseline required.
- MUSA MVP suite required once MUSA lane becomes stable (can start non-blocking).

## Test Levels and Suites

## L1 - Configure/Build Validation

### B1: Backend option validation
- Verify `CUVS_GPU_BACKEND=CUDA` and `CUVS_GPU_BACKEND=MUSA` are accepted.
- Verify invalid backend value fails with actionable message.

### B2: Target closure
- Build `libcuvs` MVP target set in MUSA mode.
- Ensure unsupported optional targets are skipped via feature gates.

## L2 - Runtime Adapter Contract Tests

### R1: Stream contract
- create -> use -> sync -> destroy stream cycle.
- repeatability over multiple create/destroy cycles.

### R2: Memory contract
- alloc/free device memory.
- host->device, device->host, and device->device copy checks.
- async copy with explicit sync correctness.

### R3: Event contract
- create/record/sync/destroy event lifecycle.
- event-based ordering on at least one simple operation chain.

### R4: Error mapping
- force representative runtime failures and validate cuVS status mapping.

## L3 - API and Component Tests

### C1: C API resource lifecycle
- create resource, set/get stream, synchronize, destroy resource.
- double-destroy and null-handle behavior as specified by API contract.

### C2: Brute-force component correctness
- build index and run deterministic k-NN query on fixed small datasets.
- validate output shape and expected nearest-neighbor IDs/distances.

## L4 - Integration Smoke

### I1: End-to-end C API smoke
- allocate input/output buffers, run brute-force build/search, verify results.

### I2: Cross-backend consistency sample
- run one shared dataset case on CUDA and MUSA, compare numerics under tolerance.

## Entry / Exit Criteria

## Entry criteria for MVP test cycle

- Backend selection compiles in CI.
- Runtime adapter skeleton exists for stream/memory/event APIs used by MVP.
- Brute-force path compiles in MUSA mode.

## Exit criteria for MVP milestone

- All L1-L4 MVP tests pass in MUSA environment.
- CUDA baseline remains green.
- No unresolved P0/P1/P2 blocker defects.

## Defect Severity and Triage

- S0: data corruption/crash/deadlock -> immediate stop-ship.
- S1: incorrect search results or API contract break -> fix before merge.
- S2: non-critical feature-gated path failure -> can defer with issue.
- S3: docs/logging/usability issue -> backlog.

## Regression Strategy

- Maintain a curated deterministic dataset pack for ANN correctness.
- Preserve golden outputs for MVP tests with versioned tolerance policy.
- Run nightly extended CUDA + MUSA smoke after each merged port batch.

## L5 - Packaging and Rename Tests

### P1: Rename script correctness
- Verify content renaming: includes, namespaces, macros, types, CMake targets,
  Python imports, linker flags, Doxygen comments.
- Verify no false positives on `cuda`/`CUDA`, `raft`, unrelated words.
- Verify file/directory path renaming: headers, libraries, CMake config, Python packages.
- Verify end-to-end tree rename: header, CMake, Python, binary passthrough.
- Verify compatibility header generation with expected `#define` mappings.

### P2: CMake packaging variables
- Verify `CUVS_OUTPUT_NAME`, `CUVS_OUTPUT_NAME_C`, `CUVS_EXPORT_SET`,
  `CUVS_INSTALL_INCLUDE_DIR`, `CUVS_NAMESPACE`, `CUVS_PACKAGE_NAME`
  are set to `muvs` values when `CUVS_GPU_BACKEND=MUSA`.
- Verify same variables are set to `cuvs` values when `CUVS_GPU_BACKEND=CUDA`.

## Coverage Goals (MVP)

- 100% coverage of runtime adapter APIs used by MVP vertical.
- 100% coverage of C API resource lifecycle paths used by MVP tests.
- At least one positive and one negative case per public MVP API call.
- 100% of rename script functions exercised by unit tests.

## Reporting

Each CI run should report:
- configure success/failure per backend,
- build success/failure per target group,
- pass/fail by suite (L1-L4),
- failed test names with backend tag,
- duration and flaky retry indicator.

## Command Matrix Template

Use project-standard command wrappers; track both backends in the same format.

- Configure:
  - `cmake -S . -B build-<backend> -DCUVS_GPU_BACKEND=<backend> ...`
- Build:
  - `cmake --build build-<backend> --target <mvp-targets>`
- Test:
  - `ctest --test-dir build-<backend> --output-on-failure -R "<mvp-regex>"`

Replace `<backend>` with `CUDA` or `MUSA` and narrow `<mvp-targets>` and `<mvp-regex>` to the accepted MVP subset.
