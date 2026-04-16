#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

"""
Build-time prefix rename: cuVS -> muVS

This script transforms cuVS source artifacts into muVS equivalents by applying
a mechanical text replacement on file contents and directory/file names.

Replacement rules (applied in order, case-sensitive):
  cuVS  -> muVS          (branding in comments/docs)
  CUVS  -> MUVS          (macro prefixes, enum values)
  cuvs  -> muvs          (namespaces, includes, function prefixes, package names)
  libcuvs -> libmuvs     (library names — handled by the cuvs->muvs rule)

Tokens that must NOT be renamed:
  cuda, CUDA, cudaStream_t, etc. — these are a different project.
  raft, rmm, dlpack — third-party dependencies.
  NVIDIA — copyright holder.

Usage:
    python rename_cuvs_to_muvs.py --src <source_tree> --dst <output_tree>
    python rename_cuvs_to_muvs.py --generate-compat-header --dst <output_dir>
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

# ---------------------------------------------------------------------------
# Core replacement table (order matters: longest / most-specific first)
# ---------------------------------------------------------------------------

_REPLACEMENTS: list[tuple[str, str]] = [
    ("cuVS", "muVS"),
    ("CUVS", "MUVS"),
    ("cuvs", "muvs"),
]

_CONTENT_RE = re.compile("|".join(re.escape(old) for old, _ in _REPLACEMENTS))
_REPLACE_MAP = {old: new for old, new in _REPLACEMENTS}

TEXT_EXTENSIONS = frozenset({
    ".h", ".hpp", ".c", ".cpp", ".cu", ".cuh",
    ".py", ".pyx", ".pxd",
    ".cmake", ".txt", ".md", ".rst", ".yaml", ".yml", ".toml", ".cfg", ".ini",
    ".json", ".in", ".sh", ".bash", ".zsh",
    ".java", ".rs", ".go",
})


def _is_text_file(path: Path) -> bool:
    if path.suffix.lower() in TEXT_EXTENSIONS:
        return True
    if path.name in {"CMakeLists.txt", "Makefile", "Dockerfile", ".gitignore"}:
        return True
    return False


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def rename_content(text: str) -> str:
    """Apply the cuVS->muVS prefix rename to text content."""
    return _CONTENT_RE.sub(lambda m: _REPLACE_MAP[m.group(0)], text)


def rename_path(relpath: str) -> str:
    """Apply the cuVS->muVS rename to a relative file/directory path."""
    parts = Path(relpath).parts
    new_parts = []
    for part in parts:
        new_part = _CONTENT_RE.sub(lambda m: _REPLACE_MAP[m.group(0)], part)
        new_parts.append(new_part)
    return str(Path(*new_parts))


def rename_tree(src_root: str, dst_root: str) -> list[str]:
    """
    Walk *src_root*, rename paths and text content, write results to *dst_root*.

    Returns a list of output file paths (relative to dst_root).
    """
    src = Path(src_root)
    dst = Path(dst_root)
    output_files: list[str] = []

    for src_file in sorted(src.rglob("*")):
        if src_file.is_dir():
            continue
        rel = src_file.relative_to(src)
        new_rel = rename_path(str(rel))
        dst_file = dst / new_rel
        dst_file.parent.mkdir(parents=True, exist_ok=True)

        if _is_text_file(src_file):
            try:
                text = src_file.read_text(encoding="utf-8")
                dst_file.write_text(rename_content(text), encoding="utf-8")
            except UnicodeDecodeError:
                shutil.copy2(src_file, dst_file)
        else:
            shutil.copy2(src_file, dst_file)

        output_files.append(new_rel)

    return output_files


# ---------------------------------------------------------------------------
# Compatibility header generator
# ---------------------------------------------------------------------------

_COMPAT_SYMBOLS = [
    # (old_type_or_func, new_type_or_func)
    ("cuvsError_t",           "muvsError_t"),
    ("cuvsResources_t",       "muvsResources_t"),
    ("cuvsStream_t",          "muvsStream_t"),
    ("cuvsLogLevel_t",        "muvsLogLevel_t"),
    ("cuvsResourcesCreate",   "muvsResourcesCreate"),
    ("cuvsResourcesDestroy",  "muvsResourcesDestroy"),
    ("cuvsStreamSet",         "muvsStreamSet"),
    ("cuvsStreamGet",         "muvsStreamGet"),
    ("cuvsStreamSync",        "muvsStreamSync"),
    ("cuvsDeviceIdGet",       "muvsDeviceIdGet"),
    ("cuvsRMMAlloc",          "muvsRMMAlloc"),
    ("cuvsRMMFree",           "muvsRMMFree"),
    ("cuvsGetLastErrorText",  "muvsGetLastErrorText"),
    ("cuvsSetLastErrorText",  "muvsSetLastErrorText"),
    ("cuvsGetLogLevel",       "muvsGetLogLevel"),
    ("cuvsSetLogLevel",       "muvsSetLogLevel"),
    ("cuvsVersionGet",        "muvsVersionGet"),
    ("cuvsMatrixCopy",        "muvsMatrixCopy"),
    ("cuvsMatrixSliceRows",   "muvsMatrixSliceRows"),
    ("CUVS_ERROR",            "MUVS_ERROR"),
    ("CUVS_SUCCESS",          "MUVS_SUCCESS"),
    ("cuvsRMMPoolMemoryResourceEnable", "muvsRMMPoolMemoryResourceEnable"),
    ("cuvsRMMMemoryResourceReset",      "muvsRMMMemoryResourceReset"),
    ("cuvsRMMHostAlloc",      "muvsRMMHostAlloc"),
    ("cuvsRMMHostFree",       "muvsRMMHostFree"),
]


def generate_compat_header() -> str:
    """
    Generate a C compatibility header that maps old cuVS names to muVS names.

    Users migrating gradually can include this header to keep using cuvs* names
    while linking against libmuvs.
    """
    lines = [
        "/*",
        " * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.",
        " * SPDX-License-Identifier: Apache-2.0",
        " *",
        " * Compatibility header: maps legacy cuVS names to muVS equivalents.",
        " * Include this header in code that was written for cuVS and is now being",
        " * compiled against the muVS (MUSA-backend) package.",
        " *",
        " * Generated by tools/musa/rename_cuvs_to_muvs.py",
        " */",
        "",
        "#pragma once",
        "",
        "#include <muvs/core/c_api.h>",
        "",
    ]

    for old_name, new_name in _COMPAT_SYMBOLS:
        lines.append(f"#define {old_name} {new_name}")

    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build-time prefix rename: cuVS -> muVS"
    )
    parser.add_argument("--src", type=str, help="Source tree root")
    parser.add_argument("--dst", type=str, required=True, help="Output tree root")
    parser.add_argument(
        "--generate-compat-header",
        action="store_true",
        help="Generate muvs/compat/cuvs_compat.h in --dst",
    )
    args = parser.parse_args()

    if args.generate_compat_header:
        out = Path(args.dst) / "muvs" / "compat" / "cuvs_compat.h"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(generate_compat_header())
        print(f"Wrote compatibility header: {out}")
        return

    if not args.src:
        parser.error("--src is required when not using --generate-compat-header")

    files = rename_tree(args.src, args.dst)
    print(f"Renamed {len(files)} files from {args.src} -> {args.dst}")


if __name__ == "__main__":
    main()
