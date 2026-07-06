# Spec — Deployment Frequency

> Estado: **cerrado** (ejemplo ilustrativo: Example Project).
> Contrato de medición para la skill de obtención.

## Atributo
Con qué frecuencia un proyecto deploya a producción.

## Marcador de deploy a prod (Paso 2)
**GitHub Release sobre tag con formato semver `vX.Y.Z`**, creado en la rama de
producción de cada repo (`main`). El timestamp del Release = momento del deploy.
Convención única entre los tres tipos de proyecto (mobile/web/backend).

## Definición operativa
Cantidad de **tags de prod** (`vX.Y.Z` sobre `main`) por proyecto, dentro de una
ventana de 14 días.

## Fuente
GitHub — tags / Releases de los repos del proyecto (ver `../config/proyectos.json`).

## Nivel de agregación
Por proyecto. **En multi-repo, conteo independiente por repo** (no se requiere
tag simultáneo en todos los repos del proyecto): cada repo deploya de forma
desacoplada, y la métrica del proyecto es la suma/serie de tags de prod de
*cualquiera* de sus repos. Decisión validada con un caso real multi-repo (ej. Example Project: frontend y backend
deployan en momentos distintos) — aplica como convención general salvo que un
proyecto puntual justifique otra cosa.

## Ventana
14 días (cadencia quincenal).

## Cálculo
`deployment_frequency = count(tags_prod en la ventana)` por proyecto (sumando
tags de todos los repos del proyecto).

## Reporte
**Conteo absoluto por ventana de 14 días** (no normalizado). Como la ventana es
fija, un conteo absoluto y una tasa semanal son equivalentes (dividir por 2 es
un paso de interpretación, no de obtención) — se deja el número crudo y que la
lectura de tendencia sea un paso posterior, fuera de esta skill.
*(Propuesta por default; avisame si preferís que la skill ya entregue
deploys/semana.)*

## Ejemplo resuelto — Example Project
- Repos: `example-org/example-frontend`, `example-partner-org/example-backend`.
- Rama prod: `main` en ambos.
- Conteo: independiente por repo.
