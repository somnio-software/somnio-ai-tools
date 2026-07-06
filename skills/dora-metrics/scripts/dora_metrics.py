#!/usr/bin/env python3
"""
Skill de obtención — DORA (Deployment Frequency + Lead Time for Changes)

Fuente: API de GitHub (REST + Search), NO git local — el lead time depende
del primer commit real de cada PR, algo que solo la API de GitHub garantiza
de forma confiable independientemente de la estrategia de merge (incluido
squash).

Contrato: SOLO obtiene y agrega. No interpreta ni rankea — eso es un paso
posterior, fuera del alcance de esta skill.

Uso:
    export GITHUB_TOKEN=ghp_xxx   # o token con scope 'repo' (read) para los repos del org
    python3 dora_metrics.py [--config config/proyectos.json] [--proyecto "Example Project"] [--out-dir outputs]
        [--branch rama] [--deploy-source release|tag] [--window-days N]

Marcador de deploy configurable por repo (campo "deploy_source" en el config,
default "release"): "release" usa GitHub Releases (tag_name matchea
tag_pattern); "tag" usa git tags planos (sin pasar por Releases) resolviendo
la fecha vía el commit al que apuntan, para proyectos que taguean pero no
publican Releases.

Limitación conocida (deploy_source=tag o release con tag liviano apuntando
al merge commit): el timestamp de ese commit puede diferir en 1-2 segundos
del `merged_at` que GitHub termina de persistir en el PR. Verificado
empíricamente en pruebas E2E (ver tests/e2e/) que esto puede fallar en ambas
direcciones:
- Excluir un PR que en realidad sí se mergeó dentro de la ventana (el PR
  queda justo afuera del límite superior).
- Atribuir un PR al intervalo de deploy SIGUIENTE en vez del que realmente
  lo incluyó (si el PR se mergeó 1-2 segundos después del deploy anterior).
Con ventanas reales (días/semanas entre deploys) este desfase de segundos
nunca alcanza a importar; solo se reprodujo en pruebas donde el flujo
completo (tag/release → merge → siguiente tag/release) se comprimió en
minutos. No se agrega un margen artificial para este caso — el costo de
acertar el margen "correcto" no se justifica para un escenario que en
producción solo ocurriría con un pipeline de CI que auto-taggea al mergear.

Requiere: requests  (pip install requests --break-system-packages)
"""

import argparse
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
from datetime import datetime, timedelta, timezone

import requests

API_ROOT = "https://api.github.com"


def get_github_token():
    """Orden de precedencia: 1) GITHUB_TOKEN env var, 2) `gh auth token`
    (si la CLI de GitHub está instalada y logueada localmente). Así cualquiera
    del equipo que ya use `gh` a diario puede correr esta skill sin generar ni
    pegar un token nuevo en ningún lado."""
    env_token = os.environ.get("GITHUB_TOKEN")
    if env_token:
        return env_token
    if shutil.which("gh"):
        try:
            out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=10)
            token = out.stdout.strip()
            if out.returncode == 0 and token:
                return token
        except Exception:
            pass
    return None


class GitHubError(Exception):
    pass


def gh_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    return s


def gh_paginate(session: requests.Session, url: str, params: dict = None):
    """GET con paginación via Link header. Yields items de cada página."""
    params = dict(params or {})
    params.setdefault("per_page", 100)
    next_url = url
    next_params = params
    while next_url:
        resp = session.get(next_url, params=next_params)
        if resp.status_code == 401:
            raise GitHubError(
                "401 Unauthorized. Revisá que GITHUB_TOKEN sea válido y tenga "
                "acceso a TODAS las orgs de los repos del proyecto (si es multi-org)."
            )
        if resp.status_code == 403 and "rate limit" in resp.text.lower():
            raise GitHubError(f"Rate limit alcanzado: {resp.text[:300]}")
        if resp.status_code == 404:
            raise GitHubError(f"404 Not Found en {next_url} — ¿el repo existe y el token tiene acceso?")
        if not resp.ok:
            raise GitHubError(f"GitHub API error {resp.status_code} en {next_url}: {resp.text[:300]}")
        data = resp.json()
        items = data.get("items", data) if isinstance(data, dict) else data
        for item in items:
            yield item
        next_url = None
        next_params = None
        if "next" in resp.links:
            next_url = resp.links["next"]["url"]


def parse_ts(s: str) -> datetime:
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def fmt_ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def get_prod_releases(session: requests.Session, repo: str, tag_pattern: str):
    """Releases publicados (no draft) cuyo tag matchea tag_pattern, orden ascendente."""
    pattern = re.compile(tag_pattern)
    releases = []
    for r in gh_paginate(session, f"{API_ROOT}/repos/{repo}/releases"):
        if r.get("draft"):
            continue
        tag = r.get("tag_name", "")
        if not pattern.match(tag):
            continue
        published = r.get("published_at") or r.get("created_at")
        if not published:
            continue
        releases.append({"tag": tag, "published_at": parse_ts(published), "url": r.get("html_url")})
    releases.sort(key=lambda x: x["published_at"])
    return releases


def get_prod_tags(session: requests.Session, repo: str, tag_pattern: str):
    """Tags (sin Release) cuyo nombre matchea tag_pattern, orden ascendente.

    Distingue tag anotado de liviano vía Git Data API: un tag anotado tiene
    su propio objeto con fecha de "tageo" (tagger.date) — la señal más
    cercana a "cuándo se marcó esto como deploy", que puede ser bastante
    posterior a cuando se escribió el código. Usar directamente la fecha del
    commit subyacente (como hacíamos antes) perdía esa distinción. Un tag
    liviano no tiene objeto propio, así que cae a la fecha del commit."""
    pattern = re.compile(tag_pattern)
    tag_names = [t.get("name", "") for t in gh_paginate(session, f"{API_ROOT}/repos/{repo}/tags")]
    tags = []
    for name in tag_names:
        if not pattern.match(name):
            continue
        ref_resp = session.get(f"{API_ROOT}/repos/{repo}/git/ref/tags/{name}")
        if not ref_resp.ok:
            continue
        obj = ref_resp.json().get("object", {})
        obj_sha = obj.get("sha")
        if obj.get("type") == "tag":
            tag_resp = session.get(f"{API_ROOT}/repos/{repo}/git/tags/{obj_sha}")
            if not tag_resp.ok:
                continue
            tag_data = tag_resp.json()
            date_str = (tag_data.get("tagger") or {}).get("date")
            if not date_str:
                continue
            tags.append({"tag": name, "published_at": parse_ts(date_str), "url": tag_data.get("object", {}).get("url")})
        else:
            commit_resp = session.get(f"{API_ROOT}/repos/{repo}/commits/{obj_sha}")
            if not commit_resp.ok:
                continue
            commit_data = commit_resp.json()
            commit_info = commit_data.get("commit", {})
            date_str = (commit_info.get("committer") or {}).get("date") or (commit_info.get("author") or {}).get("date")
            if not date_str:
                continue
            tags.append({"tag": name, "published_at": parse_ts(date_str), "url": commit_data.get("html_url")})
    tags.sort(key=lambda x: x["published_at"])
    return tags


def get_pr_first_commit_ts(session: requests.Session, repo: str, pr_number: int):
    """Timestamp del primer commit del PR (vía objeto PR, no via git log de main —
    esto sigue siendo correcto aunque el merge a main haya sido squash)."""
    commits = list(gh_paginate(session, f"{API_ROOT}/repos/{repo}/pulls/{pr_number}/commits"))
    if not commits:
        return None
    dates = []
    for c in commits:
        commit_info = c.get("commit", {})
        author_date = (commit_info.get("author") or {}).get("date")
        committer_date = (commit_info.get("committer") or {}).get("date")
        d = author_date or committer_date
        if d:
            dates.append(parse_ts(d))
    if not dates:
        return None
    return min(dates)


def get_merged_prs_between(session: requests.Session, repo: str, branch: str, start: datetime, end: datetime):
    """PRs mergeados a `branch` en (start, end], vía Search API (search/issues),
    independiente de la estrategia de merge (squash/merge commit/rebase)."""
    start_s = fmt_ts(start)
    end_s = fmt_ts(end)
    q = f"repo:{repo} is:pr is:merged base:{branch} merged:{start_s}..{end_s}"
    prs = []
    for item in gh_paginate(session, f"{API_ROOT}/search/issues", params={"q": q}):
        prs.append({"number": item["number"], "title": item.get("title", "")})
    return prs


VALID_DEPLOY_SOURCES = ("release", "tag")


def compute_repo_metrics(session: requests.Session, repo: str, branch: str,
                          tag_pattern: str, window_days: int, now: datetime,
                          deploy_source: str = "release"):
    warnings = []
    window_start = now - timedelta(days=window_days)

    if deploy_source == "tag":
        all_deploys = get_prod_tags(session, repo, tag_pattern)
        marker_label = "Tag"
    else:
        all_deploys = get_prod_releases(session, repo, tag_pattern)
        marker_label = "Release"
    deploys_in_window = [d for d in all_deploys if window_start <= d["published_at"] <= now]
    tag_to_idx = {d["tag"]: i for i, d in enumerate(all_deploys)}

    # DF se queda como conteo entero (0 incluido): "0 deploys en la ventana"
    # es un valor real y medible, no un "no aplica" (mismo criterio que usa
    # minister:dora-metrics para su propia deployment_frequency).
    deployment_frequency = len(deploys_in_window)

    lead_times_hours = []
    lt_detail = []
    for dep in deploys_in_window:
        idx = tag_to_idx[dep["tag"]]
        if idx == 0:
            warnings.append(
                f"{marker_label} {dep['tag']} no tiene {marker_label.lower()} anterior conocido — "
                "no se puede acotar la población de PRs, se excluye del Lead Time."
            )
            continue
        prev_dep = all_deploys[idx - 1]
        prs = get_merged_prs_between(session, repo, branch, prev_dep["published_at"], dep["published_at"])
        if not prs:
            warnings.append(f"{marker_label} {dep['tag']}: 0 PRs mergeados encontrados en el rango — revisar base branch/convención.")
            continue
        for pr in prs:
            first_commit_ts = get_pr_first_commit_ts(session, repo, pr["number"])
            if first_commit_ts is None:
                warnings.append(f"PR #{pr['number']}: no se pudo obtener el primer commit, se excluye.")
                continue
            lead_time_h = (dep["published_at"] - first_commit_ts).total_seconds() / 3600
            lead_times_hours.append(lead_time_h)
            lt_detail.append({
                "pr": pr["number"],
                "title": pr["title"],
                "deploy_tag": dep["tag"],
                "first_commit_ts": fmt_ts(first_commit_ts),
                "deploy_ts": fmt_ts(dep["published_at"]),
                "lead_time_hours": round(lead_time_h, 1),
            })

    # None (no 0) cuando no hay lead times computables: "sin deploys medibles
    # en la ventana" no es lo mismo que "lead time de 0 horas" — confundirlos
    # clasificaría una ventana sin señal como si fuera una entrega instantánea.
    lead_time_median_hours = round(statistics.median(lead_times_hours), 1) if lead_times_hours else None

    return {
        "repo": repo,
        "prod_branch": branch,
        "deploy_source": deploy_source,
        "window_start": fmt_ts(window_start),
        "window_end": fmt_ts(now),
        "deployment_frequency": deployment_frequency,
        "deploys_in_window": [{"tag": d["tag"], "published_at": fmt_ts(d["published_at"]), "url": d["url"]} for d in deploys_in_window],
        "lead_time_median_hours": lead_time_median_hours,
        "lead_time_n": len(lead_times_hours),
        "lead_time_detail": lt_detail,
        "warnings": warnings,
    }


def _positive_int(value: str) -> int:
    try:
        ivalue = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"debe ser un entero positivo, recibido {value!r}") from exc
    if ivalue < 1:
        raise argparse.ArgumentTypeError(f"debe ser >= 1, recibido {ivalue}")
    return ivalue


def validate_scoped_overrides(args) -> None:
    """--branch y --deploy-source son overrides puntuales de UN proyecto;
    no tiene sentido aplicarlos a todos si no se especifica --proyecto.
    Separado de main() para poder testear la validación sin invocar el CLI."""
    if args.branch and not args.proyecto:
        raise ValueError("--branch requiere --proyecto (el override es puntual, no se aplica a todos los proyectos).")
    if args.deploy_source and not args.proyecto:
        raise ValueError("--deploy-source requiere --proyecto (el override es puntual, no se aplica a todos los proyectos).")


def validate_deploy_sources(proyectos) -> None:
    """Valida que deploy_source de cada repo sea uno de los valores soportados.
    Separado de main() para poder testear la validación sin tocar el config real."""
    for proyecto in proyectos:
        for repo_cfg in proyecto["repos"]:
            ds = repo_cfg.get("deploy_source", "release")
            if ds not in VALID_DEPLOY_SOURCES:
                raise ValueError(
                    f"deploy_source inválido '{ds}' en repo {repo_cfg['repo']} "
                    f"(válidos: {', '.join(VALID_DEPLOY_SOURCES)})."
                )


def main():
    ap = argparse.ArgumentParser(description="Obtención DORA (Deployment Frequency + Lead Time) desde GitHub API.")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "..", "config", "proyectos.json"))
    ap.add_argument("--proyecto", default=None, help="Nombre de proyecto a correr (default: todos los del config).")
    ap.add_argument("--out-dir", default=None, help="Carpeta donde guardar el JSON de output (default: no guarda, solo stdout).")
    ap.add_argument("--branch", default=None, help="Override puntual de prod_branch para esta corrida (requiere --proyecto). No modifica el config.")
    ap.add_argument("--deploy-source", default=None, choices=list(VALID_DEPLOY_SOURCES),
                     help="Override puntual de deploy_source para esta corrida (requiere --proyecto). No modifica el config.")
    ap.add_argument("--window-days", type=_positive_int, default=None,
                     help="Override puntual de window_days para esta corrida. No modifica el config.")
    args = ap.parse_args()

    try:
        validate_scoped_overrides(args)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    token = get_github_token()
    if not token:
        print(
            "ERROR: no encontré credencial de GitHub.\n"
            "  Opción 1: export GITHUB_TOKEN=ghp_xxxx\n"
            "  Opción 2: correr `gh auth login` una vez (si tenés la CLI de GitHub "
            "instalada) — el script la detecta sola, no hace falta exportar nada.",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(args.config, "r") as f:
        config = json.load(f)

    tag_pattern = config["tag_pattern"]
    window_days = args.window_days if args.window_days is not None else config["window_days"]
    proyectos = config["proyectos"]
    if args.proyecto:
        proyectos = [p for p in proyectos if p["nombre"].lower() == args.proyecto.lower()]
        if not proyectos:
            print(f"ERROR: proyecto '{args.proyecto}' no está en {args.config}.", file=sys.stderr)
            sys.exit(1)
        if args.branch:
            for repo_cfg in proyectos[0]["repos"]:
                repo_cfg["prod_branch"] = args.branch
        if args.deploy_source:
            for repo_cfg in proyectos[0]["repos"]:
                repo_cfg["deploy_source"] = args.deploy_source

    try:
        validate_deploy_sources(proyectos)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    session = gh_session(token)
    now = datetime.now(timezone.utc)

    result = {
        "generated_at": fmt_ts(now),
        "window_days": window_days,
        "tag_pattern": tag_pattern,
        "proyectos": [],
    }

    for proyecto in proyectos:
        repos_result = []
        for repo_cfg in proyecto["repos"]:
            try:
                repo_tag_pattern = repo_cfg.get("tag_pattern", tag_pattern)
                deploy_source = repo_cfg.get("deploy_source", "release")
                r = compute_repo_metrics(
                    session, repo_cfg["repo"], repo_cfg["prod_branch"], repo_tag_pattern, window_days, now,
                    deploy_source=deploy_source,
                )
                r["tipo"] = repo_cfg.get("tipo", [])
            except (GitHubError, requests.exceptions.RequestException) as e:
                r = {"repo": repo_cfg["repo"], "error": str(e)}
            repos_result.append(r)
        result["proyectos"].append({"nombre": proyecto["nombre"], "repos": repos_result})

    output_json = json.dumps(result, indent=2, ensure_ascii=False)

    if args.out_dir:
        os.makedirs(args.out_dir, exist_ok=True)
        fname = os.path.join(args.out_dir, f"{now.strftime('%Y-%m-%d')}_dora.json")
        with open(fname, "w") as f:
            f.write(output_json)
        print(f"Output guardado en {fname}\n")

    # Resumen humano — SOLO obtiene y reporta, no interpreta.
    for p in result["proyectos"]:
        print(f"=== {p['nombre']} ===")
        for r in p["repos"]:
            if "error" in r:
                print(f"  [{r['repo']}] ERROR: {r['error']}")
                continue
            print(f"  [{r['repo']}] ({', '.join(r.get('tipo', []))}) [deploy_source: {r.get('deploy_source', 'release')}]")
            print(f"    Deployment Frequency (ventana {window_days}d): {r['deployment_frequency']}")
            if r["lead_time_median_hours"] is not None:
                print(f"    Lead Time mediana: {r['lead_time_median_hours']}h  (n={r['lead_time_n']})")
            else:
                print("    Lead Time mediana: sin datos en la ventana")
            for w in r["warnings"]:
                print(f"    ! {w}")
        print()

    print(output_json)


if __name__ == "__main__":
    main()
