"""Tests for scripts/fingerprint.py.

The expected values were produced by the script as it lived in closebook-finance-platform before it
moved here (CLOS-412). Tickets carry `audit-fp-<fingerprint>` labels, so a different value for the
same finding would re-open every open finding as a new ticket: these values must never change.
"""
import importlib.util
import os
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "fingerprint.py")
_spec = importlib.util.spec_from_file_location("fingerprint", SCRIPT_PATH)
fingerprint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fingerprint)

KNOWN = [
    ({"source": "security", "rule": "dependency-advisory", "file": "pnpm-lock.yaml",
      "title": "Upgrade nanoid to 3.3.8"}, "d191086891"),
    ({"source": "nestjs", "rule": "unused-dependency", "file": "apps/api/package.json:12",
      "title": "Remove unused dependency lodash"}, "15328c9e36"),
    ({"source": "react", "rule": "no-console", "file": "apps/web/src/app/page.tsx#L40",
      "title": "  Remove   console.log  from  page "}, "3eaae57fec"),
    ({"source": "dora", "rule": "", "file": "", "title": "Lead time above 7 days"}, "1012b426bd"),
]


class TestFingerprint(unittest.TestCase):
    def test_values_match_the_closebook_version(self):
        for finding, expected in KNOWN:
            with self.subTest(finding=finding["title"]):
                self.assertEqual(fingerprint.fingerprint(finding), expected)

    def test_line_numbers_do_not_change_the_fingerprint(self):
        a = {"source": "nestjs", "rule": "r", "file": "apps/api/package.json:12", "title": "t"}
        b = dict(a, file="apps/api/package.json:40")
        self.assertEqual(fingerprint.fingerprint(a), fingerprint.fingerprint(b))

    def test_case_and_spacing_do_not_change_the_fingerprint(self):
        a = {"source": "react", "rule": "r", "file": "f", "title": "Remove  Console.log"}
        b = dict(a, title="remove console.log ")
        self.assertEqual(fingerprint.fingerprint(a), fingerprint.fingerprint(b))

    def test_a_different_rule_changes_the_fingerprint(self):
        a = {"source": "react", "rule": "r1", "file": "f", "title": "t"}
        b = dict(a, rule="r2")
        self.assertNotEqual(fingerprint.fingerprint(a), fingerprint.fingerprint(b))


if __name__ == "__main__":
    unittest.main()
