#!/usr/bin/env python3
"""The weekly-audit fixer's gates, run on a committed ticket branch before anything is pushed.

Usage: fixer_gates.py --config <validated config JSON> [--repo <worktree>]

The config is what weekly-audit-triage's repo_config.py printed for the repository's default branch.
In order: the tree is clean; the diff against the merge base with origin/<base_branch> is not empty,
has at most MAX_LINES changed lines in at most MAX_APPS of the config's apps and no excluded path;
every receipt the base branch's .claude/ship-gate.json requires has a `verify` command. Then it runs the
`verify` commands and checks they left the tree clean. It prints one line per gate and ends with
`RESULT: PASS` or `RESULT: FAIL <gates>`.

Exit 0: every gate passed. 1: a gate failed. 2: it could not run (bad config, no origin/<base_branch>,
no merge base). The fixer pushes nothing unless it exits 0.
"""
import argparse
import fnmatch
import json
import os
import re
import signal
import subprocess
import sys

MAX_LINES = 400
MAX_APPS = 2
TIMEOUT_SECONDS = 1800
TAIL_LINES = 40
CONFIG_FIELDS = {"base_branch": str, "apps": list, "excluded_paths": list, "verify": list}

# The weekly-audit-triage skill's exclusion floor (its section 5), where it is a path, plus the files
# that define this gate and the reviewer. A change to one list is made in the other.
EXCLUDED_DIRS_ANY_DEPTH = ("infra/", "deploy/", "migrations/")
EXCLUDED_ROOT_PATHS = (
    ".github/workflows/",
    ".claude/weekly-audit.json",
    ".claude/ship-gate.json",
    ".claude/agents/",
)
EXCLUDED_FILE_PATTERNS = (".env", ".env.*", "*.pem", "*.key")

# Manifests and lockfiles, by basename: a `when: "dependencies"` command runs when one of them changed.
DEPENDENCY_FILES = (
    "package.json", "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml",
    "pnpm-workspace.yaml", "yarn.lock",  # npm, pnpm, yarn
    "pubspec.yaml", "pubspec.lock",  # pub
    "requirements*.txt", "Pipfile", "Pipfile.lock", "setup.py", "setup.cfg",  # pip
    "pyproject.toml", "poetry.lock", "uv.lock",  # poetry, uv
    "go.mod", "go.sum", "Cargo.toml", "Cargo.lock", "Gemfile", "Gemfile.lock",
    "composer.json", "composer.lock",
    "*.csproj", "packages.config", "packages.lock.json", "Directory.Packages.props",  # NuGet
    "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
    "gradle.lockfile", "libs.versions.toml",  # Gradle
    "pom.xml", "Podfile", "Podfile.lock",  # Maven, CocoaPods
)

# A failing command's output goes into a Jira comment: a net for an accidental echo, not a scrubber.
SECRET_LINE = re.compile(r"(?i)(token|secret|password|api[_-]?key|authorization)\s*[:=]")


class CannotRun(Exception):
    """The gates could not be evaluated: exit 2."""


def emit(line):
    print(line, flush=True)  # flushed: the commands can run for minutes, and the log shows progress


def git(repo, *args, check=True):
    proc = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, errors="replace")
    if check and proc.returncode != 0:
        raise CannotRun(f"git {' '.join(args)}: {proc.stderr.strip()}")
    return proc


def norm(path):
    path = path.strip()
    while path.startswith("./"):
        path = path[2:]
    return path.rstrip("/") or "."


def under(path, entry):
    """Whether `path` is `entry` itself or anything under it. Case-sensitive, as git paths are."""
    entry = norm(entry)
    return entry == "." or path == entry or path.startswith(entry + "/")


def excluded_by(path, excluded_paths):
    """-> the config entry or built-in that excludes `path`, or None."""
    for entry in (*excluded_paths, *EXCLUDED_ROOT_PATHS):
        if under(path, entry):
            return entry
    *dirs, name = path.split("/")
    for part in dirs:
        if part + "/" in EXCLUDED_DIRS_ANY_DEPTH:
            return part + "/"
    for pattern in EXCLUDED_FILE_PATTERNS:
        if fnmatch.fnmatchcase(name, pattern):
            return pattern
    return None


def is_dependency_file(path):
    name = path.rsplit("/", 1)[-1]
    return any(fnmatch.fnmatchcase(name, pattern) for pattern in DEPENDENCY_FILES)


def redact(line):
    match = SECRET_LINE.search(line)
    return line[: match.end()] + "[redacted]" if match else line


def changed_files(repo, merge_base):
    """-> [(path, changed lines, or None for a binary file)] from the merge base to HEAD."""
    out = git(repo, "diff", "--numstat", "--no-renames", "-z", merge_base, "HEAD").stdout
    files = []
    for record in filter(None, out.split("\0")):
        added, deleted, path = record.split("\t", 2)
        files.append((path, None if added == "-" else int(added) + int(deleted)))
    return files


def dirty_paths(repo, untracked):
    mode = "normal" if untracked else "no"
    out = git(repo, "status", "--porcelain", f"--untracked-files={mode}").stdout
    return [line[3:] for line in out.splitlines() if line]


def read_ship_gate(repo, base_ref):
    """-> the base branch's .claude/ship-gate.json, or None when it has none. ValueError if invalid."""
    blob = f"{base_ref}:.claude/ship-gate.json"
    if git(repo, "cat-file", "-e", blob, check=False).returncode:
        return None
    return json.loads(git(repo, "show", blob).stdout)


def check_receipts(ship_gate, verify):
    """-> (commands the receipts require, failures, requirement names that are not receipts)."""
    required = ship_gate.get("required", []) if isinstance(ship_gate, dict) else None
    if not isinstance(required, list):
        return set(), ["'required' is not a list"], []
    runs = {step["run"] for step in verify}
    must_run, failures, not_checked = set(), [], []
    for entry in required:
        name = entry.get("name") if isinstance(entry, dict) else entry
        if not (isinstance(entry, dict) and entry.get("receipt")):
            not_checked.append(str(name))
        elif not isinstance(entry.get("expect_cmd"), str):
            # ponytail: no expect_cmd means any command satisfies the ship gate, so no verify entry can
            # be said to stand for it; fail closed until the repository names the command.
            failures.append(f"{name} names no expect_cmd")
        elif entry["expect_cmd"] not in runs:
            failures.append(f"{name} ({entry['expect_cmd']}) has no verify command")
        else:
            must_run.add(entry["expect_cmd"])
    return must_run, failures, not_checked


def run_command(command, repo):
    """-> (exit status, or None if it timed out, combined output). The whole process group dies on a
    timeout, so a grandchild holding the pipe cannot hang the gate."""
    proc = subprocess.Popen(
        command, shell=True, cwd=repo, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, errors="replace", start_new_session=True,
    )
    try:
        output = proc.communicate(timeout=TIMEOUT_SECONDS)[0]
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        return None, proc.communicate()[0]
    return proc.returncode, output


def load_config(path):
    try:
        with open(path, encoding="utf-8") as fh:
            config = json.load(fh)
    except (OSError, ValueError) as exc:
        raise CannotRun(f"cannot read the config: {exc}")
    if not isinstance(config, dict):
        raise CannotRun("the config must be a JSON object")
    bad = [key for key, typ in CONFIG_FIELDS.items() if not isinstance(config.get(key), typ)]
    if not bad and not all(isinstance(s, dict) and isinstance(s.get("run"), str) for s in config["verify"]):
        bad = ["verify"]
    if bad:
        raise CannotRun("the config lacks or mistypes: " + ", ".join(bad))
    return config


def run_gates(config, repo):
    """Emits one line per gate; -> the names of the gates that failed."""
    base_ref = f"origin/{config['base_branch']}"
    if git(repo, "rev-parse", "--verify", "--quiet", base_ref + "^{commit}", check=False).returncode:
        raise CannotRun(f"no {base_ref}: fetch it first")
    proc = git(repo, "merge-base", base_ref, "HEAD", check=False)
    if proc.returncode:
        raise CannotRun(f"no merge base between {base_ref} and HEAD")
    merge_base = proc.stdout.strip()
    emit(f"checked {git(repo, 'rev-parse', 'HEAD').stdout.strip()} against {base_ref} ({merge_base})")
    failed = []

    def gate(name, failure, detail=""):
        if failure:
            failed.append(name)
            emit(f"{name}: FAIL {failure}")
        else:
            emit(f"{name}: pass" + (f" ({detail})" if detail else ""))

    dirty = dirty_paths(repo, untracked=True)
    gate("uncommitted", dirty and "not committed: " + ", ".join(dirty))

    files = changed_files(repo, merge_base)
    gate("empty", not files and f"no change against {base_ref}")

    binary = [path for path, lines in files if lines is None]
    total = sum(lines for _, lines in files if lines is not None)
    if binary:
        size_failure = "binary file, its lines cannot be counted: " + ", ".join(binary)
    elif total > MAX_LINES:
        size_failure = f"{total} changed lines, limit {MAX_LINES}"
    else:
        size_failure = None
    gate("size", size_failure, f"{total} lines")

    touched = [app for app in config["apps"] if any(under(path, app) for path, _ in files)]
    gate(
        "apps",
        len(touched) > MAX_APPS and f"touches {len(touched)} apps, limit {MAX_APPS}: " + ", ".join(touched),
        ", ".join(touched) or "no app",
    )

    hits = [(path, excluded_by(path, config["excluded_paths"])) for path, _ in files]
    gate("paths", ", ".join(f"{path} ({entry})" for path, entry in hits if entry))

    must_run = set()
    try:
        ship_gate = read_ship_gate(repo, base_ref)
    except ValueError as exc:
        gate("receipts", f".claude/ship-gate.json on {base_ref} is not valid JSON: {exc}")
    else:
        if ship_gate is None:
            gate("receipts", None, f"no .claude/ship-gate.json on {base_ref}: the config's verify is the list")
        else:
            must_run, failures, not_checked = check_receipts(ship_gate, config["verify"])
            detail = (f"always run: {', '.join(sorted(must_run)) or 'none'}; "
                      f"not checked: {', '.join(not_checked) or 'none'}")
            gate("receipts", "; ".join(failures), detail)

    if failed:
        emit("verify: not run, a gate above failed")
        return failed

    dependencies_changed = any(is_dependency_file(path) for path, _ in files)
    failure = None
    for step in config["verify"]:
        name = step.get("name", step["run"])
        if failure:
            emit(f"  {name}: not run")
            continue
        if step.get("when") == "dependencies" and not dependencies_changed and step["run"] not in must_run:
            emit(f"  {name}: skipped, no dependency file changed")
            continue
        code, output = run_command(step["run"], repo)
        status = f"timed out after {TIMEOUT_SECONDS} s" if code is None else f"exit {code}"
        emit(f"  {name}: {status}")
        if code != 0:
            failure = f"{name} ({status})"
            tail = output.rstrip("\n").splitlines()[-TAIL_LINES:]
            emit(f"  last {len(tail)} lines of {name}:")
            for line in tail:
                emit("    " + redact(line))
    gate("verify", failure)

    dirty = dirty_paths(repo, untracked=False)
    gate("uncommitted", dirty and "verify changed tracked files: " + ", ".join(dirty), "after verify")
    return failed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--config", required=True, help="the validated config, as JSON")
    parser.add_argument("--repo", default=".", help="the ticket's worktree (default: .)")
    args = parser.parse_args(argv)

    try:
        failed = run_gates(load_config(args.config), args.repo)
    except CannotRun as exc:
        emit(f"could not run: {exc}")
        return 2
    except Exception as exc:  # fail closed: anything unexpected is "could not run", never a pass
        emit(f"could not run: {type(exc).__name__}: {exc}")
        return 2
    if failed:
        emit("RESULT: FAIL " + " ".join(dict.fromkeys(failed)))
        return 1
    emit("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
