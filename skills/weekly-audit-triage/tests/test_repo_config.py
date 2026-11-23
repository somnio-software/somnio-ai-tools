"""Tests for scripts/repo_config.py, the validator of .claude/weekly-audit.json."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "repo_config.py")
_spec = importlib.util.spec_from_file_location("repo_config", SCRIPT_PATH)
repo_config = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(repo_config)


def valid(**overrides):
    config = {
        "version": 1,
        "repo": "acme/widgets",
        "jira_project": "WID",
        "base_branch": "develop",
        "drive_folder": "1AbCdEfGhIjK",
        "verify": [{"name": "test", "run": "npm test"}],
    }
    config.update(overrides)
    return config


class TestValidate(unittest.TestCase):
    def test_minimal_config_gets_its_defaults(self):
        config, errors = repo_config.validate(valid())
        self.assertEqual(errors, [])
        self.assertEqual(config["report_name"], "widgets")
        self.assertEqual(config["apps"], ["."])
        self.assertEqual(config["excluded_paths"], [])
        self.assertIsNone(config["ship_skill"])

    def test_given_optional_fields_are_kept(self):
        config, errors = repo_config.validate(valid(
            _comment="read by the weekly-audit skills",
            report_name="widgets-platform",
            apps=["apps/api", "apps/web"],
            excluded_paths=["infra/"],
            ship_skill="ship-flow",
            verify=[{"name": "audit", "run": "npm audit", "when": "dependencies"}],
        ))
        self.assertEqual(errors, [])
        self.assertEqual(config["report_name"], "widgets-platform")
        self.assertEqual(config["apps"], ["apps/api", "apps/web"])
        self.assertNotIn("_comment", config)

    def test_every_missing_required_field_is_named(self):
        _, errors = repo_config.validate({})
        for key in ("version", "repo", "jira_project", "base_branch", "drive_folder", "verify"):
            self.assertIn(f"missing required field '{key}'", errors)

    def test_wrong_types_are_named(self):
        _, errors = repo_config.validate(valid(version="1", repo=7, apps="apps/api", verify={}))
        self.assertIn("'version' must be a int", errors)
        self.assertIn("'repo' must be a str", errors)
        self.assertIn("'apps' must be a list", errors)
        self.assertIn("'verify' must be a list", errors)

    def test_a_boolean_is_not_a_version(self):
        _, errors = repo_config.validate(valid(version=True))
        self.assertIn("'version' must be a int", errors)

    def test_unknown_fields_are_rejected(self):
        _, errors = repo_config.validate(valid(verfy=[], slack_channel="#x"))
        self.assertIn("unknown field 'slack_channel'", errors)
        self.assertIn("unknown field 'verfy'", errors)

    def test_values_are_checked(self):
        _, errors = repo_config.validate(valid(
            version=2, repo="widgets", jira_project="wid", base_branch=" ", apps=[], excluded_paths=[""],
        ))
        self.assertIn("unsupported version 2 (supported: 1)", errors)
        self.assertIn("'repo' must be 'owner/name'", errors)
        self.assertIn("'jira_project' must be a Jira project key such as 'CLOS'", errors)
        self.assertIn("'base_branch' must not be empty", errors)
        self.assertIn("'apps' must list at least one app, or be left out", errors)
        self.assertIn("'excluded_paths[0]' must be a non-empty string", errors)

    def test_verify_entries_are_checked(self):
        _, errors = repo_config.validate(valid(verify=[
            "npm test",
            {"name": "lint"},
            {"name": "audit", "run": "npm audit", "when": "always", "timeout": 5},
        ]))
        self.assertIn("'verify[0]' must be an object with 'name' and 'run'", errors)
        self.assertIn("'verify[1].run' must be a non-empty string", errors)
        self.assertIn("'verify[2].when' must be one of: dependencies", errors)
        self.assertIn("unknown field 'verify[2].timeout'", errors)

    def test_an_empty_verify_list_is_an_error(self):
        _, errors = repo_config.validate(valid(verify=[]))
        self.assertIn("'verify' must list at least one command", errors)

    def test_a_non_object_config_is_an_error(self):
        _, errors = repo_config.validate([valid()])
        self.assertEqual(errors, ["the config must be a JSON object"])


class TestCommandLine(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run([sys.executable, SCRIPT_PATH, *args], capture_output=True, text=True)

    def write(self, text):
        fh = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        fh.write(text)
        fh.close()
        self.addCleanup(os.unlink, fh.name)
        return fh.name

    def test_valid_file_prints_the_config_and_exits_0(self):
        result = self.run_script(self.write(json.dumps(valid())))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["report_name"], "widgets")

    def test_invalid_file_lists_errors_and_exits_2(self):
        result = self.run_script(self.write(json.dumps({"version": 1})))
        self.assertEqual(result.returncode, 2)
        self.assertIn("missing required field 'repo'", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_bad_json_exits_2(self):
        result = self.run_script(self.write("{not json"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("cannot read the config", result.stderr)

    def test_missing_file_exits_2(self):
        result = self.run_script(os.path.join(tempfile.gettempdir(), "no-such-weekly-audit.json"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("no config at", result.stderr)

    def test_no_argument_prints_usage_and_exits_2(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage", result.stderr)


if __name__ == "__main__":
    unittest.main()
