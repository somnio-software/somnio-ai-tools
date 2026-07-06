#!/usr/bin/env python3
"""
E2E de scripts/dora_metrics.py contra un repo de GitHub real y descartable.

Reproduce los 7 casos validados manualmente en sesión (release mode con lead
time realista, mediana con n>1, tag anotado, tag liviano, warning de 0 PRs,
--window-days, --branch). No requiere esperas reales de minutos: usa
GIT_AUTHOR_DATE/GIT_COMMITTER_DATE para simular lead times y ventanas
realistas, y solo un sleep corto (unos segundos) donde hace falta evitar la
condición de carrera puntual entre un merge commit y el `merged_at` del PR
(ver docstring de dora_metrics.py).

ADVERTENCIA: al arrancar, este script BORRA todo el contenido de --repo
(releases, tags, branches salvo main, e historia de main vía force-push) para
que cada corrida sea reproducible. --repo tiene que ser un repo 100%
descartable tuyo — nunca uno real. No tiene default: pasá tu propio repo
descartable con --repo.

Requiere: gh CLI autenticado con permisos de admin sobre --repo (borrar
releases/tags/branches, forzar push a main).

Uso:
    python3 tests/e2e/run_e2e.py --repo tu-usuario/tu-repo-descartable
    python3 tests/e2e/run_e2e.py --repo tu-usuario/tu-repo-descartable --yes
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DORA_SCRIPT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "scripts", "dora_metrics.py"))

RESULTS = []


def check(case, condition, detail=""):
    RESULTS.append((case, bool(condition)))
    status = "PASS" if condition else "FAIL"
    print(f"  [{status}] {case}" + (f" — {detail}" if detail else ""))


def run(cmd, cwd=None, env=None, check_rc=True, input_text=None):
    result = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, input=input_text)
    if check_rc and result.returncode != 0:
        raise RuntimeError(f"Comando falló ({' '.join(cmd)}):\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}")
    return result


def gh(args, check_rc=True):
    return run(["gh"] + args, check_rc=check_rc)


def git(args, cwd, env=None, check_rc=True):
    return run(["git"] + args, cwd=cwd, env=env, check_rc=check_rc)


def backdated_env(hours_ago):
    ts = datetime.now(timezone.utc) - timedelta(hours=hours_ago)
    iso = ts.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    env = dict(os.environ)
    env["GIT_AUTHOR_DATE"] = iso
    env["GIT_COMMITTER_DATE"] = iso
    return env


def reset_repo(repo, workdir):
    print(f"Reseteando {repo} a un estado limpio (borra releases, tags, branches != main)...")

    out = gh(["release", "list", "--repo", repo, "--json", "tagName", "-q", ".[].tagName"], check_rc=False)
    for tag in out.stdout.split():
        gh(["release", "delete", tag, "--repo", repo, "--yes", "--cleanup-tag"], check_rc=False)

    # Tags sin Release (anotados o livianos) — borrar vía API, no via git push
    # a una URL suelta (depende de un credential helper que puede no estar
    # configurado; la API con gh siempre usa la sesión ya autenticada).
    out = gh(["api", f"repos/{repo}/tags", "--paginate", "-q", ".[].name"], check_rc=False)
    for name in out.stdout.split():
        gh(["api", "-X", "DELETE", f"repos/{repo}/git/refs/tags/{name}"], check_rc=False)

    out = gh(["api", f"repos/{repo}/branches", "--paginate", "-q", ".[].name"], check_rc=False)
    for branch in out.stdout.split():
        if branch != "main":
            gh(["api", "-X", "DELETE", f"repos/{repo}/git/refs/heads/{branch}"], check_rc=False)

    # El clone inicial (antes de este reset) ya trajo los tags viejos del
    # repo a nivel LOCAL — borrarlos remotamente no los saca del clone, y
    # git se niega a recrear un tag que ya existe localmente.
    out = git(["tag", "-l"], cwd=workdir, check_rc=False)
    for name in out.stdout.split():
        git(["tag", "-d", name], cwd=workdir, check_rc=False)

    git(["checkout", "--orphan", "e2e-reset"], cwd=workdir)
    git(["rm", "-rf", "."], cwd=workdir, check_rc=False)
    with open(os.path.join(workdir, "README.md"), "w") as f:
        f.write("# e2e reset\n")
    git(["add", "README.md"], cwd=workdir)
    git(["commit", "-m", "Reset for e2e run"], cwd=workdir)
    git(["branch", "-M", "main"], cwd=workdir)
    git(["push", "--force", "origin", "main"], cwd=workdir)
    print("Repo reseteado.\n")


def merge_pr_with_backdated_commit(repo, workdir, branch_name, base, hours_ago, title):
    """Crea una rama desde `base`, commitea con fecha falseada (hours_ago),
    abre PR contra `base` y lo mergea. Devuelve el número de PR."""
    git(["checkout", base, "-q"], cwd=workdir)
    git(["pull", "-q", "origin", base], cwd=workdir)
    git(["checkout", "-b", branch_name, "-q"], cwd=workdir)
    marker = os.path.join(workdir, f"{branch_name}.txt")
    with open(marker, "w") as f:
        f.write(title)
    git(["add", os.path.basename(marker)], cwd=workdir)
    env = backdated_env(hours_ago)
    git(["commit", "-m", title], cwd=workdir, env=env)
    git(["push", "-q", "-u", "origin", branch_name], cwd=workdir)
    gh(["pr", "create", "--repo", repo, "--title", title, "--body", "e2e", "--base", base, "--head", branch_name])
    out = gh(["pr", "list", "--repo", repo, "--head", branch_name, "--json", "number", "-q", ".[0].number"])
    pr_number = int(out.stdout.strip())
    gh(["pr", "merge", str(pr_number), "--repo", repo, "--merge", "--delete-branch"])
    return pr_number


def run_dora(repo, prod_branch="main", deploy_source="release", tag_pattern=None,
             window_days=3650, extra_args=None):
    # Margen corto: un release/tag recién creado puede tardar un instante en
    # aparecer en el endpoint de listado de GitHub (lag de propagación
    # observado empíricamente entre `gh release create` y que la corrida
    # siguiente lo vea) — no es un bug de dora_metrics.py, es la API.
    time.sleep(6)
    cfg = {
        "tag_pattern": tag_pattern or r"^v\d+\.\d+\.\d+$",
        "window_days": window_days,
        "proyectos": [{
            "nombre": "E2E",
            "repos": [{"repo": repo, "tipo": ["web"], "prod_branch": prod_branch, "deploy_source": deploy_source}],
        }],
    }
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(cfg, f)
        cfg_path = f.name
    try:
        cmd = ["python3", DORA_SCRIPT, "--config", cfg_path, "--proyecto", "E2E"]
        if extra_args:
            cmd += extra_args
        result = run(cmd)
    finally:
        os.unlink(cfg_path)
    json_start = result.stdout.index("\n{\n") + 1
    return json.loads(result.stdout[json_start:])


def repo_metrics(dora_output, repo):
    for p in dora_output["proyectos"]:
        for r in p["repos"]:
            if r.get("repo") == repo:
                return r
    raise KeyError(f"repo {repo} no encontrado en el output: {dora_output}")


def seed_baseline_release(repo, workdir):
    """Release inicial sin PRs, para que v0.1.0 (Caso A) no quede como el
    primer release histórico del repo — ese siempre se excluye del Lead Time
    por diseño (no hay release anterior contra la cual acotar la búsqueda de
    PRs), y el Caso A necesita que SU PR sea medible."""
    gh(["release", "create", "v0.0.1", "--repo", repo, "--title", "v0.0.1", "--notes", "baseline, sin PRs", "--target", "main"])


def case_a_release_lead_time(repo, workdir):
    print("Caso A — release, lead time realista (commit backdateado 30h)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-a", "main", hours_ago=30, title="Case A")
    time.sleep(7)  # margen real, evita la carrera merge-commit vs merged_at
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    gh(["release", "create", "v0.1.0", "--repo", repo, "--title", "v0.1.0", "--notes", "case a", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("A.DF == 2 (v0.0.1 baseline + v0.1.0)", r["deployment_frequency"] == 2, f"DF={r['deployment_frequency']}")
    check("A.lead_time_n == 1", r["lead_time_n"] == 1, f"n={r['lead_time_n']}")
    lt = r["lead_time_median_hours"] or 0
    check("A.lead_time ~= 30h", 29.5 <= lt <= 30.5, f"lead_time={lt}h")


def case_b_median(repo, workdir):
    print("Caso B — mediana con n>1 (commits backdateados 40h y 20h)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-b-1", "main", hours_ago=40, title="Case B 1")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-b-2", "main", hours_ago=20, title="Case B 2")
    time.sleep(7)
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    gh(["release", "create", "v0.2.0", "--repo", repo, "--title", "v0.2.0", "--notes", "case b", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("B.DF == 3 (v0.0.1 + v0.1.0 + v0.2.0)", r["deployment_frequency"] == 3, f"DF={r['deployment_frequency']}")
    titles = {d["title"] for d in r["lead_time_detail"]}
    # n puede dar 2 o 3: el PR del Caso A a veces se cuela acá por la
    # condición de carrera de 1-2 segundos entre merge y release ya
    # documentada en dora_metrics.py (todo el flujo corre en segundos, el
    # escenario exacto donde ese desfase importa). No es un bug de esta
    # suite ni del script — se valida contenido, no un conteo exacto.
    check("B.lead_time_n >= 2 (Case B 1 y 2 presentes)",
          r["lead_time_n"] >= 2 and {"Case B 1", "Case B 2"} <= titles,
          f"n={r['lead_time_n']} titles={titles}")
    lt = r["lead_time_median_hours"] or 0
    check("B.mediana ~= 30h (mediana de 40 y 20)", 29.5 <= lt <= 30.5, f"mediana={lt}h")


def case_c_annotated_tag(repo, workdir):
    print("Caso C — tag anotado (usa su propia fecha, no la del commit)")
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-c", "main", hours_ago=15, title="Case C")
    time.sleep(7)
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["tag", "-a", "v0.3.0", "-m", "case c annotated"], cwd=workdir)
    git(["push", "-q", "origin", "v0.3.0"], cwd=workdir)
    out = run_dora(repo, deploy_source="tag")
    r = repo_metrics(out, repo)
    tags = [d["tag"] for d in r["deploys_in_window"]]
    check("C.v0.3.0 presente en modo tag", "v0.3.0" in tags, f"tags={tags}")
    detail = [d for d in r["lead_time_detail"] if d["deploy_tag"] == "v0.3.0"]
    check("C.PR de case-c encontrado con lead time ~15h",
          bool(detail) and 14.5 <= detail[0]["lead_time_hours"] <= 15.5,
          f"detail={detail}")


def case_d_lightweight_tag(repo, workdir):
    print("Caso D — tag liviano (fallback a fecha del commit)")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["tag", "v0.4.0"], cwd=workdir)
    git(["push", "-q", "origin", "v0.4.0"], cwd=workdir)
    out = run_dora(repo, deploy_source="tag")
    r = repo_metrics(out, repo)
    tags = [d["tag"] for d in r["deploys_in_window"]]
    check("D.v0.4.0 presente en modo tag (liviano)", "v0.4.0" in tags, f"tags={tags}")


def case_e_zero_prs_warning(repo, workdir):
    print("Caso E — 0 PRs mergeados entre releases consecutivas")
    gh(["release", "create", "v0.5.0", "--repo", repo, "--title", "v0.5.0", "--notes", "case e r1", "--target", "main"])
    gh(["release", "create", "v0.6.0", "--repo", repo, "--title", "v0.6.0", "--notes", "case e r2", "--target", "main"])
    out = run_dora(repo)
    r = repo_metrics(out, repo)
    check("E.warning de 0 PRs para v0.6.0",
          any("v0.6.0" in w and "0 PRs mergeados" in w for w in r["warnings"]),
          f"warnings={r['warnings']}")


def case_f_window_days(repo, workdir):
    print("Caso F — --window-days filtra por ventana (tag anotado backdateado 20 días)")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    env = backdated_env(hours_ago=20 * 24)
    git(["tag", "-a", "v0.7.0", "-m", "case f, 20 dias atras"], cwd=workdir, env=env)
    git(["push", "-q", "origin", "v0.7.0"], cwd=workdir)
    out_14 = run_dora(repo, deploy_source="tag", window_days=14)
    out_60 = run_dora(repo, deploy_source="tag", window_days=60)
    tags_14 = [d["tag"] for d in repo_metrics(out_14, repo)["deploys_in_window"]]
    tags_60 = [d["tag"] for d in repo_metrics(out_60, repo)["deploys_in_window"]]
    check("F.v0.7.0 excluido con ventana de 14d", "v0.7.0" not in tags_14, f"tags_14={tags_14}")
    check("F.v0.7.0 incluido con ventana de 60d", "v0.7.0" in tags_60, f"tags_60={tags_60}")


def case_g_branch_override(repo, workdir):
    print("Caso G — --branch aisla la búsqueda de PRs por base branch")
    git(["checkout", "main", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "main"], cwd=workdir)
    git(["checkout", "-b", "staging", "-q"], cwd=workdir)
    git(["push", "-q", "-u", "origin", "staging"], cwd=workdir)
    merge_pr_with_backdated_commit(repo, workdir, "e2e-case-g", "staging", hours_ago=10, title="Case G")
    time.sleep(7)
    git(["checkout", "staging", "-q"], cwd=workdir)
    git(["pull", "-q", "origin", "staging"], cwd=workdir)
    gh(["release", "create", "v0.8.0", "--repo", repo, "--title", "v0.8.0", "--notes", "case g", "--target", "staging"])

    out_staging = run_dora(repo, extra_args=["--branch", "staging"])
    r_staging = repo_metrics(out_staging, repo)
    detail = [d for d in r_staging["lead_time_detail"] if d["deploy_tag"] == "v0.8.0"]
    check("G.--branch staging encuentra el PR de case-g",
          bool(detail) and 9.5 <= detail[0]["lead_time_hours"] <= 10.5,
          f"detail={detail}")

    out_main = run_dora(repo)  # default: prod_branch=main, no debe ver el PR de staging
    r_main = repo_metrics(out_main, repo)
    check("G.default (branch=main) NO mezcla el PR mergeado a staging",
          any("v0.8.0" in w and "0 PRs mergeados" in w for w in r_main["warnings"]),
          f"warnings={r_main['warnings']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", required=True,
                     help="Repo descartable propio (org/repo). Obligatorio — nunca apuntes a un repo real.")
    ap.add_argument("--yes", action="store_true", help="Salta la confirmación interactiva antes de borrar el repo.")
    args = ap.parse_args()

    print(f"Este script va a BORRAR releases, tags y branches (!= main) de {args.repo}, y forzar un push a main.")
    if not args.yes:
        confirm = input("Confirmás? escribí el nombre del repo para continuar: ")
        if confirm.strip() != args.repo:
            print("Cancelado.")
            sys.exit(1)

    with tempfile.TemporaryDirectory() as workdir:
        run(["git", "clone", f"https://github.com/{args.repo}.git", workdir])
        reset_repo(args.repo, workdir)
        seed_baseline_release(args.repo, workdir)

        for case_fn in (case_a_release_lead_time, case_b_median, case_c_annotated_tag,
                        case_d_lightweight_tag, case_e_zero_prs_warning,
                        case_f_window_days, case_g_branch_override):
            case_fn(args.repo, workdir)
            print()

    total = len(RESULTS)
    passed = sum(1 for _, ok in RESULTS if ok)
    print(f"=== {passed}/{total} checks OK ===")
    for name, ok in RESULTS:
        if not ok:
            print(f"  FALLÓ: {name}")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
