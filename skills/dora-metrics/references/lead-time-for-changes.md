# Spec — Lead Time for Changes

> Estado: **cerrado** (ejemplo ilustrativo: Example Project).
> Contrato de medición para la skill de obtención.

## Atributo
Cuánto tarda un cambio desde que se commitea hasta que llega a producción.

## Definición operativa
**Mediana** de (timestamp del tag de prod − timestamp del **primer commit del
PR**), por PR incluido en ese deploy, agregada **por proyecto y por repo**,
dentro de una ventana de 14 días.

- **Punto de partida: primer commit del PR** (no el commit de merge). Mide el
  ciclo completo — desarrollo + espera de merge + espera de deploy —, no solo
  el tramo post-merge. Consecuencia esperada: número más alto, especialmente en
  las primeras ventanas (ver Riesgo conocido).

## Fuente
GitHub — commits, PRs y tags / Releases de los repos del proyecto
(ver `../config/proyectos.json`).

## Nivel de agregación
**Por proyecto y por repo** (no combinado). Consistente con la decisión de
Deployment Frequency: en multi-repo con deploys desacoplados (ej. Example Project:
frontend y backend), se reporta una mediana **por repo**, no una única mediana
mezclando ambos — evita que el ciclo de un repo distorsione la lectura del otro.

## Ventana
14 días (cadencia quincenal).

## Población
PRs mergeados a `main` desde el tag de prod anterior **de ese mismo repo**
(los cambios que entraron en ese deploy).

**PRs sin tag posterior** (mergeados pero sin deploy aún dentro de la ventana):
se **excluyen** del cálculo de esta ventana. Entran en el cálculo de la ventana
donde efectivamente se taggee el deploy que los incluye. No se usa "ahora" como
proxy de fin.

## Cálculo
Por cada PR incluido: `lead_time = tag_prod_ts − primer_commit_ts`.
Métrica por repo: **mediana** de esos lead times (robusta a outliers, no
promedio). El proyecto reporta una mediana por cada repo que lo compone.

## Ejemplo resuelto — Example Project
- Repos: `example-org/example-frontend`, `example-partner-org/example-backend`.
- Se reportan **2 medianas** (una por repo), no una combinada.
- PRs sin tag posterior: excluidos hasta que exista el tag que los incluya.

## Riesgo conocido
Lead time inflado en las primeras ventanas (deploys que agrupan cambios viejos).
No leer como performance hasta 3-4 ventanas limpias.
