---
name: specai-adr
description: Use when una decisión arquitectónica duradera y transversal requiere conservar su rationale sin duplicar la especificación normativa.
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Architecture Decision Records

**REQUIRED SUB-SKILL:** Use specai:specai-documentation

Un ADR registra por qué se tomó una decisión arquitectónica y qué alternativas se descartaron. No sustituye una spec ni convierte cada feature en una decisión arquitectónica.

## When to Use

Crea un ADR únicamente cuando la decisión sea duradera o transversal: afecta a varias features o módulos, fija una restricción compartida, o sería costosa de revertir. No lo crees por defecto para cada feature, ni para detalles locales, cambios triviales o decisiones ya cubiertas por una convención normativa.

El ADR debe nacer de una decisión explícita durante el diseño y conservar su contexto, alternativas, rationale y consecuencias. Si no existe una decisión duradera y transversal, no se crea ningún ADR.

## Decision Gate

Antes de crear el registro, confirma todas estas condiciones:

- La decisión tiene alcance transversal o un coste relevante de reversión.
- La decisión no está suficientemente explicada por una spec normativa existente.
- El registro aporta rationale y alternativas, no una copia de requisitos.
- La creación o modificación la realiza `specai-documentation`.
- La única vía de escritura es completar `skills/specai-adr/templates/adr.md`; no se redactan ADR ad hoc ni se añaden comandos públicos.

Usa solo los estados `proposed`, `accepted` y `superseded`. Un ADR comienza como `proposed`, pasa a `accepted` cuando la decisión queda adoptada y pasa a `superseded` cuando otro ADR lo reemplaza. No se borra un ADR histórico.

Cada registro conserva estos campos: Feature ID de origen, ruta enlazada de la feature, PRD relacionada, Spec normativa, Diseño relacionado, Reemplaza y Reemplazado por. Las rutas de feature, PRD, spec y diseño se expresan como enlaces Markdown válidos cuando el archivo existe. `docs/specai/project/` es la autoridad normativa; el ADR contiene exclusivamente rationale, alternativas y consecuencias de esa autoridad.

Cuando una feature pasa a `docs/specai/feature/`, revisa el control de enlaces: actualiza o confirma el enlace de la Feature ID de origen y de la PRD, spec y diseño relacionados, comprueba que apuntan a rutas existentes y enlaza la feature con el ADR desde su `-designs.md` o spec. El traslado no convierte el ADR en autoridad normativa.

## Provenance

La procedencia mínima relaciona el ADR con la Feature ID de origen, un enlace a la carpeta de feature y sus artefactos enlazados de PRD, spec y diseño. Mantén también las relaciones de sustitución mediante Reemplaza y Reemplazado por. La plantilla es el único formato admitido y la documentación normativa prevalece siempre sobre cualquier resumen del ADR.
