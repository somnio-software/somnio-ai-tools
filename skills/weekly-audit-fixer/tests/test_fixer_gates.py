"""Tests for scripts/fixer_gates.py, the fixer's deterministic gates, and for the steps of its SKILL.md.

Each test builds a throwaway git repository whose origin/develop is its first commit and whose HEAD is a
ticket branch, and stands in `true`, `false` and the running Python for the repository's commands.
"""
import contextlib
import importlib.util
import io
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

TESTS = os.path.dirname(os.path.abspath(__file__))
SKILL_DIR = os.path.dirname(TESTS)
FIXTURES = os.path.join(TESTS, "fixtures")
TRIAGE_SKILL = os.path.join(SKILL_DIR, "..", "weekly-audit-triage", "SKILL.md")

_spec = importlib.util.spec_from_file_location(
    "fixer_gates", os.path.join(SKILL_DIR, "scripts", "fixer_gates.py"))
fixer_gates = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fixer_gates)

# No global git config: a signing or hooks setting on the machine must not reach the throwaway repos.
_git_env = mock.patch.dict(os.environ, {
    "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
    "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "test@example.com",
    "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "test@example.com",
})
APPS = ["apps/api", "apps/web", "apps/mcp"]
PYTHON = shlex.quote(sys.executable)


def setUpModule():
    _git_env.start()


def tearDownModule():
    _git_env.stop()


def load_fixture(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as fh:
        return json.load(fh)


class Repo:
    def __init__(self, test, base_files=None):
        tmp = tempfile.TemporaryDirectory()
        test.addCleanup(tmp.cleanup)
        self.root = tmp.name
        self.path = os.path.join(self.root, "repo")
        os.makedirs(self.path)
        self.git("init", "-q", "-b", "develop")
        self.commit({"README.md": "readme\n", **(base_files or {})})
        self.git("update-ref", "refs/remotes/origin/develop", "HEAD")
        self.git("checkout", "-q", "-b", "chore/WID-1-fix")

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", self.path, *args], check=True, capture_output=True, text=True).stdout.strip()

    def write(self, files):
        for rel, content in files.items():
            full = os.path.join(self.path, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb" if isinstance(content, bytes) else "w") as fh:
                fh.write(content)

    def commit(self, files):
        self.write(files)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "change")

    def exists(self, rel):
        return os.path.exists(os.path.join(self.path, rel))

    def gates(self, **overrides):
        config = {"base_branch": "develop", "apps": ["."], "excluded_paths": [],
                  "verify": [{"name": "check", "run": "true"}]}
        config.update(overrides)
        config_path = os.path.join(self.root, "config.json")
        with open(config_path, "w", encoding="utf-8") as fh:
            json.dump(config, fh)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = fixer_gates.main(["--config", config_path, "--repo", self.path])
        return code, out.getvalue()


def lines(n):
    return "".join(f"line {i}\n" for i in range(n))


MARKER = [{"name": "marker", "run": "touch ran"}]


class TestEmptyAndUncommitted(unittest.TestCase):  # AC-1
    def test_no_change_fails_empty_and_runs_nothing(self):
        repo = Repo(self)
        code, out = repo.gates(verify=MARKER)
        self.assertEqual(code, 1)
        self.assertIn("empty: FAIL no change against origin/develop", out)
        self.assertTrue(out.endswith("RESULT: FAIL empty\n"))
        self.assertFalse(repo.exists("ran"))

    def test_an_uncommitted_file_fails_before_any_command(self):
        repo = Repo(self)
        repo.commit({"src/a.txt": "a\n"})
        repo.write({"src/b.txt": "b\n", "README.md": "changed\n"})
        code, out = repo.gates(verify=MARKER)
        self.assertEqual(code, 1)
        self.assertIn("uncommitted: FAIL not committed: README.md, src/b.txt", out)
        self.assertIn("verify: not run, a gate above failed", out)
        self.assertFalse(repo.exists("ran"))

    def test_a_command_that_rewrites_a_tracked_file_fails_uncommitted(self):
        repo = Repo(self)
        repo.commit({"src/a.txt": "a\n"})
        code, out = repo.gates(verify=[{"name": "format", "run": "echo x >> README.md"}])
        self.assertEqual(code, 1)
        self.assertIn("verify: pass", out)
        self.assertIn("uncommitted: FAIL verify changed tracked files: README.md", out)
        self.assertTrue(out.endswith("RESULT: FAIL uncommitted\n"))


class TestSize(unittest.TestCase):  # AC-2
    def test_400_lines_pass(self):
        repo = Repo(self)
        repo.commit({"a.txt": lines(400)})
        code, out = repo.gates()
        self.assertEqual(code, 0, out)
        self.assertIn("size: pass (400 lines)", out)

    def test_401_lines_fail_with_the_count(self):
        repo = Repo(self)
        repo.commit({"a.txt": lines(400), "b.txt": "one\n"})
        code, out = repo.gates(verify=MARKER)
        self.assertEqual(code, 1)
        self.assertIn("size: FAIL 401 changed lines, limit 400", out)
        self.assertFalse(repo.exists("ran"))

    def test_added_and_deleted_lines_both_count(self):
        repo = Repo(self)
        repo.commit({"README.md": "other\n"})
        _, out = repo.gates()
        self.assertIn("size: pass (2 lines)", out)

    def test_a_binary_file_fails(self):
        repo = Repo(self)
        repo.commit({"logo.bin": b"\x00\x01\x02"})
        code, out = repo.gates()
        self.assertEqual(code, 1)
        self.assertIn("size: FAIL binary file, its lines cannot be counted: logo.bin", out)


class TestApps(unittest.TestCase):  # AC-3
    def test_three_apps_fail(self):
        repo = Repo(self)
        repo.commit({"apps/api/a.ts": "a\n", "apps/web/b.ts": "b\n", "apps/mcp/c.ts": "c\n"})
        code, out = repo.gates(apps=APPS)
        self.assertEqual(code, 1)
        self.assertIn("apps: FAIL touches 3 apps, limit 2: apps/api, apps/web, apps/mcp", out)

    def test_two_apps_pass(self):
        repo = Repo(self)
        repo.commit({"apps/api/a.ts": "a\n", "apps/web/b.ts": "b\n"})
        code, out = repo.gates(apps=APPS)
        self.assertEqual(code, 0, out)
        self.assertIn("apps: pass (apps/api, apps/web)", out)

    def test_root_files_touch_no_app(self):
        repo = Repo(self)
        repo.commit({"pnpm-lock.yaml": "lock\n"})
        code, out = repo.gates(apps=APPS)
        self.assertEqual(code, 0, out)
        self.assertIn("apps: pass (no app)", out)

    def test_the_default_app_is_the_whole_repository(self):
        repo = Repo(self)
        repo.commit({"apps/api/a.ts": "a\n", "apps/web/b.ts": "b\n", "apps/mcp/c.ts": "c\n"})
        code, out = repo.gates(apps=["."])
        self.assertEqual(code, 0, out)
        self.assertIn("apps: pass (.)", out)

    def test_an_app_prefix_is_not_a_match(self):
        self.assertFalse(fixer_gates.under("apps/api-client/x.ts", "apps/api"))
        self.assertTrue(fixer_gates.under("apps/api/x.ts", "./apps/api/"))


class TestPaths(unittest.TestCase):  # AC-4
    CLOSEBOOK = load_fixture("closebook-weekly-audit.json")["excluded_paths"]

    def test_the_built_ins_exclude_with_an_empty_config(self):
        for path in ("apps/api/prisma/migrations/x/migration.sql", ".github/workflows/ci.yml",
                     ".env", ".env.local", "apps/web/.env.production", ".claude/ship-gate.json",
                     ".claude/weekly-audit.json", ".claude/agents/code-reviewer.md", "infra/main.tf",
                     "apps/web/deploy/values.yaml", "certs/server.pem", "keys/signing.key"):
            self.assertIsNotNone(fixer_gates.excluded_by(path, []), path)

    def test_config_entries_match_a_file_or_a_directory(self):
        self.assertEqual(fixer_gates.excluded_by(".claude/RULES.md", self.CLOSEBOOK), ".claude/RULES.md")
        self.assertEqual(fixer_gates.excluded_by("apps/api/prisma/schema.prisma", self.CLOSEBOOK),
                         "apps/api/prisma/")
        self.assertEqual(fixer_gates.excluded_by("apps/mcp/src/auth.ts", self.CLOSEBOOK), "apps/mcp/src/auth.ts")

    def test_near_misses_and_case_are_not_excluded(self):
        for path in ("apps/api/prisma-utils/x.ts", "apps/mcp/src/auth.test.ts", "docs/infra.md",
                     "Infra/main.tf", "src/environment.ts", "docs/keys.md"):
            self.assertIsNone(fixer_gates.excluded_by(path, self.CLOSEBOOK), path)

    def test_every_excluded_path_is_named_and_nothing_runs(self):
        repo = Repo(self)
        repo.commit({"apps/api/prisma/schema.prisma": "model\n", ".github/workflows/ci.yml": "on: push\n",
                     "src/ok.ts": "ok\n"})
        code, out = repo.gates(excluded_paths=["apps/api/prisma/"], verify=MARKER)
        self.assertEqual(code, 1)
        self.assertIn("paths: FAIL .github/workflows/ci.yml (.github/workflows/), "
                      "apps/api/prisma/schema.prisma (apps/api/prisma/)", out)
        self.assertFalse(repo.exists("ran"))

    def test_every_directory_the_triage_excludes_is_a_built_in(self):
        with open(TRIAGE_SKILL, encoding="utf-8") as fh:
            text = fh.read()
        gate = text[text.index("## 5. Complexity gate"):text.index("## 6.")]
        directories = re.findall(r"`([^`\s]+/)`", gate)
        self.assertTrue(directories, "the triage's section 5 names no directory")
        for directory in directories:
            self.assertIsNotNone(fixer_gates.excluded_by(directory + "x.txt", []), directory)


class TestReceipts(unittest.TestCase):  # AC-5
    def test_closebook_develop_passes(self):
        must_run, failures, not_checked = fixer_gates.check_receipts(
            load_fixture("closebook-ship-gate.json"), load_fixture("closebook-weekly-audit.json")["verify"])
        self.assertEqual(failures, [])
        self.assertEqual(must_run, {"pnpm build", "pnpm --filter @closebook/web lint",
                                    "pnpm --filter @closebook/mcp typecheck", "pnpm test",
                                    "pnpm test:int:changed --subset-only"})
        self.assertEqual(not_checked, ["spec"])

    def test_a_receipt_without_a_verify_command_fails(self):
        gate = {"required": [{"name": "lint", "receipt": True, "expect_cmd": "npm run lint"}]}
        repo = Repo(self, {".claude/ship-gate.json": json.dumps(gate)})
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates(verify=MARKER)
        self.assertEqual(code, 1)
        self.assertIn("receipts: FAIL lint (npm run lint) has no verify command", out)
        self.assertFalse(repo.exists("ran"))

    def test_a_receipt_without_expect_cmd_fails(self):
        _, failures, _ = fixer_gates.check_receipts({"required": [{"name": "lint", "receipt": True}]}, [])
        self.assertEqual(failures, ["lint names no expect_cmd"])

    def test_without_a_ship_gate_the_config_is_the_list(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates()
        self.assertEqual(code, 0, out)
        self.assertIn("receipts: pass (no .claude/ship-gate.json on origin/develop: "
                      "the config's verify is the list)", out)

    def test_an_invalid_ship_gate_fails(self):
        repo = Repo(self, {".claude/ship-gate.json": "{not json"})
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates()
        self.assertEqual(code, 1)
        self.assertIn("receipts: FAIL .claude/ship-gate.json on origin/develop is not valid JSON", out)

    def test_the_ship_gate_is_read_from_the_base_branch(self):
        gate = {"required": [{"name": "check", "receipt": True, "expect_cmd": "true"}]}
        repo = Repo(self, {".claude/ship-gate.json": json.dumps(gate)})
        repo.commit({".claude/ship-gate.json": "{not json"})
        _, out = repo.gates()
        self.assertIn("receipts: pass (always run: true; not checked: none)", out)
        self.assertIn("paths: FAIL .claude/ship-gate.json (.claude/ship-gate.json)", out)


class TestVerify(unittest.TestCase):  # AC-6
    def test_a_failing_command_stops_the_list(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates(verify=[{"name": "lint", "run": "false"}, *MARKER])
        self.assertEqual(code, 1)
        self.assertIn("  lint: exit 1", out)
        self.assertIn("  marker: not run", out)
        self.assertIn("verify: FAIL lint (exit 1)", out)
        self.assertFalse(repo.exists("ran"))

    def test_a_command_past_its_timeout_is_killed_with_its_children(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        started = time.monotonic()
        with mock.patch.object(fixer_gates, "TIMEOUT_SECONDS", 1):
            code, out = repo.gates(verify=[{"name": "slow", "run": "sleep 30; true"}])
        self.assertLess(time.monotonic() - started, 15)
        self.assertEqual(code, 1)
        self.assertIn("verify: FAIL slow (timed out after 1 s)", out)

    def test_the_output_is_tailed_and_secrets_redacted(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        script = "import sys; [print('out', i) for i in range(1, 101)]; print('API_TOKEN=abc123'); sys.exit(3)"
        code, out = repo.gates(verify=[{"name": "test", "run": f"{PYTHON} -c {shlex.quote(script)}"}])
        self.assertEqual(code, 1)
        self.assertIn("verify: FAIL test (exit 3)", out)
        self.assertIn("  last 40 lines of test:", out)
        self.assertIn("    out 62\n", out)
        self.assertNotIn("out 61\n", out)
        self.assertIn("    API_TOKEN=[redacted]", out)
        self.assertNotIn("abc123", out)

    def test_redact_keeps_the_key_and_drops_the_value(self):
        self.assertEqual(fixer_gates.redact("Authorization: Bearer x"), "Authorization:[redacted]")
        self.assertEqual(fixer_gates.redact("password = hunter2"), "password =[redacted]")
        self.assertEqual(fixer_gates.redact("3 tests passed"), "3 tests passed")

    AUDIT = [{"name": "audit", "run": "touch audit-ran", "when": "dependencies"}]

    def test_a_dependencies_command_is_skipped_without_a_dependency_change(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates(verify=self.AUDIT)
        self.assertEqual(code, 0, out)
        self.assertIn("  audit: skipped, no dependency file changed", out)
        self.assertFalse(repo.exists("audit-ran"))

    def test_a_dependencies_command_runs_on_a_lockfile_change(self):
        repo = Repo(self)
        repo.commit({"apps/web/package.json": "{}\n"})
        code, out = repo.gates(verify=self.AUDIT)
        self.assertEqual(code, 0, out)
        self.assertTrue(repo.exists("audit-ran"))

    def test_a_receipt_runs_a_dependencies_command_anyway(self):
        gate = {"required": [{"name": "audit", "receipt": True, "expect_cmd": "touch audit-ran"}]}
        repo = Repo(self, {".claude/ship-gate.json": json.dumps(gate)})
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates(verify=self.AUDIT)
        self.assertEqual(code, 0, out)
        self.assertTrue(repo.exists("audit-ran"))

    def test_dependency_files_are_matched_by_basename(self):
        for path in ("pnpm-lock.yaml", "apps/web/package.json", "requirements-dev.txt", "src/App.csproj",
                     "ios/Podfile.lock", "go.sum"):
            self.assertTrue(fixer_gates.is_dependency_file(path), path)
        for path in ("src/package.ts", "docs/requirements.md"):
            self.assertFalse(fixer_gates.is_dependency_file(path), path)


class TestResult(unittest.TestCase):  # AC-7
    def test_every_gate_passing_names_the_sha_and_passes(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates()
        self.assertEqual(code, 0, out)
        first, *_, last = out.splitlines()
        merge_base = repo.git("rev-parse", "origin/develop")
        self.assertEqual(first, f"checked {repo.git('rev-parse', 'HEAD')} against origin/develop ({merge_base})")
        self.assertEqual(last, "RESULT: PASS")
        self.assertIn("  check: exit 0", out)

    def test_no_base_ref_cannot_run(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        repo.git("update-ref", "-d", "refs/remotes/origin/develop")
        code, out = repo.gates()
        self.assertEqual(code, 2)
        self.assertIn("could not run: no origin/develop", out)

    def test_a_config_without_a_field_it_reads_cannot_run(self):
        repo = Repo(self)
        repo.commit({"src/a.ts": "a\n"})
        code, out = repo.gates(verify=None)
        self.assertEqual(code, 2)
        self.assertIn("could not run: the config lacks or mistypes: verify", out)

    def test_a_config_that_is_not_json_cannot_run(self):
        repo = Repo(self)
        path = os.path.join(repo.root, "config.json")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("{")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = fixer_gates.main(["--config", path, "--repo", repo.path])
        self.assertEqual(code, 2)
        self.assertIn("could not run: cannot read the config", out.getvalue())


class TestSkillText(unittest.TestCase):  # AC-8, AC-9: the steps are instructions; this pins their anchors
    @classmethod
    def setUpClass(cls):
        with open(os.path.join(SKILL_DIR, "SKILL.md"), encoding="utf-8") as fh:
            cls.text = fh.read()

    def assert_says(self, anchor, says=True):
        self.assertEqual(anchor in self.text, says, f"SKILL.md {'lacks' if says else 'still says'} {anchor!r}")

    def test_the_script_gates_the_push_of_one_sha(self):
        self.assert_says("scripts/fixer_gates.py")
        self.assert_says("refs/heads/")
        self.assert_says("a third of the", says=False)

    def test_the_repository_reviewer_reviews_before_the_pr(self):
        self.assert_says("code-reviewer")
        self.assert_says("PASS_WITH_NOTES")


if __name__ == "__main__":
    unittest.main()
