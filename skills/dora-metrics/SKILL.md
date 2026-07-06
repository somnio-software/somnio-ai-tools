---
name: dora-metrics
description: >
  Obtiene las métricas DORA Deployment Frequency y Lead Time for Changes, por
  proyecto y por repo, desde GitHub (API, no git local). Usar esta skill
  siempre que el usuario pida correr o actualizar las métricas DORA, medir
  deployment frequency o lead time de un proyecto (ej. "Example Project"), generar
  el reporte quincenal de métricas, o pregunte cuántos deploys hizo un
  proyecto o cuánto tarda un cambio en llegar a producción.
  Disparar también con frases como: "corré las métricas DORA", "métricas de
  Example Project", "deployment frequency de [proyecto]", "lead time de
  [proyecto]", "reporte quincenal de métricas", "cuántos deploys hicimos este
  sprint".
allowed-tools: Read, Write, Edit, Bash
---

# DORA Metrics — Deployment Frequency & Lead Time for Changes

> Esta skill **solo obtiene y agrega el dato** — no interpreta, no rankea, no
> compara personas ni proyectos entre sí. Eso es un paso posterior y separado,
> fuera del alcance de esta skill.

## Contexto

Se miden dos métricas DORA por proyecto: **Deployment Frequency** (con qué
frecuencia se deploya a prod) y **Lead Time for Changes** (cuánto tarda un
cambio en llegar a prod). Es la etapa de **calibración**: el objetivo es que
el equipo tenga un dato consistente y ejecutable por sí mismo — no que se use
para evaluar personas. La obtención del dato y su interpretación son pasos
deliberadamente separados: en cuanto una métrica se usa para evaluar personas,
deja de ser una buena métrica (Ley de Goodhart).

CI es uniforme (GitHub Actions) pero CD es heterogéneo (mobile/web/backend
deployan distinto), así que en vez de medir el CD real se usa un marcador
uniforme: un **GitHub Release con tag semver `vX.Y.Z`** sobre la rama de
producción de cada repo. Todo el dato sale de la **API de GitHub** — nunca de
un clon local de git — porque el lead time depende del primer commit real de
cada PR, y eso solo es confiable leyendo el objeto PR de GitHub (sigue siendo
correcto incluso si el merge fue squash; el git log de `main` no lo garantiza).

Los proyectos pueden ser mono-repo o multi-repo. En multi-repo, cada repo se
mide y reporta **independiente, sin combinar**: si un proyecto deploya
frontend y backend en momentos distintos, mezclarlos en un solo número
ocultaría justamente la señal que la calibración busca exponer.

Definiciones formales de cada métrica (atributo, población, cálculo exacto):
`references/deployment-frequency.md` y `references/lead-time-for-changes.md`.

## Input

- **Nombre del proyecto** (ej. "Example Project"). Si el usuario no especifica uno,
  correr todos los proyectos de `config/proyectos.json`.
- Ventana de medición: fija en 14 días por default (config `window_days`) — no
  pedirla salvo que el usuario explícitamente quiera otra cosa.

## Output

- Resumen humano por consola, por proyecto y por repo: deployment frequency,
  lead time mediana, y warnings de casos borde.
- Opcionalmente, un JSON portable en la carpeta indicada con `--out-dir` (ej.
  `outputs/YYYY-MM-DD_dora.json`), si se pide guardar el resultado.

---

## Workflow

### Paso 1 — Identificar el/los proyecto(s)

Leer `config/proyectos.json`. Buscar el proyecto pedido por nombre
(case-insensitive).

**Si el proyecto no está en el config**: no inventar repos ni asumir un
mapeo. En vez de frenar y mandar al usuario a editar un archivo aparte,
preguntarle directamente los datos que faltan y agregarlos vos mismo a
`config/proyectos.json`:

- Nombre del proyecto.
- Repo(s) de GitHub que lo componen (`org/repo`), uno o varios (multi-repo).
- Tipo de cada repo (web / mobile / backend).
- Rama de producción de cada repo (default razonable: `main`, pero
  confirmar — no asumir).
- Opcional: si algún repo no usa GitHub Releases sino tags planos
  (`deploy_source: "tag"`), o un `tag_pattern` distinto al global. Default:
  hereda `deploy_source: "release"` y el `tag_pattern` global si no se
  especifica nada.
- Opcional: alguna nota corta si hay algo no obvio del proyecto (ej. multi-repo
  con orgs distintas, deploys desacoplados entre repos) — va en un campo
  `"notas"` del proyecto. No hace falta si no hay nada particular que aclarar.

Mostrar el JSON resultante antes de guardarlo y pedir confirmación (es un
archivo compartido por todo el equipo). Una vez guardado, seguir con el
Paso 2 normalmente.

### Paso 2 — Mostrar tabla de confirmación

Antes de llamar a la API, mostrar una tabla con lo que se va a medir. A
diferencia de una skill que genera un documento (donde la tabla es un gate
obligatorio antes de crear algo difícil de deshacer), acá es informativa: la
skill solo lee datos y arma un reporte, así que se puede seguir de largo salvo
que algo llame la atención (un repo que no correspondería, una rama rara).
Mostrarla siempre igual, para que quien la corra vea de un vistazo qué se está
midiendo:

| Proyecto | Repo | Tipo | Rama prod | Ventana |
|---|---|---|---|---|
| Example Project | `example-org/example-frontend` | web, mobile | main | últimos 14 días |
| Example Project | `example-partner-org/example-backend` | backend | main | últimos 14 días |

Si algo en la tabla no coincide con lo que el usuario esperaba, parar y
preguntar antes de correr el script.

### Paso 3 — Verificar autenticación

El script (`scripts/dora_metrics.py`) necesita una credencial de GitHub con
acceso de lectura a **todas** las orgs de los repos del proyecto (ej. si es
multi-org: `example-org` y `example-partner-org`). Orden de precedencia,
automático:

1. Variable de entorno `GITHUB_TOKEN`.
2. `gh auth token` — si la CLI de GitHub ya está logueada localmente, no hace
   falta pedir ni pegar nada.

Si ninguna de las dos está disponible, el script lo va a decir explícitamente
al correr (no falla en silencio). En ese caso, explicarle al usuario las dos
opciones — no le pidas que pegue un token en el chat si el flujo es Cowork; en
Claude Code local, sugerí `gh auth login` si no lo tiene hecho.

### Paso 4 — Correr el script

```bash
pip install requests --break-system-packages   # si hace falta

python3 scripts/dora_metrics.py --proyecto "Example Project" --out-dir outputs
```

Flags disponibles:
- `--config`: path al config (default: `config/proyectos.json`).
- `--proyecto`: nombre exacto del proyecto (default: corre todos los del config).
- `--out-dir`: si se pasa, además de imprimir por stdout guarda
  `YYYY-MM-DD_dora.json` ahí.
- `--branch <rama>`: override puntual de `prod_branch` para esta corrida
  (requiere `--proyecto`). No modifica el config — usar solo para pruebas
  puntuales contra una rama distinta a la configurada.
- `--deploy-source {release,tag}`: override puntual de `deploy_source`
  (requiere `--proyecto`). No modifica el config.
- `--window-days N`: override puntual de la ventana en días. No modifica
  el config.

Ver `README.md` (sección "Configuración") para el detalle de qué hace cada
campo del config y cuándo usar cada override.

### Paso 5 — Reportar

**Siempre responder en el chat con los dos valores directos** (Deployment
Frequency y Lead Time mediana) por cada repo, aunque también se guarde el
JSON — nunca reemplazar la respuesta por un simple "guardé el archivo,
revisalo ahí". Mostrar el resumen humano tal cual lo imprime el script — no
reinterpretar ni rankear los números, eso es un paso posterior, fuera del
alcance de esta skill. Si
hubo `warnings` en el output (release sin release anterior, PR sin commits
recuperables, 0 PRs en el rango), mostrarlos también: son señal de gaps de
proceso, justo lo que esta etapa de calibración busca exponer, no ruido a
esconder.

Si se guardó el JSON, decir dónde quedó, además de reportar los valores.

---

## Mantenimiento del config

`config/proyectos.json` es la **única fuente de verdad** del mapeo proyecto →
repos — no hay un doc aparte que mantener sincronizado. Se agregan proyectos
nuevos vía el Paso 1 de este workflow (conversación con el usuario), o
editando el JSON directamente. La skill no infiere el mapeo por sí sola: si
falta, pregunta.

## Limitaciones conocidas (piloto)

- Primer Release histórico de un repo: se excluye del cálculo de Lead Time (no
  hay forma de acotar la población de PRs anterior a él).
- Usa la Search API de GitHub (rate limits más bajos que la REST normal); con
  1-2 proyectos no debería ser problema, pero al escalar a más proyectos
  puede requerir batching/caching.
- Lead time va a salir alto en las primeras corridas — esperable en
  calibración, no leer como performance hasta 3-4 ventanas limpias.
- `deploy_source: "tag"`: si el tag/release se crea a 1-2 segundos del merge
  (ej. un pipeline que auto-taggea), un PR puede quedar excluido o mal
  atribuido al intervalo siguiente. Ver detalle en el docstring de
  `scripts/dora_metrics.py`. Irrelevante con cadencias reales (días/semanas).

## Notas importantes

- Esta skill **solo obtiene y reporta**. Nunca interpreta, rankea, ni compara
  personas — mezclar obtención con evaluación contamina el dato (Ley de Goodhart).
- Multi-repo: cada repo se mide y reporta independiente, nunca combinado.
- Fuente única: API de GitHub. Nunca leer del `.git` local del repo clonado.
- Si el proyecto pedido no está en `config/proyectos.json`, no lo inventes —
  preguntar los datos y agregarlo (Paso 1), nunca asumir repos o ramas.
