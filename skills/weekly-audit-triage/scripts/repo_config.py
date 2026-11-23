#!/usr/bin/env python3
"""Validate a repository's weekly-audit config (.claude/weekly-audit.json).

Prints the config with its defaults applied and exits 0, or prints every error, one per line, and
exits 2. The schema is references/repo-config.md. Usage: repo_config.py <path to weekly-audit.json>
"""
import json
import re
import sys

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
}
IGNORED = {"_comment"}
VERIFY_KEYS = {"name", "run", "when"}
VERIFY_WHEN = {"dependencies"}
SUPPORTED_VERSIONS = {1}


def _is(value, typ) -> bool:
    # bool is a subclass of int in Python; a `true` version is not a version.
    return isinstance(value, typ) and not (typ is int and isinstance(value, bool))


def _strings(key: str, value: list, errors: list) -> None:
    for i, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            errors.append(f"'{key}[{i}]' must be a non-empty string")


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

    config = {k: v for k, v in data.items() if k not in IGNORED}
    if _is(data.get("repo"), str):
        config.setdefault("report_name", data["repo"].split("/")[-1])
    config.setdefault("apps", ["."])
    config.setdefault("excluded_paths", [])
    config.setdefault("ship_skill", None)
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
