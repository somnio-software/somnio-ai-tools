#!/usr/bin/env python3
"""Install the scan tools with the version and sha256 the repository's CI pins (CLOS-419 D2).

Usage: install_tools.py <validated config JSON> <repo root> <bin dir>

For each entry of the config's `tools` (tool -> repository file), reads exactly one `<TOOL>_VERSION:` and
one `<TOOL>_SHA256:` value from that file, downloads the linux x64 release asset CI downloads, checks its
sha256 before extracting anything, and writes the binary to `<bin dir>/<tool>`. Prints `OK <tool>
<version>` or `FAIL <tool>: <reason>` for every tool, and exits 0 when all are OK, 2 otherwise.
"""
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.error
import urllib.request

# The asset each CI file downloads; repo_config.py's TOOLS lists the same names.
ASSETS = {
    "gitleaks": "https://github.com/gitleaks/gitleaks/releases/download/v{v}/gitleaks_{v}_linux_x64.tar.gz",
    "trivy": "https://github.com/aquasecurity/trivy/releases/download/v{v}/trivy_{v}_Linux-64bit.tar.gz",
}
TIMEOUT = 60  # seconds, per network operation; no retry
VALUES = {"VERSION": re.compile(r"\d+\.\d+\.\d+"), "SHA256": re.compile(r"[0-9a-f]{64}")}


class Failure(Exception):
    pass


def pinned(tool: str, path: str, text: str) -> dict:
    """-> {"VERSION": …, "SHA256": …} from the CI file's text; Failure naming the file otherwise."""
    found = {}
    for name, shape in VALUES.items():
        key = f"{tool.upper()}_{name}"
        values = set(re.findall(rf"^[ \t]*{key}:[ \t]*[\"']?([^\"'\s#]+)", text, re.MULTILINE))
        if not values:
            raise Failure(f"no {key} in {path}")
        if len(values) > 1:
            raise Failure(f"{path} sets {key} to {' and '.join(sorted(values))}")
        found[name] = values.pop()
        if not shape.fullmatch(found[name]):
            raise Failure(f"{key} in {path} is '{found[name]}', not a {name.lower()}")
    return found


def install(tool: str, path: str, repo_root: str, bin_dir: str, opener=urllib.request.urlopen) -> str:
    """-> the installed version; Failure with the reason otherwise. Writes nothing unless the hash matches."""
    if tool not in ASSETS:
        raise Failure(f"not a tool this script installs ({', '.join(ASSETS)})")
    try:
        with open(os.path.join(repo_root, path), encoding="utf-8") as fh:
            pin = pinned(tool, path, fh.read())
    except (OSError, UnicodeDecodeError) as exc:
        raise Failure(f"cannot read {path}: {exc}") from None
    url = ASSETS[tool].format(v=pin["VERSION"])
    try:
        with opener(url, timeout=TIMEOUT) as response:
            data = response.read()
    except urllib.error.HTTPError as exc:
        exc.close()
        raise Failure(f"{url} returned HTTP {exc.code}") from None
    except OSError as exc:  # URLError and timeouts included
        raise Failure(f"cannot download {url}: {exc}") from None
    digest = hashlib.sha256(data).hexdigest()
    if digest != pin["SHA256"]:
        raise Failure(f"sha256 of {url} is {digest}, {path} pins {pin['SHA256']}")
    try:
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            member = next((m for m in archive.getmembers() if m.name == tool and m.isfile()), None)
            if member is None:
                raise Failure(f"the archive has no '{tool}' file")
            binary = archive.extractfile(member).read()
    except tarfile.TarError as exc:
        raise Failure(f"cannot read the archive: {exc}") from None
    os.makedirs(bin_dir, exist_ok=True)
    target = os.path.join(bin_dir, tool)
    with open(target, "wb") as fh:
        fh.write(binary)
    os.chmod(target, 0o755)
    return pin["VERSION"]


def main(argv: list, opener=urllib.request.urlopen) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(argv[0], encoding="utf-8") as fh:
            tools = json.load(fh).get("tools") or {}
    except (OSError, ValueError, AttributeError) as exc:
        print(f"cannot read the config: {exc}", file=sys.stderr)
        return 2
    failed = False
    for tool, path in tools.items():
        try:
            print(f"OK {tool} {install(tool, path, argv[1], argv[2], opener)}")
        except (Failure, OSError) as exc:
            print(f"FAIL {tool}: {exc}")
            failed = True
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
