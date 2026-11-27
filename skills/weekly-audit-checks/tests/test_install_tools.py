"""Tests for scripts/install_tools.py, which installs the scan tools at the version the repository's CI pins."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
import urllib.error

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "install_tools.py")
_spec = importlib.util.spec_from_file_location("install_tools", SCRIPT_PATH)
install_tools = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(install_tools)

# The pins as Closebook's CI writes them (.github/workflows/ci.yml and .github/actions/setup-trivy/action.yml).
CI_YML = """jobs:
  changes:
    env:
      GITLEAKS_VERSION: {version}
      GITLEAKS_SHA256: {sha}
      BASE_SHA: ${{{{ github.event.pull_request.base.sha }}}}
    steps:
      - name: Install Gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v${{GITLEAKS_VERSION}}/gitleaks_${{GITLEAKS_VERSION}}_linux_x64.tar.gz"
          echo "${{GITLEAKS_SHA256}}  gitleaks.tar.gz" | sha256sum -c -
"""
SETUP_TRIVY = """runs:
  using: composite
  steps:
    - name: Install Trivy
      shell: bash
      env:
        TRIVY_VERSION: {version}
        TRIVY_SHA256: {sha}
"""
GITLEAKS_URL = "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz"
TRIVY_URL = "https://github.com/aquasecurity/trivy/releases/download/v0.76.0/trivy_0.76.0_Linux-64bit.tar.gz"


def tarball(name: str, content: bytes = b"#!/bin/sh\necho binary\n") -> bytes:
    """A release asset holding `name`, plus the LICENSE and README the real ones carry."""
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        for member, data in ((name, content), ("LICENSE", b"MIT"), ("README.md", b"readme")):
            info = tarfile.TarInfo(member)
            info.size = len(data)
            archive.addfile(info, io.BytesIO(data))
    return buffer.getvalue()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Opener:
    """A stub of urllib.request.urlopen: serves `assets` by URL, raises HTTP 404 for anything else."""

    def __init__(self, assets: dict):
        self.assets = assets
        self.requested = []

    def __call__(self, url, timeout=None):
        self.requested.append((url, timeout))
        if isinstance(self.assets.get(url), Exception):
            raise self.assets[url]
        if url not in self.assets:
            raise urllib.error.HTTPError(url, 404, "Not Found", {}, None)
        return io.BytesIO(self.assets[url])


class InstallTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = os.path.join(tmp.name, "repo")
        self.bin = os.path.join(tmp.name, "bin")
        self.gitleaks = tarball("gitleaks")
        self.trivy = tarball("trivy")
        self.ci(CI_YML.format(version="8.30.1", sha=sha(self.gitleaks)),
                SETUP_TRIVY.format(version="0.76.0", sha=sha(self.trivy)))
        self.config = os.path.join(tmp.name, "config.json")
        with open(self.config, "w", encoding="utf-8") as fh:
            json.dump({"repo": "acme/widgets", "tools": {
                "gitleaks": ".github/workflows/ci.yml", "trivy": ".github/actions/setup-trivy/action.yml"}}, fh)

    def ci(self, ci_yml=None, setup_trivy=None):
        for path, text in ((".github/workflows/ci.yml", ci_yml), (".github/actions/setup-trivy/action.yml",
                                                                    setup_trivy)):
            if text is not None:
                os.makedirs(os.path.dirname(os.path.join(self.root, path)), exist_ok=True)
                with open(os.path.join(self.root, path), "w", encoding="utf-8") as fh:
                    fh.write(text)

    def run_main(self, opener):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = install_tools.main([self.config, self.root, self.bin], opener)
        return code, out.getvalue().splitlines()


class TestPins(InstallTest):
    def test_the_version_and_sha256_are_read_from_ci_shaped_files(self):
        text = CI_YML.format(version="8.30.1", sha="a" * 64)
        self.assertEqual(install_tools.pinned("gitleaks", "ci.yml", text), {"VERSION": "8.30.1", "SHA256": "a" * 64})
        text = SETUP_TRIVY.format(version='"0.76.0"', sha="b" * 64)
        self.assertEqual(install_tools.pinned("trivy", "action.yml", text)["VERSION"], "0.76.0")

    def test_a_repeated_identical_value_is_fine(self):
        text = CI_YML.format(version="8.30.1", sha="a" * 64) * 2
        self.assertEqual(install_tools.pinned("gitleaks", "ci.yml", text)["VERSION"], "8.30.1")

    def test_a_missing_value_names_the_file(self):
        text = CI_YML.format(version="8.30.1", sha="a" * 64).replace("GITLEAKS_SHA256:", "# GITLEAKS_SHA256:")
        with self.assertRaisesRegex(install_tools.Failure, r"^no GITLEAKS_SHA256 in ci\.yml$"):
            install_tools.pinned("gitleaks", "ci.yml", text)

    def test_two_different_values_name_the_file(self):
        text = CI_YML.format(version="8.30.1", sha="a" * 64) + "      GITLEAKS_VERSION: 8.28.0\n"
        with self.assertRaisesRegex(install_tools.Failure, r"^ci\.yml sets GITLEAKS_VERSION to 8\.28\.0 and 8\.30\.1$"):
            install_tools.pinned("gitleaks", "ci.yml", text)

    def test_a_value_of_the_wrong_shape(self):
        text = CI_YML.format(version="${{ vars.GITLEAKS }}", sha="a" * 64)
        with self.assertRaisesRegex(install_tools.Failure, "not a version"):
            install_tools.pinned("gitleaks", "ci.yml", text)


class TestInstall(InstallTest):
    def test_good_tarballs_leave_executable_binaries(self):
        opener = Opener({GITLEAKS_URL: self.gitleaks, TRIVY_URL: self.trivy})
        self.assertEqual(self.run_main(opener), (0, ["OK gitleaks 8.30.1", "OK trivy 0.76.0"]))
        for tool in ("gitleaks", "trivy"):
            path = os.path.join(self.bin, tool)
            self.assertTrue(os.access(path, os.X_OK), path)
        self.assertEqual(sorted(os.listdir(self.bin)), ["gitleaks", "trivy"])
        self.assertEqual({timeout for _, timeout in opener.requested}, {60})

    def test_a_hash_mismatch_writes_nothing_and_the_other_tool_still_installs(self):
        opener = Opener({GITLEAKS_URL: tarball("gitleaks", b"tampered"), TRIVY_URL: self.trivy})
        code, lines = self.run_main(opener)
        self.assertEqual(code, 2)
        self.assertEqual(lines[1], "OK trivy 0.76.0")
        self.assertRegex(lines[0], rf"^FAIL gitleaks: sha256 of {GITLEAKS_URL} is [0-9a-f]{{64}}, "
                                   rf"\.github/workflows/ci\.yml pins {sha(self.gitleaks)}$")
        self.assertEqual(os.listdir(self.bin), ["trivy"])

    def test_a_missing_pin_fails_naming_the_file_and_downloads_nothing(self):
        self.ci(ci_yml="jobs: {}\n")
        opener = Opener({GITLEAKS_URL: self.gitleaks, TRIVY_URL: self.trivy})
        code, lines = self.run_main(opener)
        self.assertEqual((code, lines), (2, ["FAIL gitleaks: no GITLEAKS_VERSION in .github/workflows/ci.yml",
                                             "OK trivy 0.76.0"]))
        self.assertEqual([url for url, _ in opener.requested], [TRIVY_URL])

    def test_download_errors_fail_without_a_retry(self):
        opener = Opener({TRIVY_URL: urllib.error.URLError("timed out")})
        code, lines = self.run_main(opener)
        self.assertEqual(code, 2)
        self.assertEqual(lines, [f"FAIL gitleaks: {GITLEAKS_URL} returned HTTP 404",
                                 f"FAIL trivy: cannot download {TRIVY_URL}: <urlopen error timed out>"])
        self.assertEqual(len(opener.requested), 2)
        self.assertFalse(os.path.exists(self.bin))

    def test_an_archive_without_the_binary(self):
        other = tarball("gitleaks-darwin")
        self.ci(ci_yml=CI_YML.format(version="8.30.1", sha=sha(other)))
        code, lines = self.run_main(Opener({GITLEAKS_URL: other, TRIVY_URL: self.trivy}))
        self.assertEqual((code, lines[0]), (2, "FAIL gitleaks: the archive has no 'gitleaks' file"))

    def test_a_missing_ci_file(self):
        os.remove(os.path.join(self.root, ".github/actions/setup-trivy/action.yml"))
        code, lines = self.run_main(Opener({GITLEAKS_URL: self.gitleaks}))
        self.assertEqual(code, 2)
        self.assertTrue(lines[1].startswith("FAIL trivy: cannot read .github/actions/setup-trivy/action.yml:"), lines)

    def test_a_config_without_tools_installs_nothing(self):
        with open(self.config, "w", encoding="utf-8") as fh:
            json.dump({"repo": "acme/widgets"}, fh)
        self.assertEqual(self.run_main(Opener({})), (0, []))


class TestCommandLine(unittest.TestCase):
    def test_usage_and_an_unreadable_config_exit_2(self):
        for args in ((), ("config.json", "."), (os.path.join(tempfile.gettempdir(), "no-such.json"), ".", "bin")):
            with self.subTest(args=args):
                result = subprocess.run([sys.executable, SCRIPT_PATH, *args], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertTrue("Usage" in result.stderr or "cannot read the config" in result.stderr)


if __name__ == "__main__":
    unittest.main()
