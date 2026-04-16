# muVS User Scenarios and Migration Guide

## Context

cuVS today is an NVIDIA CUDA-only library. Every user — from Python data scientists to
C++ infrastructure engineers — builds, installs, and runs cuVS exclusively on NVIDIA GPUs.

This document answers: **if we ship muVS (the MUSA-backend build of cuVS), what does
each type of user need to do?**

## Naming Convention

| Term | Meaning |
|---|---|
| **cuVS** | The existing library built for NVIDIA CUDA GPUs (unchanged) |
| **muVS** | A separately-packaged build of the same codebase targeting MUSA GPUs |
| **cuVS (unified)** | Future state where one source tree supports both via `CUVS_GPU_BACKEND` |

muVS is **not a fork** — it is a build variant of the same repository, selected at
compile time. The API surface, algorithm behavior, and data formats are identical.

---

## User Personas

### P1: Python end-user (pip / conda consumer)

**Today with cuVS:**
```bash
pip install cuvs-cu12          # or conda install -c rapidsai cuvs
```
```python
from cuvs.neighbors import brute_force
index = brute_force.build(res, dataset)
result = brute_force.search(res, index, queries, k=10)
```

**With muVS — what changes:**
```bash
pip install muvs               # separate package name, MUSA wheels
```
```python
from muvs.neighbors import brute_force     # import path changes
index = brute_force.build(res, dataset)     # API calls identical
result = brute_force.search(res, index, queries, k=10)
```

**Migration effort: LOW**

- Install a different package.
- Change import prefix from `cuvs` to `muvs`.
- All function signatures, parameter names, return types, and data formats are the same.
- DLPack interop works the same way (device type tag will be `kDLMUSA` instead of `kDLCUDA`).

**What users do NOT need to change:**
- Algorithm selection, index parameters, distance metrics.
- Data loading, preprocessing, result handling.
- Any CPU-side logic.

### P2: C API application developer

**Today with cuVS:**
```c
#include <cuvs/core/c_api.h>
#include <cuvs/neighbors/brute_force.h>

cuvsResources_t res;
cuvsResourcesCreate(&res);
cudaStream_t stream;
cudaStreamCreate(&stream);
cuvsStreamSet(res, stream);
// ... build index, search ...
```

**With muVS — what changes:**
```c
#include <muvs/core/c_api.h>            // header path changes
#include <muvs/neighbors/brute_force.h>

muvsResources_t res;                     // type prefix changes
muvsResourcesCreate(&res);
musaStream_t stream;                     // MUSA runtime type
musaStreamCreate(&stream);
muvsStreamSet(res, stream);              // function prefix changes
// ... build index, search — same API shape ...
```

**Migration effort: MEDIUM (mechanical)**

- Change header includes from `cuvs/` to `muvs/`.
- Change function/type prefixes from `cuvs` to `muvs`.
- Change CUDA runtime calls to MUSA equivalents (`cuda*` → `musa*`).
- Link against `libmuvs` and MUSA toolkit instead of `libcuvs` and CUDA toolkit.
- Logic, algorithm parameters, and data flow remain identical.

**Alternative (unified header mode, future):**
```c
#include <cuvs/core/c_api.h>            // same header
// cuvsStream_t resolves to musaStream_t when built with MUSA backend
cuvsStream_t stream;
```

### P3: C++ application developer

**Today with cuVS:**
```cpp
#include <cuvs/neighbors/brute_force.hpp>
#include <raft/core/resources.hpp>

raft::resources res;
auto idx = cuvs::neighbors::brute_force::build(res, params, dataset);
cuvs::neighbors::brute_force::search(res, search_params, idx, queries, neighbors, distances);
```

**With muVS — what changes:**
```cpp
#include <muvs/neighbors/brute_force.hpp>  // header path
#include <raft/core/resources.hpp>          // RAFT also needs MUSA build

raft::resources res;
auto idx = muvs::neighbors::brute_force::build(res, params, dataset);   // namespace change
muvs::neighbors::brute_force::search(res, search_params, idx, queries, neighbors, distances);
```

**Migration effort: MEDIUM (mechanical)**

- Change header includes from `cuvs/` to `muvs/`.
- Change namespace from `cuvs::` to `muvs::`.
- Ensure RAFT/RMM are also built for MUSA (dependency chain).
- Compile with MUSA toolkit (`mcc` instead of `nvcc`).
- Same algorithm APIs, same template parameters, same mdspan types.

### P4: Rust / Go / Java binding user

**Today:** Link against `libcuvs_c` and use FFI wrappers.

**With muVS:** Link against `libmuvs_c` with equivalent FFI. The binding layer
handles the name translation; user-facing API in each language stays the same
shape (same struct names, same method names, different underlying library).

**Migration effort: LOW** — change dependency declaration and (if applicable) feature flag.

### P5: Build-from-source integrator (CMake consumer)

**Today with cuVS:**
```bash
cmake -S . -B build -DCMAKE_CUDA_ARCHITECTURES=80
cmake --build build
```

**With muVS — option A (unified source tree, recommended long-term):**
```bash
cmake -S . -B build -DCUVS_GPU_BACKEND=MUSA
cmake --build build
```

**With muVS — option B (separate muVS package):**
```bash
cmake -S . -B build                    # MUSA is the default in muVS checkout
cmake --build build
```

**Migration effort: LOW**

- Pass one CMake flag or use the muVS-specific source.
- No algorithm code changes needed.

---

## Decision: Separate Package (muVS) vs Unified Build

### Recommended approach: **ship as separate muVS package, built from same source**

| Aspect | Separate muVS Package | Unified cuVS with flag |
|---|---|---|
| User confusion | Clear: `pip install muvs` = MUSA | Unclear: same name, different hardware |
| CUDA user impact | Zero — cuVS is untouched | Risk of accidental breakage |
| Package manager | Clean dependency resolution | Conflicting CUDA/MUSA deps in same name |
| CI | Separate matrix, independent failures | Single matrix, coupled failures |
| Source maintenance | Same repo, different build configs | Same repo, same build configs |
| Long-term convergence | Can merge later when mature | Already merged from day one |

### Why separate packaging but same source

1. **Python ecosystem convention** — PyTorch ships `torch` (CUDA) and `torch-musa`
   separately. Users expect different package names for different hardware.
2. **No accidental GPU mismatch** — installing `muvs` on a CUDA-only machine fails
   fast with a clear error rather than silently loading wrong binaries.
3. **Independent release cadence** — muVS can ship feature-gated releases without
   blocking cuVS stability.
4. **Same codebase** — no fork divergence. All algorithm improvements land in both.

---

## What Stays the Same (for all users)

- Algorithm names and parameter semantics.
- Index serialization format (indices saved on one backend can be loaded on the other
  for CPU-accessible data).
- DLPack tensor interchange protocol (device type tag changes, but layout is the same).
- Error codes and error model.
- Logging levels and configuration.

## What Changes (summary by layer)

| Layer | cuVS (CUDA) | muVS (MUSA) | User Action |
|---|---|---|---|
| Package name | `cuvs` / `cuvs-cu12` | `muvs` | Change install command |
| Python import | `from cuvs.*` | `from muvs.*` | Find-and-replace import |
| C/C++ headers | `#include <cuvs/...>` | `#include <muvs/...>` | Find-and-replace include |
| C API prefix | `cuvs*` / `CUVS_*` | `muvs*` / `MUVS_*` | Find-and-replace symbols |
| C++ namespace | `cuvs::` | `muvs::` | Find-and-replace namespace |
| Stream type | `cudaStream_t` | `musaStream_t` | Change GPU runtime calls |
| Link library | `-lcuvs` | `-lmuvs` | Change linker flags |
| CMake package | `find_package(cuvs)` | `find_package(muvs)` | Change CMake call |
| DLPack device | `kDLCUDA` | `kDLMUSA` | Change device type checks |
| GPU toolkit | CUDA Toolkit | MUSA Toolkit | Install correct toolkit |

## What We Provide to Ease Migration

1. **Naming script** — a provided `rename_cuvs_to_muvs.py` that mechanically
   transforms user code (imports, includes, prefixes).
2. **Compatibility typedef header** — `muvs/compat/cuvs_compat.h` that maps old
   `cuvs*` names to `muvs*` for gradual migration.
3. **Migration guide per language** — one-page guides for Python, C, C++, Rust, Go.
4. **Dual-backend CI** — correctness results published for both backends so users
   can verify algorithm parity.

---

## FAQ

### Q: Can I use cuVS and muVS in the same process?
No. They link against different GPU runtimes that cannot coexist. Choose one per process.

### Q: Will my saved indices work across backends?
Yes for CPU-serialized formats. The on-disk format is identical. GPU-resident data
must be copied through host to cross backends.

### Q: Is there a performance difference?
Performance depends on the GPU hardware and runtime. muVS targets functional
correctness parity first; performance tuning follows.

### Q: Do I need to rebuild my entire stack?
Yes — all GPU-linked dependencies (RAFT, RMM, and your application) must be built
against the same backend. CPU-only dependencies are unchanged.

### Q: When will all cuVS algorithms be available in muVS?
The MVP ships single-GPU brute-force ANN. Additional algorithms will be enabled
progressively. The backlog tracks the expansion order.
