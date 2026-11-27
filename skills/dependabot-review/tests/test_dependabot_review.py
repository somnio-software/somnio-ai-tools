"""Tests for scripts/dependabot_review.py: the PRs that need a verdict, and the verdict comment."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "dependabot_review.py")
_spec = importlib.util.spec_from_file_location("dependabot_review", SCRIPT_PATH)
dr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dr)

HEAD = "41d47e3329" + "0" * 30
OTHER = "4f3efe6cf4" + "1" * 30
ME = "routine-account"

# Cut from closebook-finance-platform #339 (a single major) on 2026-11-27.
SINGLE_339 = """Bumps [typescript](https://github.com/microsoft/TypeScript) from 5.9.3 to 7.0.2.
<details>
<summary>Release notes</summary>
<p>Updates `not-a-dependency` from 1.0.0 to 9.0.0 inside the notes is still a line, but not this one.</p>
</details>
"""

# Cut from #480 (a grouped minor-and-patch PR, 65 KB and truncated) on 2026-11-27.
GROUPED_480 = """Bumps the minor-and-patch group with 44 updates in the / directory:

| Package | From | To |
| --- | --- | --- |
| [@aws-sdk/client-s3](https://github.com/aws/aws-sdk-js-v3/tree/HEAD/clients/client-s3) | `3.1161.0` | `3.1174.0` |
| [@opentelemetry/auto-instrumentations-node](https://github.com/open-telemetry/x) | `0.82.0` | `0.83.1` |
| [@types/supertest](https://github.com/DefinitelyTyped/DefinitelyTyped/tree/HEAD/types/supertest) | `6.0.3` | `7.2.1` |
| [jose](https://github.com/panva/jose) | `6.2.15` | `6.2.18` |


Updates `@aws-sdk/client-s3` from 3.1161.0 to 3.1174.0
<details>
<summary>Release notes</summary>
<p><em>Sourced from <a href="https://github.com/aws/aws-sdk-js-v3/releases">@​aws-sdk/client-s3's releases</a>.</em></p>
</details>

_Description has been truncated_"""

# Cut from #478 (a grouped GitHub Actions PR: no table, one 'Updates' line per action).
ACTIONS_478 = """Bumps the actions group with 2 updates in the / directory: [aws-actions/amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login) and [pnpm/action-setup](https://github.com/pnpm/action-setup).

Updates `aws-actions/amazon-ecr-login` from 2.1.7 to 2.2.0
<details>
<summary>Release notes</summary>
</details>

Updates `pnpm/action-setup` from 6.1.0 to 6.1.1
<details>
</details>
"""


def pr(number, head=HEAD, login=dr.BOT, draft=False, state="open", body=SINGLE_339,
       ref="dependabot/npm_and_yarn/typescript-7.0.2"):
    return {"number": number, "state": state, "draft": draft, "user": {"login": login},
            "title": f"chore(deps): #{number}", "html_url": f"https://github.com/o/r/pull/{number}",
            "created_at": "2026-11-23T16:15:00Z", "body": body,
            "head": {"sha": head, "ref": ref}, "base": {"ref": "develop"}}


def comment(cid, login, body):
    return {"id": cid, "user": {"login": login}, "body": body}


def marker(head=HEAD, final="true"):
    return f"<!-- dependabot-review head={head} final={final} -->\n**Dependabot review: needs work**"


class TestParseUpdates(unittest.TestCase):
    def test_a_single_bump(self):
        self.assertEqual(dr.parse_updates(SINGLE_339),
                         [{"package": "typescript", "from": "5.9.3", "to": "7.0.2", "major": True}])

    def test_a_grouped_table_counts_each_update_once(self):
        updates = dr.parse_updates(GROUPED_480)
        self.assertEqual([(u["package"], u["from"], u["to"], u["major"]) for u in updates], [
            ("@aws-sdk/client-s3", "3.1161.0", "3.1174.0", False),
            ("@opentelemetry/auto-instrumentations-node", "0.82.0", "0.83.1", True),
            ("@types/supertest", "6.0.3", "7.2.1", True),
            ("jose", "6.2.15", "6.2.18", False),
        ])

    def test_github_actions_without_a_table(self):
        self.assertEqual(dr.parse_updates(ACTIONS_478), [
            {"package": "aws-actions/amazon-ecr-login", "from": "2.1.7", "to": "2.2.0", "major": False},
            {"package": "pnpm/action-setup", "from": "6.1.0", "to": "6.1.1", "major": False},
        ])

    def test_a_bump_in_a_directory_and_a_zero_width_space_in_the_name(self):
        body = "Bumps [@​nestjs/config](https://x) from 0.3.1 to 0.4.0 in /apps/api."
        self.assertEqual(dr.parse_updates(body),
                         [{"package": "@nestjs/config", "from": "0.3.1", "to": "0.4.0", "major": True}])

    def test_a_body_with_nothing_to_parse(self):
        self.assertEqual(dr.parse_updates("Updates the requirements on [x](https://x) to permit 2."), [])
        self.assertEqual(dr.parse_updates(None), [])


class TestIsMajor(unittest.TestCase):
    def test_the_rule(self):
        for old, new, major in [
            ("5.9.3", "7.0.2", True),
            ("0.3.1", "0.4.0", True),          # 0.x: the minor is the major
            ("0.3.1", "0.3.2", False),
            ("3.1161.0", "3.1174.0", False),
            ("v4", "v5", True),
            ("v4", "v4.2.1", False),
            ("1.0.0-rc.1", "1.0.0", False),
            ("3d3c42e5aac5ba805825da76410c181273ba90b1", "v7.0.1", True),  # a SHA is unknown: major
        ]:
            with self.subTest(old=old, new=new):
                self.assertEqual(dr.is_major(old, new), major)


class TestSelectPending(unittest.TestCase):
    def select(self, pulls, comments=None):
        return dr.select_pending(pulls, comments or {}, ME)

    def test_only_open_non_draft_dependabot_prs(self):
        pulls = [pr(1), pr(2, draft=True), pr(3, login="someone"), pr(4, state="closed"),
                 pr(5, login="dependabot")]
        self.assertEqual([p["number"] for p in self.select(pulls)], [1])

    def test_no_verdict(self):
        [only] = self.select([pr(339)], {339: [comment(1, dr.BOT, "### Labels\n\nnot found")]})
        self.assertEqual((only["why"], only["comment_id"]), ("no verdict", None))
        self.assertEqual(only["head_sha"], HEAD)
        self.assertEqual(only["ecosystem"], "npm_and_yarn")
        self.assertEqual(only["updates"][0]["package"], "typescript")
        self.assertNotIn("body", only)

    def test_a_final_verdict_for_the_head_is_done(self):
        self.assertEqual(self.select([pr(339)], {339: [comment(9, ME, marker())]}), [])

    def test_a_verdict_for_another_head(self):
        [only] = self.select([pr(339)], {339: [comment(9, ME, marker(head=OTHER))]})
        self.assertEqual((only["why"], only["comment_id"]), ("new head", 9))

    def test_a_verdict_not_final(self):
        [only] = self.select([pr(339)], {339: [comment(9, ME, marker(final="false"))]})
        self.assertEqual((only["why"], only["comment_id"]), ("not final", 9))

    def test_the_latest_verdict_of_the_account_wins(self):
        comments = {339: [comment(8, ME, marker(head=OTHER)), comment(9, ME, marker())]}
        self.assertEqual(self.select([pr(339)], comments), [])

    def test_a_marker_from_anyone_else_is_not_a_verdict(self):
        for login in (dr.BOT, "a-person"):
            with self.subTest(login=login):
                [only] = self.select([pr(339)], {339: [comment(9, login, marker())]})
                self.assertEqual((only["why"], only["comment_id"]), ("no verdict", None))

    def test_a_quoted_marker_is_not_a_verdict(self):
        [only] = self.select([pr(339)], {339: [comment(9, ME, "> as said:\n" + marker())]})
        self.assertEqual(only["why"], "no verdict")

    def test_the_ecosystem_of_an_action(self):
        [only] = self.select([pr(478, body=ACTIONS_478, ref="dependabot/github_actions/actions-a5e49fc645")])
        self.assertEqual(only["ecosystem"], "github_actions")


def verdict(**overrides):
    data = {
        "head_sha": HEAD,
        "final": True,
        "verdict": "block",
        "reason": "`typescript` 7 is a native compiler; `ts-jest` keeps a peer on 5.",
        "ci": "11 checks failed: `api-tests` (`error TS5110`).",
        "updates": [{"package": "typescript", "from": "5.9.3", "to": "7.0.2", "major": True,
                     "usages": ["apps/api/tsconfig.json:3", "apps/web/tsconfig.json:4"]}],
    }
    data.update(overrides)
    return data


class TestRender(unittest.TestCase):
    def test_a_valid_body_opens_with_the_marker(self):
        body, errors = dr.render(verdict())
        self.assertEqual(errors, [])
        self.assertTrue(body.startswith(f"<!-- dependabot-review head={HEAD} final=true -->\n"))
        self.assertIn("**Dependabot review: block**", body)
        self.assertIn("**Why:** `typescript` 7 is a native compiler", body)
        self.assertIn("**CI:** 11 checks failed", body)
        self.assertIn("| `typescript` | `5.9.3` | `7.0.2` | yes | `apps/api/tsconfig.json:3`, "
                      "`apps/web/tsconfig.json:4` |", body)
        self.assertIn("never merges", body)
        self.assertEqual(dr.MARKER.match(body).groups(), (HEAD, "true"))

    def test_a_scoped_package_in_backticks_is_not_a_ping(self):
        _, errors = dr.render(verdict(updates=[{"package": "@nestjs/config", "from": "11.0.0",
                                                "to": "12.0.0", "major": True, "usages": []}]))
        self.assertEqual(errors, [])

    def test_not_final_is_in_the_marker_and_the_text(self):
        body, errors = dr.render(verdict(final=False, verdict="needs work"))
        self.assertEqual(errors, [])
        self.assertTrue(body.startswith(f"<!-- dependabot-review head={HEAD} final=false -->"))
        self.assertIn("Not final", body)

    def test_each_reason_to_refuse(self):
        for overrides, error in [
            ({"verdict": "approve"}, "'verdict' must be one of: ready to merge, needs work, block"),
            ({"reason": " "}, "'reason' must be a non-empty string"),
            ({"ci": ""}, "'ci' must be a non-empty string"),
            ({"head_sha": "41d47e3"}, "'head_sha' must be the PR's 40-character head SHA"),
            ({"final": "yes"}, "'final' must be true or false"),
            ({"reason": "ask @rgual-somnio"}, "an '@' outside a code span would ping someone: "
                                              "put package names in backticks"),
            ({"reason": "bumps @nestjs/config"}, "an '@' outside a code span would ping someone: "
                                                 "put package names in backticks"),
            ({"reason": "run `@dependabot rebase`"}, "'@dependabot' appears in the body: from an account "
                                                     "with write access it is a command"),
            ({"ci": "@Dependabot recreate"}, "'@dependabot' appears in the body: from an account "
                                             "with write access it is a command"),
        ]:
            with self.subTest(overrides=overrides):
                _, errors = dr.render(verdict(**overrides))
                self.assertIn(error, errors)


class TestCommandLine(unittest.TestCase):
    def run_script(self, *args):
        return subprocess.run([sys.executable, SCRIPT_PATH, *args], capture_output=True, text=True,
                              env={**os.environ, "PATH": ""})  # no gh: nothing can reach GitHub

    def write(self, data):
        fh = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(data, fh)
        fh.close()
        self.addCleanup(os.unlink, fh.name)
        return fh.name

    def test_comment_prints_the_body(self):
        result = self.run_script("comment", self.write(verdict()))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.startswith("<!-- dependabot-review head="))

    def test_comment_refuses_with_exit_2_and_prints_no_body(self):
        result = self.run_script("comment", self.write(verdict(reason="@dependabot merge")))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("'@dependabot' appears", result.stderr)

    def test_pending_without_gh_exits_2(self):
        result = self.run_script("pending", "somnio-products/closebook-finance-platform")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("nothing may be posted", result.stderr)

    def test_pending_needs_owner_and_name(self):
        result = self.run_script("pending", "closebook")
        self.assertEqual(result.returncode, 2)

    def test_usage(self):
        self.assertEqual(self.run_script("merge", "1").returncode, 2)
        self.assertEqual(self.run_script().returncode, 2)


if __name__ == "__main__":
    unittest.main()
