# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (14 febrero 2026) - Refactor Versiones, Compliance, Auditoria

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Versiones solo en guardado explicito (no autosave) | Completado |
| 2 | Renombrar versiones con custom_name | Completado |
| 3 | Indicador de version actual con marcador de cambios | Completado |
| 4 | Diff contra version anterior (no contra la ultima) | Completado |
| 5 | Restaurar sin crear version automatica | Completado |
| 6 | Fix: pasar assigns al componente unified_status_bar | Completado |
| 7 | Auditoria de codigo: fix bugs criticos y mejoras | Completado |
| 8 | Simplificar lista de versiones | Completado |
| 9 | Fix: nombre del diseno se graba correctamente | Completado |
| 10 | Fix: rename version (phx-submit en vez de phx-key) | Completado |
| 11 | Preview SVG en detalle de version | Completado |
| 12 | Lapiz de renombrar mas visible (w-4 al lado de vN) | Completado |
| 13 | Normativa: analisis de bloqueo tras seleccion | Completado |
| 14 | Normativa solo lectura en canvas | Completado |
| 15 | Revisar avisos compliance y accion "añadir campo" | Completado |
| 16 | Fix: DataMatrix dimensiones cuadradas desde compliance | Completado |

---

### Cambios por Area

#### Historial de Versiones (refactorizado)

**Migracion:** `20260214120000_add_custom_name_to_design_versions.exs`
- Columna nullable `custom_name :string` en `design_versions`

**Schema (`design_version.ex`):**
- Campo `custom_name`, añadido al changeset
- Nuevo `rename_changeset/2` con validacion max 100 chars

**Versioning (`versioning.ex`):**
- `restore_version/3` — Ya no crea version al restaurar, solo actualiza el diseno
- `rename_version/3` — Nuevo: poner/quitar nombre personalizado a versiones
- `generate_change_summary/2` — Nuevo: genera resumen legible de cambios vs ultima version
- `diff_against_previous/2` — Nuevo: diff contra version anterior (para panel de detalle)
- `compute_hash/4` — Eliminado `change_message` del hash
- `duplicate_hash?/2` — Corregido: solo compara contra la ultima version (no todas)

**Designs context (`designs.ex`):**
- Eliminado bloque `Task.start` en `update_design/3` que creaba snapshots automaticos

**Editor LiveView (`editor.ex`):**
- Mount: nuevos assigns `current_version_number`, `has_unversioned_changes`, `restored_from_version`, `renaming_version_id`, `rename_version_value`, `version_preview_svg`
- `do_save_elements`: autosave (marca `has_unversioned_changes`) vs guardado explicito (crea snapshot)
- `restore_version`: establece `current_version_number` al restaurado, sin crear version
- Rename: usa `<form phx-submit>` (fix critico — antes `phx-key="Enter"` rompia el input)
- `handle_select_version`: usa `diff_against_previous`, genera SVG preview on-demand
- Template: indicador `v3 *`, badge "actual", custom_name inline, lapiz w-4, preview SVG

#### Compliance / Normativas

- **Normativa read-only en canvas**: si ya tiene normativa asignada, muestra nombre como texto (no selector). El selector solo aparece cuando no hay normativa
- **DataMatrix fix**: formatos 2D (DATAMATRIX, AZTEC, MAXICODE) se crean con dimensiones cuadradas (20x20mm) en vez de lineales (40x15mm)
- **Avisos de compliance**: revisado el flujo de "Agregar campo" — funciona correctamente

#### Auditoria de Codigo

Fixes aplicados de la auditoria automatica:
- **Critico**: Rename version usaba `phx-key="Enter"` que impedia capturar keystrokes → cambiado a `<form phx-submit>`
- **Medio**: `duplicate_hash?` comparaba contra TODAS las versiones → solo contra la ultima
- **Medio**: `Integer.parse` sin guard en handlers de rename → añadido `case` con fallback
- **Bajo**: Doble llamada a `latest_version_number` en mount → unificada en una variable

**Tests:** 31 tests, 0 failures

### Commits de Esta Sesion

```
495062b Refactor version history: explicit saves only, rename, and version indicator
a4b73a9 Fix version rename, deduplicate hash check, and simplify version list UI
07a6b9f Fix DataMatrix dimensions from compliance and make standard read-only
f38e703 Add SVG preview in version detail panel
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

---

## Comandos Utiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Ejecutar migraciones
mix ecto.migrate

# Tests de versioning
mix test test/qr_label_system/designs/versioning_test.exs

# Tests completos
mix test

# Compilar
mix compile
```

---

## Historial de Sesiones Recientes

| Fecha | Sesion | Principales Cambios |
|-------|--------|---------------------|
| 14 feb 2026 | 15 | Refactor versiones, compliance read-only, auditoria, SVG preview |
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 14 febrero 2026 (sesion 15)*
