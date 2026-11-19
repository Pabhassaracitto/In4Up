"""CI diagnostics must retain Flutter assertions within Actions' byte cap."""

import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/emit_failure_annotation.py"
SPEC = importlib.util.spec_from_file_location("annotations", SCRIPT)
annotations = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(annotations)


class FailureAnnotationsTest(unittest.TestCase):
    def test_widget_and_plain_assertions_and_all_names_are_retained(self):
        lines = [
            "00:00 +0: loading a_test.dart",
            "══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞══",
            "The following TestFailure was thrown running a test:",
            "Expected: 'mlkit'",
            "  Actual: 'google_free'",
            "When the exception was thrown, this was the stack:",
            "#0 package:flutter/test.dart",
            "#1 file:///repo/test/a_test.dart:12",
            "00:01 +0 -1: a_test.dart: drag reorder [E]",
            "  Test failed. See exception logs above.",
            "00:01 +0 -1: a_test.dart: route persistence",
            "00:01 +0 -2: a_test.dart: route persistence [E]",
            "  Expected: true",
            "    Actual: false",
            "00:02 +0 -2: Some tests failed.",
        ]
        selected = annotations._priority_lines(lines)
        self.assertIn("Expected: 'mlkit'", selected)
        self.assertIn("  Expected: true", selected)
        self.assertIn(lines[8], selected[:3])
        self.assertIn(lines[11], selected[:3])
        self.assertIn(lines[7], selected)

    def test_chunks_bound_utf8_bytes_without_splitting_command_escapes(self):
        raw = ("Tiếng Việt %25 %0A %0D བོད་ " * 1000)
        chunks = annotations._chunks(raw)
        self.assertEqual("".join(chunks), raw)
        self.assertTrue(all(len(c.encode("utf-8")) <= annotations.CHUNK
                            for c in chunks))
        self.assertTrue(all(not c.endswith(("%", "%0", "%2"))
                            for c in chunks))

    def test_build_errors_keep_existing_priority(self):
        selected = annotations._priority_lines([
            "starting compiler",
            "FAILED: target",
            "undefined reference to symbol",
            "ninja: build stopped",
        ])
        self.assertIn("FAILED: target", selected)
        self.assertIn("undefined reference to symbol", selected)


if __name__ == "__main__":
    unittest.main()
