# dora-metrics

Skill + script de **obtención** (no interpretación) de dos métricas DORA por
proyecto y por repo: **Deployment Frequency** y **Lead Time for Changes**.
Todo el dato sale de la API de GitHub — nunca de un clon local de git. El
contrato completo (qué mide, qué NO hace, el rationale de cada decisión) está
en `SKILL.md`; este README es la puerta de entrada para un humano que abre la
carpeta.

Carpeta 100% autocontenida: no depende de nada fuera de `dora-metrics/` salvo
`gh` (GitHub CLI) y Python 3 con `requests`.

## Qué hace y qué no

- Calcula Deployment Frequency (conteo de deploys en una ventana) y Lead Time
  for Changes (mediana, primer commit del PR → deploy), por repo.
- **No interpreta ni rankea.** No clasifica en tiers, no compara proyectos ni
  personas. Eso es un paso posterior y deliberadamente separado — en cuanto una métrica se usa para evaluar personas, deja de ser una buena métrica (Ley de Goodhart).
- Definiciones formales de cada métrica: `references/deployment-frequency.md` y
  `references/lead-time-for-changes.md`.

## Cómo correrlo

### Opción A — pidiéndoselo a la skill (Claude Code)

Cualquier frase natural la dispara: "corré las métricas DORA de Example Project",
"deployment frequency de X", "reporte quincenal de métricas". Ver `SKILL.md`
para el detalle del flujo (tabla de confirmación, auth, reporte).

### Opción B — a mano

```bash
pip install requests --break-system-packages   # si hace falta

export GITHUB_TOKEN=ghp_xxxx    # o simplemente tené `gh auth login` hecho

python3 scripts/dora_metrics.py --proyecto "Example Project" --out-dir outputs
```

Auth: el script busca `GITHUB_TOKEN` en el entorno, y si no está, prueba
`gh auth token` (si tenés la GitHub CLI logueada, no hace falta generar ni
pegar nada). El token necesita acceso de lectura a **todas** las orgs de los
repos del proyecto — un proyecto multi-repo, por ejemplo, puede tener repos en `example-org` y `example-partner-org`.

### Flags

| Flag | Default | Qué hace |
|---|---|---|
| `--config` | `config/proyectos.json` | Path al config a usar. |
| `--proyecto` | todos los del config | Nombre exacto del proyecto a correr. |
| `--out-dir` | no guarda | Si se pasa, además de stdout guarda `YYYY-MM-DD_dora.json` ahí. |
| `--branch <rama>` | — | Override puntual de `prod_branch` para esta corrida (requiere `--proyecto`). No toca el config. |
| `--deploy-source {release,tag}` | — | Override puntual de `deploy_source` (requiere `--proyecto`). No toca el config. |
| `--window-days N` | — | Override puntual de la ventana en días. No toca el config. |

Los overrides (`--branch`, `--deploy-source`, `--window-days`) son para
pruebas puntuales — la corrida real de cada quincena usa lo que dice el
config, sin flags extra.

## Cómo agregar un proyecto nuevo

**La forma recomendada es pedírselo directo a la skill** ("agregá el proyecto
X, tiene estos repos...") — va a preguntar los datos que falten y editar
`config/proyectos.json` por vos, mostrando el resultado antes de guardar.

Si preferís editarlo a mano, para cada proyecto necesitás resolver:

- **¿Mono-repo o multi-repo?** Listar todos los repos de GitHub que lo
  componen.
- **¿Qué rama es "producción"** en cada repo? (no asumas `main` — confirmalo).
- **En multi-repo, ¿los repos deployan acoplados o independientes?** Si un
  deploy del proyecto no implica tag en todos los repos a la vez (caso más
  común), cada repo se cuenta y reporta por separado, nunca
  combinado. Esto ya es el comportamiento default de la skill, no hace falta
  configurar nada extra para esto.
- **¿El repo usa GitHub Releases, o solo tags planos?** Ver "Configuración"
  abajo (`deploy_source`).

## Configuración

Todo vive en `config/proyectos.json`. Dos niveles: global (aplica a todos los
proyectos salvo que un repo lo pise) y por repo.

```json
{
  "tag_pattern": "^v\\d+\\.\\d+\\.\\d+$",
  "window_days": 14,
  "proyectos": [
    {
      "nombre": "Example Project",
      "notas": "Texto libre opcional: lo no obvio de este proyecto puntual.",
      "repos": [
        {
          "repo": "example-org/example-frontend",
          "tipo": ["web", "mobile"],
          "prod_branch": "main",
          "deploy_source": "release",
          "tag_pattern": "^v\\d+\\.\\d+\\.\\d+$"
        }
      ]
    }
  ]
}
```

| Campo | Nivel | Default si se omite | Qué es |
|---|---|---|---|
| `tag_pattern` | global | — (obligatorio) | Regex que debe matchear el tag para contar como deploy. |
| `window_days` | global | — (obligatorio) | Ventana de medición en días. |
| `proyectos[].nombre` | proyecto | — (obligatorio) | Nombre por el que se busca el proyecto (case-insensitive). |
| `proyectos[].notas` | proyecto | ninguna | Texto libre: rationale o aclaraciones específicas de ese proyecto (no metodología general — esa vive acá, en el README). |
| `repos[].repo` | repo | — (obligatorio) | `org/repo` de GitHub. |
| `repos[].tipo` | repo | `[]` | Lista informativa (web/mobile/backend), solo se usa para mostrar en el output. |
| `repos[].prod_branch` | repo | — (obligatorio) | Rama de producción de ese repo. |
| `repos[].deploy_source` | repo | `"release"` | `"release"` = GitHub Release con tag semver. `"tag"` = tag plano sin Release (git tag anotado o liviano), para proyectos que taguean pero no publican Releases. |
| `repos[].tag_pattern` | repo | el `tag_pattern` global | Override si ese repo puntual usa un formato de tag distinto (ej. con build number). |

## Ejemplo de output

Resumen humano (stdout):

```
=== Example Project ===
  [example-org/example-frontend] (web, mobile) [deploy_source: release]
    Deployment Frequency (ventana 14d): 2
    Lead Time mediana: 4.3h  (n=3)
```

JSON portable (si se usa `--out-dir`), un repo dentro de `proyectos[].repos[]`:

```json
{
  "repo": "example-org/example-frontend",
  "prod_branch": "main",
  "deploy_source": "release",
  "deployment_frequency": 2,
  "deploys_in_window": [
    {"tag": "v1.4.0", "published_at": "2026-07-01T18:03:00Z", "url": "..."}
  ],
  "lead_time_median_hours": 4.3,
  "lead_time_n": 3,
  "lead_time_detail": [
    {"pr": 128, "title": "Fix X", "deploy_tag": "v1.4.0",
     "first_commit_ts": "2026-07-01T13:45:00Z",
     "deploy_ts": "2026-07-01T18:03:00Z", "lead_time_hours": 4.3}
  ],
  "warnings": []
}
```

## Testing

Dos niveles, con propósitos distintos:

### Unit tests — lógica del script, sin red

```bash
python3 -m unittest discover -s tests -p "test_*.py" -v
```

Mockean `requests.Session`, corren en segundos. Cubren el cálculo de DF/LT,
la mediana, la exclusión del primer deploy, los warnings, y las validaciones
de config/CLI. Correr esto siempre que se toque `scripts/dora_metrics.py`.

### E2E — contra un repo real de GitHub

```bash
python3 tests/e2e/run_e2e.py --repo tu-usuario/algun-repo-descartable
```

Valida el pipeline completo (crear rama, PR, merge, release/tag, correr el
script, verificar el resultado) contra un repo real. **Requiere un repo
descartable propio** (el `--repo` es un parámetro obligatorio, no tiene default) y `gh` autenticado con permisos sobre ese repo. Resetea el
repo a un estado limpio al arrancar, así es repetible. Tarda ~1 minuto (usa
fechas de commit falseadas para simular lead times realistas sin esperar
minutos reales — solo espera unos segundos donde hace falta evitar una
condición de carrera puntual entre el merge y el tag, documentada en
`scripts/dora_metrics.py`).

No corre en CI ni se dispara solo — es una herramienta para quien mantiene
el script, no parte del uso normal de la skill.

## Limitaciones conocidas

Ver la sección correspondiente en `SKILL.md` y el docstring de
`scripts/dora_metrics.py` (ahí está el detalle técnico de cada una).

## Estructura

```
dora-metrics/
├── README.md              # este archivo
├── SKILL.md                # instrucciones para Claude (fuente de verdad del workflow)
├── config/proyectos.json   # mapeo proyecto -> repos, única fuente de verdad
├── references/              # contrato formal de cada métrica
├── scripts/dora_metrics.py # el script de obtención
├── tests/                   # unit tests + e2e
└── evals/                   # evals de la skill (¿dispara y conversa bien?, no valida el cálculo)
```
