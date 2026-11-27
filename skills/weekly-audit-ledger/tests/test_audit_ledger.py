"""Tests for scripts/audit_ledger.py, the "Audit pending" section of TL watch.

The literals pinned here belong to other skills: the run label `weekly-audit-run-<DATE>` and the comment
`Still present in the <DATE> run.` (weekly-audit-triage), and the branch `fix|chore/<KEY>-n-<slug>`
(weekly-audit-fixer). A change to one of them there must update these tests in the same PR.
"""
import contextlib
import importlib.util
import io
import json
import os
import shutil
import tempfile
import unittest

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "scripts", "audit_ledger.py")
_spec = importlib.util.spec_from_file_location("audit_ledger", SCRIPT_PATH)
ledger = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ledger)

NOW = ledger.parse_time("2026-11-27T12:00:00Z")
REPO = "acme/widgets"


def issue(key, *tags, status="new", created="2026-11-09T17:14:31.214-0300", summary=None, parent=None, comments=()):
    fields = {
        "summary": summary or f"Fix {key}",
        "status": {"name": "x", "statusCategory": {"key": status}},
        "labels": ["weekly-audit", *tags],
        "created": created,
        "comment": {"comments": list(comments), "total": len(comments)},
    }
    if parent:
        fields["parent"] = {"key": parent}
    return {"key": key, "fields": fields}


def md(date):
    return {"id": "1", "body": f"Still present in the {date} run."}


def adf(date):
    return {"id": "2", "body": {"type": "doc", "version": 1, "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": f"Still present in the {date} run."}]}]}}


def pr(number, branch, created="2026-11-23T12:00:00Z", draft=False, author="fixer-dev", reviews=()):
    return {
        "number": number, "title": f"fix: {branch}", "url": f"https://github.com/{REPO}/pull/{number}",
        "headRefName": branch, "isDraft": draft, "createdAt": created,
        "author": {"login": author, "is_bot": False},
        "reviews": [{"author": {"login": login}, "state": state} for login, state in reviews],
    }


class Folder(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dir)

    def write(self, name, data):
        with open(os.path.join(self.dir, name), "w", encoding="utf-8") as fh:
            fh.write(data if isinstance(data, str) else json.dumps(data))

    def setup_repo(self, issues=(), prs=(), name="widgets", project="WID"):
        self.write(f"{name}.config.json", {"repo": f"acme/{name}", "jira_project": project})
        self.write(f"{project}.jira.1.json", {"issues": list(issues)})
        self.write(f"{name}.prs.json", list(prs))

    def section(self, *repos, now=NOW):
        return ledger.build_section(self.dir, list(repos or [REPO]), now)

    def line(self, prefix, *repos):
        return next(l for l in self.section(*repos).splitlines() if l.startswith(prefix))


class TestWaiting(Folder):
    def test_lists_open_auto_fixable_without_a_decision_oldest_first(self):
        self.setup_repo([
            issue("WID-3", "audit-auto-fixable", created="2026-11-20T10:00:00Z"),
            issue("WID-1", "audit-auto-fixable", created="2026-11-09T17:14:31.214-0300"),
            issue("WID-4", "audit-auto-fixable", "audit-approved"),
            issue("WID-5", "audit-auto-fixable", "audit-needs-human"),
            issue("WID-6", "audit-auto-fixable", "wont-do"),
            issue("WID-7", "audit-auto-fixable", status="done"),
            issue("WID-8", "audit-needs-human"),
        ])
        self.assertEqual(
            self.line("- Waiting"),
            '- Waiting for audit-approved (2): WID-1 "Fix WID-1" 18d; WID-3 "Fix WID-3" 7d',
        )


class TestUnreviewed(Folder):
    def run_prs(self, *prs):
        self.setup_repo([
            issue("WID-1", "audit-auto-fixable", "audit-approved"),
            issue("WID-2", "audit-auto-fixable"),
            issue("WID-3", "audit-auto-fixable", "audit-approved", status="done"),
        ], prs)
        return self.line("- Fixer PRs")

    def test_lists_a_ready_unreviewed_fixer_pr_after_72_hours(self):
        self.assertEqual(
            self.run_prs(pr(10, "fix/WID-1-n-remove-lodash", created="2026-11-24T11:00:00Z")),
            f"- Fixer PRs without review for more than 3 days (1): #10 https://github.com/{REPO}/pull/10 (WID-1) 3d",
        )

    def test_chore_branch_counts(self):
        self.assertIn("(1)", self.run_prs(pr(11, "chore/WID-1-n-format")))

    def test_age_boundaries(self):
        self.assertIn("(0)", self.run_prs(pr(10, "fix/WID-1-n-x", created="2026-11-24T13:00:00Z")))  # 71 h
        self.assertIn("(0)", self.run_prs(pr(10, "fix/WID-1-n-x", created="2026-11-24T12:00:00Z")))  # 72 h
        self.assertIn("(1)", self.run_prs(pr(10, "fix/WID-1-n-x", created="2026-11-24T08:59:00-0200")))  # 73 h

    def test_reviews_by_the_author_or_a_bot_do_not_count(self):
        line = self.run_prs(pr(10, "fix/WID-1-n-x", reviews=[
            ("fixer-dev", "COMMENTED"), ("automata-ai-bot", "APPROVED"),
            ("copilot-pull-request-reviewer", "COMMENTED"), ("dependabot[bot]", "COMMENTED"),
        ]))
        self.assertIn("(1)", line)

    def test_one_human_review_of_any_state_removes_it(self):
        for state in ("APPROVED", "CHANGES_REQUESTED", "COMMENTED", "DISMISSED"):
            self.assertIn("(0)", self.run_prs(pr(10, "fix/WID-1-n-x", reviews=[("tl", state)])), state)

    def test_not_listed(self):
        cases = {
            "draft": pr(10, "fix/WID-1-n-x", draft=True),
            "unapproved ticket": pr(10, "fix/WID-2-n-x"),
            "done ticket": pr(10, "fix/WID-3-n-x"),
            "another project": pr(10, "fix/OTHER-1-n-x"),
            "unknown ticket": pr(10, "fix/WID-99-n-x"),
            "feat branch": pr(10, "feat/WID-1-n-x"),
            "no slug": pr(10, "fix/WID-1"),
        }
        for name, case in cases.items():
            self.assertIn("(0)", self.run_prs(case), name)

    def test_prs_of_every_repository_of_the_project_are_read(self):
        self.setup_repo([issue("WID-1", "audit-auto-fixable", "audit-approved")], [pr(10, "fix/WID-1-n-x")])
        self.write("gadgets.config.json", {"repo": "acme/gadgets", "jira_project": "WID"})
        self.write("gadgets.prs.json", [pr(20, "chore/WID-1-n-y", created="2026-11-20T12:00:00Z")])
        section = self.section(REPO, "acme/gadgets")
        self.assertIn("WID · acme/widgets, acme/gadgets", section)
        self.assertIn("(2): #20 ", section)


class TestNotSeen(Folder):
    def runs(self, *dates):
        # Run dates come from any issue of the project, a Done one included.
        return issue("WID-90", *(f"weekly-audit-run-{d}" for d in dates), status="done")

    def listed(self, *issues):
        self.setup_repo(issues)
        return ledger.not_seen(ledger.load_issues(self.dir, "WID", []))

    def test_lists_a_finding_two_runs_have_not_seen(self):
        self.setup_repo([
            self.runs("2026-11-09", "2026-11-16", "2026-11-23"),
            issue("WID-1", "audit-fp-abc", "weekly-audit-run-2026-11-09", parent="WID-50"),
        ])
        self.assertEqual(
            self.line("- Audit tickets"),
            '- Audit tickets not seen in the last 2 runs, can be closed (1): '
            'WID-1 "Fix WID-1" (task WID-50) last seen 2026-11-09',
        )

    def test_seen_in_the_latest_run_or_missing_only_one(self):
        self.assertEqual(self.listed(
            self.runs("2026-11-09", "2026-11-16", "2026-11-23"),
            issue("WID-1", "audit-fp-a", "weekly-audit-run-2026-11-09", comments=[md("2026-11-23")]),
            issue("WID-2", "audit-fp-b", "weekly-audit-run-2026-11-09", comments=[adf("2026-11-16")]),
        ), [])

    def test_comments_in_markdown_and_adf_both_count_as_seen_and_as_runs(self):
        self.assertEqual(self.listed(
            issue("WID-1", "audit-fp-a", created="2026-11-09T10:00:00Z"),
            issue("WID-2", "audit-fp-b", comments=[md("2026-11-16")]),
            issue("WID-3", "audit-fp-c", comments=[adf("2026-11-23")]),
        ), ['WID-1 "Fix WID-1" last seen 2026-11-09'])

    def test_creation_counts_as_seen(self):
        self.assertEqual(self.listed(
            self.runs("2026-11-09", "2026-11-16", "2026-11-23"),
            issue("WID-1", "audit-fp-a", created="2026-11-17T10:00:00Z"),
        ), [])

    def test_not_listed_without_a_fingerprint_when_done_or_wont_do(self):
        self.assertEqual(self.listed(
            self.runs("2026-11-09", "2026-11-16", "2026-11-23"),
            issue("WID-1", "weekly-audit-run-2026-11-09"),
            issue("WID-2", "audit-fp-b", "weekly-audit-run-2026-11-09", status="done"),
            issue("WID-3", "audit-fp-c", "weekly-audit-run-2026-11-09", "wont-do"),
        ), [])


class TestSection(Folder):
    def test_header_and_nothing_pending(self):
        self.setup_repo([issue("WID-1", "audit-auto-fixable", "audit-approved")])
        self.assertEqual(self.section(), "Audit pending — 2026-11-27 UTC\nWID · acme/widgets\nNothing pending.")

    def test_missing_config_jira_and_prs_are_could_not_see(self):
        self.write("widgets.config.json", {"repo": REPO, "jira_project": "WID"})
        self.write("gadgets.config.json", "{not json")
        self.assertEqual(
            self.section(REPO, "acme/gadgets", "acme/tools"),
            "Audit pending — 2026-11-27 UTC\n"
            "WID · acme/widgets\n"
            "- Could not see: Jira issues of WID; open PRs of acme/widgets\n"
            "acme/gadgets\n"
            "- Could not see: no valid .claude/weekly-audit.json on its default branch\n"
            "acme/tools\n"
            "- Could not see: no valid .claude/weekly-audit.json on its default branch",
        )

    def test_a_missing_pr_file_keeps_the_lists(self):
        self.setup_repo([issue("WID-1", "audit-auto-fixable")])
        os.remove(os.path.join(self.dir, "widgets.prs.json"))
        lines = self.section().splitlines()
        self.assertIn("- Fixer PRs without review for more than 3 days (0): none", lines)
        self.assertEqual(lines[-1], "- Could not see: open PRs of acme/widgets")

    def test_the_three_jira_shapes_and_two_pages_merge_by_key(self):
        self.write("widgets.config.json", {"repo": REPO, "jira_project": "WID"})
        self.write("widgets.prs.json", [])
        self.write("WID.jira.1.json", [issue("WID-1", "audit-auto-fixable")])
        self.write("WID.jira.2.json", {"issues": [issue("WID-2", "audit-auto-fixable")]})
        self.write("WID.jira.3.json", {"issues": {"nodes": [
            issue("WID-3", "audit-auto-fixable"),
            {"key": "WID-1", "fields": {"comment": {"comments": [md("2026-11-16")]}}},
        ]}})
        self.write("WID.jira.4.json", "")
        self.write("WID.jira.5.json", {"issues": "unexpected"})
        self.write("WID.jira.6.json", [{"fields": {"summary": "no key"}}])
        unseen = []
        issues = ledger.load_issues(self.dir, "WID", unseen)
        self.assertEqual(sorted(issues), ["WID-1", "WID-2", "WID-3"])
        self.assertEqual(issues["WID-1"]["summary"], "Fix WID-1")
        self.assertEqual(len(issues["WID-1"]["comments"]), 1)
        self.assertEqual(unseen, ["WID.jira.4.json (unreadable)", "WID.jira.5.json (unreadable)",
                                  "1 WID issue(s) without a key"])
        self.assertIn("(3): WID-1 ", self.line("- Waiting"))

    def test_every_page_unreadable_is_could_not_see(self):
        self.setup_repo()
        self.write("WID.jira.1.json", "[")
        self.assertEqual(self.section().splitlines()[2:], ["- Could not see: WID.jira.1.json (unreadable)"])

    def test_text_is_cut_and_loses_slack_syntax(self):
        summary = "Remove <!channel> and <https://evil|click> from\n" + "x" * 100
        self.setup_repo([issue("WID-1", "audit-auto-fixable", summary=summary)])
        text = self.line("- Waiting").split('"')[1]
        self.assertEqual(len(text), 80)
        self.assertTrue(text.startswith("Remove !channel and https://evil|click from xxx"))
        self.assertTrue(text.endswith("…"))
        self.assertNotRegex(text, "[<>\n]")

    def test_dates_with_z_and_jira_offsets(self):
        self.assertEqual(str(ledger.parse_time("2026-11-09T23:30:00.000-0300")), "2026-11-10 02:30:00+00:00")
        self.assertEqual(str(ledger.parse_time("2026-11-09T23:30:00Z")), "2026-11-09 23:30:00+00:00")
        self.assertIsNone(ledger.parse_time("yesterday"))


class TestMain(Folder):
    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = ledger.main(list(argv))
            except SystemExit as exc:
                code = exc.code
        return code, out.getvalue()

    def test_prints_the_section(self):
        self.setup_repo()
        code, out = self.run_main(self.dir, REPO, "--now", "2026-11-27T09:00:00-0300")
        self.assertEqual((code, out), (0, "Audit pending — 2026-11-27 UTC\nWID · acme/widgets\nNothing pending.\n"))

    def test_usage_errors_exit_2(self):
        cases = {
            "no repository": [self.dir],
            "missing folder": [os.path.join(self.dir, "nope"), REPO],
            "not owner/name": [self.dir, "widgets"],
            "shared name": [self.dir, REPO, "other/widgets"],
            "bad --now": [self.dir, REPO, "--now", "tomorrow"],
        }
        for name, argv in cases.items():
            self.assertEqual(self.run_main(*argv), (2, ""), name)


if __name__ == "__main__":
    unittest.main()
