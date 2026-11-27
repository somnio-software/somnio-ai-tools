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
        _, errors = repo_config.validate(valid(verfy=[], slack="#x"))
        self.assertIn("unknown field 'slack'", errors)
        self.assertIn("unknown field 'verfy'", errors)

    def test_a_config_without_audits_validates_as_before(self):
        config, errors = repo_config.validate(valid())
        self.assertEqual(errors, [])
        self.assertEqual(set(config), {"version", "repo", "jira_project", "base_branch", "drive_folder",
                                       "verify", "report_name", "apps", "excluded_paths", "ship_skill"})

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


def routine(**overrides):
    """A config with the fields the weekly-audit-checks routine reads (CLOS-413)."""
    config = valid(
        report_name="widgets-platform",
        slack_channel="C0123456789",
        audits=[
            {"skill": "security-audit"},
            {"skill": "nestjs-health-audit", "path": "apps/api"},
            {"skill": "react-health-audit", "path": "apps/web", "report_name": "widgets-web"},
            {"skill": "dora-metrics"},
        ],
        dora={"window_days": 14, "prod_branch": "main", "type": ["web", "backend"],
              "deploy_source": "release", "tag_pattern": r"^prod-v\d+$", "provider": "github"},
    )
    config.update(overrides)
    return {k: v for k, v in config.items() if v is not None}  # an override of None drops the field


class TestRoutineFields(unittest.TestCase):
    def test_audits_get_their_defaults(self):
        config, errors = repo_config.validate(routine())
        self.assertEqual(errors, [])
        self.assertEqual(config["audits"], [
            {"skill": "security-audit", "path": ".", "report_name": "widgets-platform"},
            {"skill": "nestjs-health-audit", "path": "apps/api", "report_name": "widgets-platform"},
            {"skill": "react-health-audit", "path": "apps/web", "report_name": "widgets-web"},
            {"skill": "dora-metrics", "path": ".", "report_name": "widgets-platform"},
        ])
        self.assertEqual(config["slack_channel"], "C0123456789")
        self.assertEqual(config["dora"], routine()["dora"])

    def test_audits_need_report_name_and_slack_channel(self):
        _, errors = repo_config.validate(routine(report_name=None, slack_channel=None))
        self.assertIn("'report_name' is required when 'audits' is given", errors)
        self.assertIn("'slack_channel' is required when 'audits' is given", errors)

    def test_slack_channel_alone_needs_no_audits(self):
        _, errors = repo_config.validate(valid(slack_channel="C0123456789"))
        self.assertEqual(errors, [])

    def test_an_audit_skill_must_be_an_accepted_type(self):
        _, errors = repo_config.validate(routine(audits=[{"skill": "nextjs-health-audit"}], dora=None))
        self.assertIn("'audits[0].skill' must be one of: security-audit, dora-metrics, nestjs-health-audit, "
                      "react-health-audit, python-health-audit", errors)

    def test_audit_entries_are_checked(self):
        _, errors = repo_config.validate(routine(audits=[
            "security-audit",
            {"skill": "nestjs-health-audit", "path": "", "report_name": 7, "stack": "nestjs"},
            {"skill": "dora-metrics"},
            {"skill": "dora-metrics", "report_name": "widgets-platform"},
        ]))
        self.assertIn("'audits[0]' must be an object with 'skill'", errors)
        self.assertIn("'audits[1].path' must be a non-empty string", errors)
        self.assertIn("'audits[1].report_name' must be a non-empty string", errors)
        self.assertIn("unknown field 'audits[1].stack'", errors)
        self.assertIn("'audits[3]' writes the same report as 'audits[2]'", errors)

    def test_an_empty_audits_list_is_an_error(self):
        _, errors = repo_config.validate(routine(audits=[]))
        self.assertIn("'audits' must list at least one audit, or be left out", errors)

    def test_dora_metrics_needs_dora(self):
        _, errors = repo_config.validate(routine(dora=None))
        self.assertEqual(errors, ["'dora' is required when 'dora-metrics' is an audit"])

    def test_dora_needs_dora_metrics(self):
        _, errors = repo_config.validate(routine(audits=[{"skill": "security-audit"}]))
        self.assertEqual(errors, ["'dora' is given but 'dora-metrics' is not an audit"])
        _, errors = repo_config.validate(valid(dora=routine()["dora"]))
        self.assertEqual(errors, ["'dora' is given but 'dora-metrics' is not an audit"])

    def test_window_days_must_be_a_positive_integer(self):
        for window in (0, -7, "14", True, 1.5):
            with self.subTest(window=window):
                _, errors = repo_config.validate(routine(dora={"window_days": window, "prod_branch": "main"}))
                self.assertEqual(errors, ["'dora.window_days' must be a positive integer"])
        _, errors = repo_config.validate(routine(dora={"window_days": 1, "prod_branch": "main"}))
        self.assertEqual(errors, [])

    def test_dora_fields_are_checked(self):
        _, errors = repo_config.validate(routine(dora={
            "window": 14, "type": "web", "deploy_source": " ", "tag_pattern": 3,
        }))
        self.assertIn("missing required field 'dora.window_days'", errors)
        self.assertIn("missing required field 'dora.prod_branch'", errors)
        self.assertIn("unknown field 'dora.window'", errors)
        self.assertIn("'dora.type' must be a list", errors)
        self.assertIn("'dora.deploy_source' must not be empty", errors)
        self.assertIn("'dora.tag_pattern' must be a str", errors)
        _, errors = repo_config.validate(routine(dora={"window_days": 7, "prod_branch": "main", "type": [""]}))
        self.assertEqual(errors, ["'dora.type[0]' must be a non-empty string"])

    def test_wrong_types_of_the_routine_fields(self):
        _, errors = repo_config.validate(routine(slack_channel="", audits={}, dora=[]))
        self.assertIn("'slack_channel' must not be empty", errors)
        self.assertIn("'audits' must be a list", errors)
        self.assertIn("'dora' must be a dict", errors)


SHA = "e160a38" + "0" * 33
PINS = {
    "ai_tools_ref": SHA,
    "tools": {"gitleaks": ".github/workflows/ci.yml", "trivy": ".github/actions/setup-trivy/action.yml"},
    "services": [{"name": "postgres", "run": "service postgresql start", "env": {"DATABASE_URL": "postgres://x"}},
                 {"name": "redis", "run": "redis-server --daemonize yes"}],
}


class TestPinFields(unittest.TestCase):
    """ai_tools_ref, tools and services (CLOS-419)."""

    def errors(self, **fields):
        return repo_config.validate(routine(**{**PINS, **fields}))[1]

    def test_valid_fields_are_kept_without_defaults(self):
        config, errors = repo_config.validate(routine(**PINS))
        self.assertEqual(errors, [])
        for key, value in PINS.items():
            self.assertEqual(config[key], value)
        config, _ = repo_config.validate(routine())
        self.assertFalse({"ai_tools_ref", "tools", "services"} & set(config))

    def test_ai_tools_ref_must_be_a_full_lowercase_sha(self):
        for ref in ("e160a38", SHA.upper(), "main", SHA + "0"):
            with self.subTest(ref=ref):
                self.assertEqual(self.errors(ai_tools_ref=ref), [
                    "'ai_tools_ref' must be the 40-character lowercase hex SHA of a somnio-ai-tools commit"])

    def test_tools_are_checked(self):
        self.assertEqual(self.errors(tools={"semgrep": "ci.yml"}),
                         ["'tools.semgrep' is not a tool the routine installs (gitleaks, trivy)"])
        for path in ("/etc/ci.yml", "../other/ci.yml", ".github/../../ci.yml"):
            with self.subTest(path=path):
                self.assertEqual(self.errors(tools={"gitleaks": path}), [
                    "'tools.gitleaks' must be a path relative to the repository root, without '..'"])
        self.assertEqual(self.errors(tools={"trivy": ""}), ["'tools.trivy' must be a non-empty string"])
        self.assertEqual(self.errors(tools={}), ["'tools' must list at least one tool, or be left out"])
        self.assertEqual(self.errors(tools=[]), ["'tools' must be a dict"])

    def test_services_are_checked(self):
        errors = self.errors(services=[
            {"name": "postgres", "run": "a"},
            {"name": "postgres", "run": " "},
            {"name": "redis", "run": "b", "env": {"PORT": 6379}},
            {"run": "c", "timeout": 5},
            "postgres",
        ])
        self.assertEqual(errors, [
            "'services[1].run' must be a non-empty string",
            "'services[1].name' repeats 'postgres'",
            "'services[2].env' must be an object of strings",
            "'services[3].name' must be a non-empty string",
            "unknown field 'services[3].timeout'",
            "'services[4]' must be an object with 'name' and 'run'",
        ])
        self.assertEqual(self.errors(services=[]), ["'services' must list at least one service, or be left out"])
        self.assertEqual(self.errors(services=[{"name": "pg", "run": "x", "env": []}]),
                         ["'services[0].env' must be an object of strings"])

    def test_the_fields_need_no_audits(self):
        self.assertEqual(repo_config.validate(valid(**PINS))[1], [])


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

    def test_a_routine_config_prints_its_audits_with_defaults(self):
        result = self.run_script(self.write(json.dumps(routine())))
        self.assertEqual(result.returncode, 0, result.stderr)
        audits = json.loads(result.stdout)["audits"]
        self.assertEqual(audits[0], {"skill": "security-audit", "path": ".", "report_name": "widgets-platform"})

    def test_the_pin_fields_exit_0_when_valid_and_2_naming_each_error(self):
        result = self.run_script(self.write(json.dumps(routine(**PINS))))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["ai_tools_ref"], SHA)
        bad = routine(ai_tools_ref=SHA[:12], tools={"gitleaks": "/ci.yml"},
                      services=[{"name": "pg", "run": "a"}, {"name": "pg", "run": "", "env": {"X": 1}}])
        result = self.run_script(self.write(json.dumps(bad)))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stderr.splitlines(), [
            "'ai_tools_ref' must be the 40-character lowercase hex SHA of a somnio-ai-tools commit",
            "'tools.gitleaks' must be a path relative to the repository root, without '..'",
            "'services[1].run' must be a non-empty string",
            "'services[1].name' repeats 'pg'",
            "'services[1].env' must be an object of strings",
        ])

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
