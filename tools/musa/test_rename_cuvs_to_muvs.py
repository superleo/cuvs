#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

"""
TDD Red-then-Green tests for rename_cuvs_to_muvs.py

These tests validate that the build-time prefix rename script correctly
transforms cuVS source artifacts into muVS equivalents. They exercise:

  1. Text content renaming (includes, namespaces, macros, types, comments)
  2. File path renaming (directory and filename substitutions)
  3. CMake target / library name renaming
  4. Edge cases (no false positives on unrelated strings)
"""

import os
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS_DIR))

from rename_cuvs_to_muvs import (  # noqa: E402
    rename_content,
    rename_path,
    rename_tree,
)


class TestRenameContent(unittest.TestCase):
    """Unit tests for in-memory text content renaming."""

    def test_include_directive_header_path(self):
        src = '#include <cuvs/core/c_api.h>'
        self.assertEqual(rename_content(src), '#include <muvs/core/c_api.h>')

    def test_include_directive_cpp_header(self):
        src = '#include <cuvs/neighbors/brute_force.hpp>'
        self.assertEqual(rename_content(src), '#include <muvs/neighbors/brute_force.hpp>')

    def test_namespace_declaration(self):
        src = 'namespace cuvs::neighbors::brute_force {'
        self.assertEqual(rename_content(src), 'namespace muvs::neighbors::brute_force {')

    def test_namespace_closing_comment(self):
        src = '}  // namespace cuvs::backend'
        self.assertEqual(rename_content(src), '}  // namespace muvs::backend')

    def test_qualified_name(self):
        src = 'auto idx = cuvs::neighbors::brute_force::build(res, params, dataset);'
        self.assertEqual(
            rename_content(src),
            'auto idx = muvs::neighbors::brute_force::build(res, params, dataset);',
        )

    def test_c_api_function_prefix(self):
        src = 'cuvsError_t cuvsResourcesCreate(cuvsResources_t* res);'
        self.assertEqual(
            rename_content(src),
            'muvsError_t muvsResourcesCreate(muvsResources_t* res);',
        )

    def test_c_api_enum_values(self):
        src = 'typedef enum { CUVS_ERROR = 0, CUVS_SUCCESS = 1 } cuvsError_t;'
        self.assertEqual(
            rename_content(src),
            'typedef enum { MUVS_ERROR = 0, MUVS_SUCCESS = 1 } muvsError_t;',
        )

    def test_cmake_find_package(self):
        src = 'find_package(cuvs REQUIRED)'
        self.assertEqual(rename_content(src), 'find_package(muvs REQUIRED)')

    def test_cmake_target_link(self):
        src = 'target_link_libraries(myapp PRIVATE cuvs::cuvs)'
        self.assertEqual(rename_content(src), 'target_link_libraries(myapp PRIVATE muvs::muvs)')

    def test_library_name(self):
        src = 'set(LIB_NAME "libcuvs")'
        self.assertEqual(rename_content(src), 'set(LIB_NAME "libmuvs")')

    def test_python_import(self):
        src = 'from cuvs.neighbors import brute_force'
        self.assertEqual(rename_content(src), 'from muvs.neighbors import brute_force')

    def test_python_import_direct(self):
        src = 'import cuvs'
        self.assertEqual(rename_content(src), 'import muvs')

    def test_macro_prefix(self):
        src = '#define CUVS_BACKEND_TRY(call) \\'
        self.assertEqual(rename_content(src), '#define MUVS_BACKEND_TRY(call) \\')

    def test_macro_ifdef(self):
        src = '#ifdef CUVS_BACKEND_MUSA'
        self.assertEqual(rename_content(src), '#ifdef MUVS_BACKEND_MUSA')

    def test_doxygen_group(self):
        src = ' * @defgroup bruteforce_cpp_index cuVS Bruteforce index'
        self.assertEqual(
            rename_content(src), ' * @defgroup bruteforce_cpp_index muVS Bruteforce index'
        )

    def test_no_false_positive_on_cuda(self):
        """cuda/CUDA tokens must NOT be renamed — only cuvs/cuVS tokens."""
        src = '#include <cuda_runtime.h>\ncudaStream_t stream;'
        self.assertEqual(rename_content(src), src)

    def test_no_false_positive_on_raft(self):
        src = '#include <raft/core/resources.hpp>'
        self.assertEqual(rename_content(src), src)

    def test_no_false_positive_on_unrelated_words(self):
        src = 'recursive function'
        self.assertEqual(rename_content(src), src)

    def test_preserves_cuda_backend_musa_define_value(self):
        """CUVS_BACKEND_MUSA -> MUVS_BACKEND_MUSA (macro name rename)."""
        src = '#if defined(CUVS_BACKEND_MUSA)'
        self.assertEqual(rename_content(src), '#if defined(MUVS_BACKEND_MUSA)')

    def test_multiline_content(self):
        src = textwrap.dedent("""\
            #include <cuvs/core/c_api.h>
            namespace cuvs::core {
            cuvsError_t cuvsResourcesCreate(cuvsResources_t* res);
            }  // namespace cuvs::core
        """)
        expected = textwrap.dedent("""\
            #include <muvs/core/c_api.h>
            namespace muvs::core {
            muvsError_t muvsResourcesCreate(muvsResources_t* res);
            }  // namespace muvs::core
        """)
        self.assertEqual(rename_content(src), expected)

    def test_spdx_header_preserved(self):
        """NVIDIA copyright stays as-is."""
        src = '# SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.'
        self.assertEqual(rename_content(src), src)

    def test_link_flag(self):
        src = 'target_link_libraries(foo PRIVATE -lcuvs)'
        self.assertEqual(rename_content(src), 'target_link_libraries(foo PRIVATE -lmuvs)')


class TestRenamePath(unittest.TestCase):
    """Unit tests for file/directory path renaming."""

    def test_header_path(self):
        self.assertEqual(rename_path('include/cuvs/core/c_api.h'), 'include/muvs/core/c_api.h')

    def test_library_filename(self):
        self.assertEqual(rename_path('lib/libcuvs.so'), 'lib/libmuvs.so')

    def test_c_library_filename(self):
        self.assertEqual(rename_path('lib/libcuvs_c.so'), 'lib/libmuvs_c.so')

    def test_cmake_config(self):
        self.assertEqual(
            rename_path('lib/cmake/cuvs/cuvs-config.cmake'),
            'lib/cmake/muvs/muvs-config.cmake',
        )

    def test_python_package_dir(self):
        self.assertEqual(
            rename_path('python/cuvs/neighbors/__init__.py'),
            'python/muvs/neighbors/__init__.py',
        )

    def test_no_rename_unrelated(self):
        self.assertEqual(rename_path('include/raft/core/handle.hpp'), 'include/raft/core/handle.hpp')


class TestRenameTree(unittest.TestCase):
    """Integration tests: rename a temp directory tree and verify output."""

    def setUp(self):
        self.src_dir = tempfile.mkdtemp(prefix="cuvs_rename_test_src_")
        self.dst_dir = tempfile.mkdtemp(prefix="cuvs_rename_test_dst_")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.src_dir, ignore_errors=True)
        shutil.rmtree(self.dst_dir, ignore_errors=True)

    def _write(self, relpath: str, content: str):
        full = Path(self.src_dir) / relpath
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content)

    def test_end_to_end_header_rename(self):
        self._write("include/cuvs/core/c_api.h", textwrap.dedent("""\
            #pragma once
            #include <cuvs/core/c_api_compat.h>
            typedef enum { CUVS_ERROR = 0, CUVS_SUCCESS = 1 } cuvsError_t;
            cuvsError_t cuvsResourcesCreate(cuvsResources_t* res);
        """))

        rename_tree(self.src_dir, self.dst_dir)

        out = Path(self.dst_dir) / "include" / "muvs" / "core" / "c_api.h"
        self.assertTrue(out.exists(), f"Expected {out} to exist")
        text = out.read_text()
        self.assertIn('#include <muvs/core/c_api_compat.h>', text)
        self.assertIn('MUVS_ERROR', text)
        self.assertIn('muvsResourcesCreate', text)
        self.assertNotIn('cuvs', text.lower().replace('cuda', '').replace('recursive', ''))

    def test_end_to_end_cmake_rename(self):
        self._write("CMakeLists.txt", textwrap.dedent("""\
            project(cuvs VERSION 1.0)
            add_library(cuvs SHARED src/cuvs.cpp)
            find_package(cuvs REQUIRED)
        """))

        rename_tree(self.src_dir, self.dst_dir)

        out = Path(self.dst_dir) / "CMakeLists.txt"
        text = out.read_text()
        self.assertIn('project(muvs', text)
        self.assertIn('add_library(muvs', text)
        self.assertIn('find_package(muvs', text)

    def test_end_to_end_python_rename(self):
        self._write("python/cuvs/__init__.py", "from cuvs.neighbors import brute_force\n")

        rename_tree(self.src_dir, self.dst_dir)

        out = Path(self.dst_dir) / "python" / "muvs" / "__init__.py"
        self.assertTrue(out.exists())
        self.assertIn('from muvs.neighbors', out.read_text())

    def test_binary_file_copied_unchanged(self):
        bin_data = bytes(range(256))
        bin_path = Path(self.src_dir) / "data" / "model.bin"
        bin_path.parent.mkdir(parents=True)
        bin_path.write_bytes(bin_data)

        rename_tree(self.src_dir, self.dst_dir)

        out = Path(self.dst_dir) / "data" / "model.bin"
        self.assertTrue(out.exists())
        self.assertEqual(out.read_bytes(), bin_data)


class TestCompatHeader(unittest.TestCase):
    """Validate that the generated compatibility header maps cuvs -> muvs."""

    def test_compat_header_content(self):
        from rename_cuvs_to_muvs import generate_compat_header
        content = generate_compat_header()
        self.assertIn('muvsError_t', content)
        self.assertIn('cuvsError_t', content)
        self.assertIn('muvsResources_t', content)
        self.assertIn('cuvsResources_t', content)
        self.assertIn('muvsStreamSet', content)
        self.assertIn('cuvsStreamSet', content)
        self.assertIn('#define', content)


if __name__ == '__main__':
    unittest.main()
