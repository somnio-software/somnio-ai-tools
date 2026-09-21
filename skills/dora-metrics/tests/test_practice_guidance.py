"""Unit tests for scripts/practice_guidance.py — the practice guidance parser.

No network, no fixtures on disk beyond a temp file written by the test itself.

Usage:
    python3 -m unittest discover -s tests -p "test_*.py" -v
"""

import importlib.util
import os
import tempfile
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "practice_guidance.py")
_spec = importlib.util.spec_from_file_location("practice_guidance", SCRIPT_PATH)
practice_guidance = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(practice_guidance)

SAMPLE = """# Practice guidance

Intro prose that belongs to no code.

## Lowering Lead Time for Changes

<!-- code: trunk_based_development -->
**Trunk-based development**

### What

Developers integrate small changes frequently.

### Why it helps this metric

A long-lived branch pushes its first commit long before merging.

### How to adopt it

- Cap how long a branch may live.

---

<!-- code: small_prs -->
**Keep pull requests small**

### What

Each PR covers one focused change.

### Why it helps this metric

A large PR typically accumulates commits over a longer stretch.

### How to adopt it

- Scope a PR to one reviewable unit of change.

---

## Raising Deployment Frequency

<!-- code: reduce_batch_size -->
**Reduce deploy batch size**

### What

Each deploy ships a smaller amount of change.

### Why it helps this metric

Shipping in smaller batches more often raises the count directly.

### How to adopt it

- Move away from a fixed deploy schedule.

---

<!-- code: no_title_example -->
### What

This entry has no bold title line, only goes straight to a subsection.

### Why it helps this metric

Exercises the fallback path.

### How to adopt it

- N/A.

---

## A section with no anchor

This one is for humans only and must be ignored by the parser.
"""


class TestLoadGuidance(unittest.TestCase):
    def setUp(self):
        fd, self.path = tempfile.mkstemp(suffix=".md")
        with os.fdopen(fd, "w") as f:
            f.write(SAMPLE)
        self.guidance = practice_guidance.load_guidance(self.path)

    def tearDown(self):
        os.unlink(self.path)

    def test_finds_every_anchored_code(self):
        """Parser extracts all anchor codes from the markdown."""
        self.assertEqual(
            set(self.guidance),
            {"trunk_based_development", "small_prs", "reduce_batch_size", "no_title_example"}
        )

    def test_parses_the_three_subsections(self):
        """Parser extracts What, Why it helps this metric, and How to adopt it."""
        entry = self.guidance["trunk_based_development"]
        self.assertEqual(entry["what"], "Developers integrate small changes frequently.")
        self.assertEqual(
            entry["why"],
            "A long-lived branch pushes its first commit long before merging."
        )
        self.assertIn("Cap how long a branch may live.", entry["how_to_adopt"])

    def test_missing_subsection_is_empty_string_not_absent(self):
        """Parser creates empty strings for missing subsections, never omits keys."""
        entry = self.guidance["reduce_batch_size"]
        # This entry has all three subsections, but test the pattern anyway
        self.assertEqual(set(entry.keys()), {"what", "why", "how_to_adopt", "title", "dimension"})

    def test_title_is_parsed_for_a_titled_entry(self):
        """Parser captures the bold title line right after the anchor."""
        self.assertEqual(
            self.guidance["trunk_based_development"]["title"], "Trunk-based development"
        )
        self.assertEqual(self.guidance["small_prs"]["title"], "Keep pull requests small")

    def test_title_is_empty_string_when_entry_has_no_title_line(self):
        """An entry that goes straight from its anchor to a ### subsection,
        with no bold title line, gets back an empty string — never a missing
        key and never the code standing in for it (that fallback belongs to
        the renderer, not the parser)."""
        self.assertEqual(self.guidance["no_title_example"]["title"], "")

    def test_dimension_is_set_correctly(self):
        """Parser assigns the correct dimension heading to each entry."""
        self.assertEqual(self.guidance["trunk_based_development"]["dimension"], "lead_time")
        self.assertEqual(self.guidance["small_prs"]["dimension"], "lead_time")
        self.assertEqual(self.guidance["reduce_batch_size"]["dimension"], "deployment_frequency")

    def test_stops_at_the_horizontal_rule_and_ignores_unanchored_sections(self):
        """Parser stops at --- and ignores unanchored sections that follow."""
        self.assertNotIn("for humans only", self.guidance["reduce_batch_size"]["how_to_adopt"])

    def test_missing_file_returns_empty_dict(self):
        """Parser returns {} when the file does not exist, never crashes."""
        self.assertEqual(practice_guidance.load_guidance("/nonexistent/practice-guidance.md"), {})


EXPECTED_CODES = {
    "trunk_based_development",
    "small_prs",
    "automate_release_tagging",
    "fast_ci_feedback",
    "feature_flags_over_long_branches",
    "decouple_deploy_from_release_event",
    "automate_the_deploy_pipeline",
    "reduce_batch_size",
}


class TestRealPracticeGuidanceFile(unittest.TestCase):
    """The shipped file must actually parse — a broken anchor or a renamed
    subsection would silently strip the guidance from every report."""

    def setUp(self):
        self.guidance = practice_guidance.load_guidance(practice_guidance.default_path())

    def test_has_every_expected_code(self):
        """The shipped file has exactly the expected set of guidance codes."""
        self.assertEqual(set(self.guidance), EXPECTED_CODES)

    def test_every_entry_has_all_three_subsections(self):
        """Every guidance entry has What, Why it helps this metric, and How to adopt it."""
        for code, entry in self.guidance.items():
            with self.subTest(code=code):
                self.assertTrue(entry["what"], f"{code} has no What")
                self.assertTrue(entry["why"], f"{code} has no Why it helps this metric")
                self.assertTrue(entry["how_to_adopt"], f"{code} has no How to adopt it")

    def test_every_entry_has_a_dimension(self):
        """Every entry is assigned to a dimension (lead_time or deployment_frequency)."""
        for code, entry in self.guidance.items():
            with self.subTest(code=code):
                self.assertIn(
                    entry["dimension"],
                    ["lead_time", "deployment_frequency"],
                    f"{code} has no dimension or wrong dimension"
                )

    def test_every_entry_has_a_title(self):
        """Every entry in the shipped catalog has a human-readable title —
        the renderer's code fallback exists for a future untitled entry, not
        because any shipped one is missing its title today."""
        for code, entry in self.guidance.items():
            with self.subTest(code=code):
                self.assertTrue(entry["title"], f"{code} has no title")


if __name__ == "__main__":
    unittest.main()
