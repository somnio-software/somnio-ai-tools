#!/usr/bin/env python3
"""Validate a repository's weekly-audit config (.claude/weekly-audit.json).

Prints the config with its defaults applied and exits 0, or prints every error, one per line, and
exits 2. The schema is references/repo-config.md. Usage: repo_config.py <path to weekly-audit.json>
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from report_check import ACCEPTED_TYPES, DORA  # noqa: E402  (sibling module, loaded by path so the script runs from anywhere)

REQUIRED = {
    "version": int,
    "repo": str,
    "jira_project": str,
    "base_branch": str,
    "drive_folder": str,
    "verify": list,
}
OPTIONAL = {
    "report_name": str,
    "apps": list,
    "excluded_paths": list,
    "ship_skill": str,
    "slack_channel": str,
    "audits": list,
    "dora": dict,
    "scheduled_scans": list,
}
IGNORED = {"_comment"}
VERIFY_KEYS = {"name", "run", "when"}
VERIFY_WHEN = {"dependencies"}
SUPPORTED_VERSIONS = {1}
AUDIT_KEYS = {"skill", "path", "report_name"}
# The per-repo keys of dora-metrics' projects.json, plus the run's window. dora_metrics.py checks the
# values of `deploy_source` and `provider` itself.
DORA_KEYS = {"window_days": int, "prod_branch": str, "type": list, "deploy_source": str,
             "tag_pattern": str, "provider": str}
DORA_REQUIRED = {"window_days", "prod_branch"}
# A file name in .github/workflows/, never a path: the triage reads its scheduled runs (CLOS-417).
WORKFLOW_FILE = re.compile(r"[A-Za-z0-9._-]+\.ya?ml")


def _is(value, typ) -> bool:
    # bool is a subclass of int in Python; a `true` version is not a version.
    return isinstance(value, typ) and not (typ is int and isinstance(value, bool))


def _strings(key: str, value: list, errors: list) -> None:
    for i, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            errors.append(f"'{key}[{i}]' must be a non-empty string")


def _audits(data: dict, errors: list) -> None:
    if not data["audits"]:
        errors.append("'audits' must list at least one audit, or be left out")
    for key in ("report_name", "slack_channel"):
        if key not in data:
            errors.append(f"'{key}' is required when 'audits' is given")
    seen = {}
    for i, audit in enumerate(data["audits"]):
        if not isinstance(audit, dict):
            errors.append(f"'audits[{i}]' must be an object with 'skill'")
            continue
        if audit.get("skill") not in ACCEPTED_TYPES:
            errors.append(f"'audits[{i}].skill' must be one of: {', '.join(ACCEPTED_TYPES)}")
        for key in ("path", "report_name"):
            if key in audit and (not isinstance(audit[key], str) or not audit[key].strip()):
                errors.append(f"'audits[{i}].{key}' must be a non-empty string")
        for key in sorted(set(audit) - AUDIT_KEYS):
            errors.append(f"unknown field 'audits[{i}].{key}'")
        # Two audits with the same key and skill write the same file: the second would overwrite the first.
        name = audit.get("report_name", data.get("report_name"))
        if audit.get("skill") in ACCEPTED_TYPES and isinstance(name, str):
            first = seen.setdefault((name, audit["skill"]), i)
            if first != i:
                errors.append(f"'audits[{i}]' writes the same report as 'audits[{first}]'")


def _dora(dora: dict, errors: list) -> None:
    for key, typ in DORA_KEYS.items():
        if key not in dora:
            if key in DORA_REQUIRED:
                errors.append(f"missing required field 'dora.{key}'")
        elif key == "window_days":
            if not _is(dora[key], int) or dora[key] < 1:
                errors.append("'dora.window_days' must be a positive integer")
        elif not _is(dora[key], typ):
            errors.append(f"'dora.{key}' must be a {typ.__name__}")
        elif typ is str and not dora[key].strip():
            errors.append(f"'dora.{key}' must not be empty")
    if _is(dora.get("type"), list):
        _strings("dora.type", dora["type"], errors)
    for key in sorted(set(dora) - set(DORA_KEYS)):
        errors.append(f"unknown field 'dora.{key}'")


def _scheduled_scans(scans: list, errors: list) -> None:
    for i, scan in enumerate(scans):
        if not isinstance(scan, str) or not WORKFLOW_FILE.fullmatch(scan):
            errors.append(f"'scheduled_scans[{i}]' must be a workflow file name in .github/workflows/, "
                          "such as 'vulnerability-scan.yml'")


def validate(data) -> tuple[dict, list]:
    """-> (config with defaults applied, errors). The config is meaningful only without errors."""
    if not isinstance(data, dict):
        return {}, ["the config must be a JSON object"]
    errors = []
    for key, typ in {**REQUIRED, **OPTIONAL}.items():
        if key not in data:
            if key in REQUIRED:
                errors.append(f"missing required field '{key}'")
        elif not _is(data[key], typ):
            errors.append(f"'{key}' must be a {typ.__name__}")
        elif typ is str and not data[key].strip():
            errors.append(f"'{key}' must not be empty")
    for key in sorted(set(data) - set(REQUIRED) - set(OPTIONAL) - IGNORED):
        errors.append(f"unknown field '{key}'")

    if _is(data.get("version"), int) and data["version"] not in SUPPORTED_VERSIONS:
        errors.append(f"unsupported version {data['version']} (supported: 1)")
    if _is(data.get("repo"), str) and not re.fullmatch(r"[\w.-]+/[\w.-]+", data["repo"]):
        errors.append("'repo' must be 'owner/name'")
    if _is(data.get("jira_project"), str) and not re.fullmatch(r"[A-Z][A-Z0-9]+", data["jira_project"]):
        errors.append("'jira_project' must be a Jira project key such as 'CLOS'")

    if _is(data.get("verify"), list):
        if not data["verify"]:
            errors.append("'verify' must list at least one command")
        for i, step in enumerate(data["verify"]):
            if not isinstance(step, dict):
                errors.append(f"'verify[{i}]' must be an object with 'name' and 'run'")
                continue
            for key in ("name", "run"):
                if not isinstance(step.get(key), str) or not step[key].strip():
                    errors.append(f"'verify[{i}].{key}' must be a non-empty string")
            if "when" in step and step["when"] not in VERIFY_WHEN:
                errors.append(f"'verify[{i}].when' must be one of: {', '.join(sorted(VERIFY_WHEN))}")
            for key in sorted(set(step) - VERIFY_KEYS):
                errors.append(f"unknown field 'verify[{i}].{key}'")
    for key in ("apps", "excluded_paths"):
        if _is(data.get(key), list):
            _strings(key, data[key], errors)
    if _is(data.get("apps"), list) and not data["apps"]:
        errors.append("'apps' must list at least one app, or be left out")

    audits = data["audits"] if _is(data.get("audits"), list) else None
    if audits is not None:
        _audits(data, errors)
    if _is(data.get("dora"), dict):
        _dora(data["dora"], errors)
    dora_audit = any(isinstance(audit, dict) and audit.get("skill") == DORA for audit in audits or [])
    if dora_audit and "dora" not in data:
        errors.append(f"'dora' is required when '{DORA}' is an audit")
    if "dora" in data and not dora_audit:
        errors.append(f"'dora' is given but '{DORA}' is not an audit")
    if _is(data.get("scheduled_scans"), list):
        _scheduled_scans(data["scheduled_scans"], errors)

    config = {k: v for k, v in data.items() if k not in IGNORED}
    if _is(data.get("repo"), str):
        config.setdefault("report_name", data["repo"].split("/")[-1])
    config.setdefault("apps", ["."])
    config.setdefault("excluded_paths", [])
    config.setdefault("ship_skill", None)
    config.setdefault("scheduled_scans", [])
    if audits:
        config["audits"] = [
            {"path": ".", "report_name": config.get("report_name"), **audit} if isinstance(audit, dict) else audit
            for audit in audits
        ]
    return config, errors


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        print(f"no config at {sys.argv[1]}", file=sys.stderr)
        return 2
    except (OSError, ValueError) as exc:
        print(f"cannot read the config: {exc}", file=sys.stderr)
        return 2
    config, errors = validate(data)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 2
    json.dump(config, sys.stdout, indent=2, ensure_ascii=False)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
