# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (14 febrero 2026) - Thumbnails, deseleccion DataMatrix, compliance_role, GS1 HRI

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Fix: DataMatrix deseleccion al mover (creation scale tracking) | Completado |
| 2 | Campo `compliance_role` en Element schema + validadores + editor | Completado |
| 3 | Thumbnail real del canvas en historial de versiones | Completado |
| 4 | Eliminar info de cambios duplicada en panel de versiones | Completado |
| 5 | GS1 parser: soporte formato HRI con parentesis | Completado |
| 6 | FMD DataMatrix placeholder con GS1 valido | Completado |
| 7 | Fix: export/import missing 11 fields en designs.ex | Completado |
| 8 | Templates con compliance_role en todos los elementos regulatorios | Completado |
| 9 | Fix: toolbar "ELEMENTOS" overflow (w-20 → w-24) | Completado |
| 10 | Tests compliance_role (4 unit + 2 LiveView) | Completado |

---

### Cambios por Area

#### Fix DataMatrix deseleccion al mover

**Problema:** Al mover un DataMatrix en el canvas, se deseleccionaba al soltar. No ocurria con QR.

**Causa raiz:** bwip-js genera imagenes a dimensiones nativas → `scaleX/Y != 1` siempre. El codigo en `saveElementsImmediate` activaba `_pendingRecreate` en CADA guardado (incluso moves), destruyendo y recreando el objeto, lo que disparaba `selection:cleared`.

**Solucion (canvas_designer.js):**
- `createBarcode`: almacena `_creationScaleX/Y` en la imagen
- `saveElementsImmediate`: compara scale contra `_creationScaleX/Y` (no contra 1) para detectar resize real
- `recreateGroupWithoutSave`: flag `_isRecreatingElement` + `wasActive` tracking para restaurar seleccion
- `applyZIndexOrdering` / `updateDepthOverlays`: flag `_isSavingElements` para suprimir `selection:cleared`

#### Thumbnail real en historial de versiones

**Problema:** El preview de version usaba SVG simplificado server-side (patrones simulados, texto truncado).

**Solucion:**
- **Migracion** `20260214150000`: columna `thumbnail :text` en `design_versions`
- **Schema** (`design_version.ex`): campo `thumbnail` añadido
- **Versioning** (`versioning.ex`): nueva funcion `update_version_thumbnail/3`
- **JS** (`canvas_designer.js`): `captureCanvasThumbnail()` exporta solo el area de la etiqueta via `canvas.toDataURL()`, escala a JPEG max 320x220px
- **Editor** (`editor.ex`): tras crear version, push `capture_thumbnail` → JS responde con `canvas_thumbnail` → server almacena
- **Template**: `<img>` con thumbnail almacenado en lugar de `Phoenix.HTML.raw(svg)`
- Eliminado `version_preview_svg` assign y dependencia de `SvgPreview`

#### Info de cambios sin duplicar

- Eliminado `change_message` del recuadro de version en la lista Y del panel de detalle
- La info de cambios queda solo en la seccion "CAMBIOS EN ESTA VERSION" (diff detallado)

#### Campo `compliance_role`

**Element schema (`element.ex`):**
- `field :compliance_role, :string` + cast

**Validadores (EU1169, FMD, GS1):**
- Deteccion primero por `compliance_role`, fallback a regex
- `fix_action` maps incluyen `compliance_role` para auto-asignar

**Editor (`editor.ex`):**
- Dropdown "Rol normativo" condicional a normativa activa
- Checkmark en roles ya asignados a otros elementos

**Templates (`templates.exs`):**
- 10 plantillas con roles auto-asignados

#### GS1 Checksum — formato HRI

**`gs1/checksum.ex`:**
- `parse_gs1_128/1` soporta formato HRI: `(01)value(17)value...`
- `looks_like_gs1?/1` detecta formato HRI
- FMD DataMatrix placeholder actualizado con GS1 valido

#### Export/Import fix

**`designs.ex`:**
- 11 campos faltantes en `export_element/1` e `import_element/1`

### Commits de Esta Sesion

```
58a201f Fix DataMatrix deselection on move and add compliance_role field
c95eccd Replace SVG preview with canvas thumbnail in version history
2854d8c Support GS1 HRI format with parentheses and complete element serialization
```

---

## Arquitectura Clave

### Flujo de Versiones (refactorizado)

```
Autosave (cada cambio)         Guardar (boton explicito)
       │                              │
  update_design()               update_design()
  sin crear version             + create_snapshot()
       │                        + generate_change_summary()
  has_unversioned_changes=true         │
       │                        current_version_number=N+1
  Indicador: "v3 *"            has_unversioned_changes=false
                                Indicador: "v4"
```

### Restaurar Version (refactorizado)

```
Restaurar a v2
       │
  update design con datos de v2
  current_version_number = 2 (el restaurado)
  restored_from_version = 2
  has_unversioned_changes = false
       │
  Indicador: "v2"
  (si edita despues: "v2 *")
  (al guardar: crea version con "Restaurado desde v2. Cambiados: ...")
```

### Normativa en Canvas

```
Sin normativa asignada          Con normativa asignada
       │                              │
  Selector dropdown             Texto read-only
  (elegir normativa)            (nombre de la norma)
```

### Flujo de Etiquetas Multiples

```
[/generate/data]       [/generate/design]      [/designs/:id/edit]
      │                       │                       │
 Subir Excel/CSV ──────► Elegir diseno ──────► Vincular columnas
      │                       │                       │
 UploadDataStore.put()        │              UploadDataStore.get()
```

### Lecciones Aprendidas

- **Function components**: solo reciben assigns pasados explicitamente. Si se añaden assigns al socket, hay que pasarlos en la invocacion del componente. Error comun: `KeyError key :new_assign not found`
- **phx-key="Enter"**: filtra TODOS los event bindings del elemento (phx-keyup y phx-keydown). No usar si se necesita capturar keystrokes normales. Usar `<form phx-submit>` en su lugar
- **Streams**: elementos con `phx-update="stream"` no se re-renderizan con cambios de assigns. Usar modales globales fuera del stream
- **duplicate_hash?**: comparar solo contra la ultima version, no todas. Si no, restaurar a un estado anterior y guardar puede ser bloqueado por dedup
- **Formatos 2D (DataMatrix, Aztec, MaxiCode)**: siempre deben ser cuadrados. Forzar en 3 puntos: creacion desde compliance, render en canvas JS, y cambio de formato en panel de propiedades
- **Barcode scale != 1**: bwip-js genera a dimensiones nativas, no al tamaño target. Guardar `_creationScaleX/Y` y comparar contra eso, no contra 1, para detectar resize real
- **export/import de elementos**: cualquier campo nuevo en el schema debe añadirse a AMBAS funciones `export_element/1` e `import_element/1` en designs.ex, no solo al schema
- **Seeds de templates**: despues de modificar `templates.exs`, hay que re-ejecutar `mix run priv/repo/seeds/templates.exs` para que se actualicen en la DB (son idempotentes: delete+insert)
- **GS1 HRI format**: los DataMatrix FMD usan formato HRI con parentesis `(01)value(17)value...`, no el raw format con FNC1 separators. El parser debe soportar ambos

---

## Comandos Utiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Ejecutar migraciones
mix ecto.migrate

# Tests de versioning
mix test test/qr_label_system/designs/versioning_test.exs

# Tests de compliance
mix test test/qr_label_system/compliance/

# Tests completos
mix test

# Compilar
mix compile
```

---

## Historial de Sesiones Recientes

| Fecha | Sesion | Principales Cambios |
|-------|--------|---------------------|
| 14 feb 2026 | 18 | Canvas thumbnails, DataMatrix deselect fix, GS1 HRI, change info dedup |
| 14 feb 2026 | 17 | Campo compliance_role, HRI parsing, export/import fix, template roles |
| 14 feb 2026 | 16 | Fix 2D barcode square rendering (render, format change, compliance) |
| 14 feb 2026 | 15 | Refactor versiones, compliance read-only, auditoria, SVG preview |
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 14 febrero 2026 (sesion 18)*
