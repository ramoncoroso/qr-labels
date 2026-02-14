# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (14 febrero 2026) - Refactor Historial de Versiones

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Versiones solo en guardado explicito (no autosave) | Completado |
| 2 | Renombrar versiones con custom_name | Completado |
| 3 | Indicador de version actual con marcador de cambios | Completado |
| 4 | Diff contra version anterior (no contra la ultima) | Completado |
| 5 | Restaurar sin crear version automatica | Completado |
| 6 | Fix: pasar assigns al componente unified_status_bar | Completado |

### Problema Original

El editor creaba un snapshot de version en cada autosave, inundando el historial con micro-cambios. El usuario queria:
- Versiones solo al pulsar "Guardar"
- Poder renombrar versiones
- Indicador que refleje la version actual real

### Cambios Realizados

**Migracion:** `20260214120000_add_custom_name_to_design_versions.exs`
- Columna nullable `custom_name :string` en `design_versions`

**Schema (`design_version.ex`):**
- Campo `custom_name`, añadido al changeset
- Nuevo `rename_changeset/2` con validacion max 100 chars

**Versioning (`versioning.ex`):**
- `restore_version/3` — Ya no crea version al restaurar, solo actualiza el diseño
- `rename_version/3` — Nuevo: poner/quitar nombre personalizado a versiones
- `generate_change_summary/2` — Nuevo: genera resumen legible de cambios vs ultima version
- `diff_against_previous/2` — Nuevo: diff contra version anterior (para panel de detalle)
- `compute_hash/4` — Eliminado `change_message` del hash (ya no necesario)
- Helpers privados: `get_latest_version/1`, `diff_fields_against_design/2`, `field_label/1`

**Designs context (`designs.ex`):**
- Eliminado bloque `Task.start` en `update_design/3` que creaba snapshots automaticos

**Editor LiveView (`editor.ex`):**
- Mount: nuevos assigns `current_version_number`, `has_unversioned_changes`, `restored_from_version`, `renaming_version_id`, `rename_version_value`
- `do_save_elements`: dos caminos — autosave (marca `has_unversioned_changes`) y guardado explicito (crea snapshot con `generate_change_summary`)
- `restore_version`: establece `current_version_number` al restaurado, sin crear version
- Handlers de renombrar: `start_rename_version`, `save_rename_version`, `cancel_rename_version`, `update_rename_version_value`
- `handle_select_version`: usa `diff_against_previous` en vez de diff vs ultima
- Undo/redo: marcan `has_unversioned_changes: true`
- Template: indicador `v3 *`, badge "actual", custom_name, inline rename, textos actualizados
- Fix: pasar `current_version_number` y `has_unversioned_changes` al componente `unified_status_bar`

**Tests (`versioning_test.exs`):**
- 31 tests, 0 failures
- Tests actualizados para nuevo comportamiento (restore no crea version, update_design no crea snapshot)
- Tests nuevos para `rename_version`, `generate_change_summary`, `diff_against_previous`

### Commits de Esta Sesion

```
495062b Refactor version history: explicit saves only, rename, and version indicator
```

---

## Tareas Pendientes

### Bugs (prioridad alta)

| # | Tarea | Descripcion |
|---|-------|-------------|
| 9 | Nombre no se graba | Al guardar el diseño, el nombre no persiste correctamente |
| 10 | Rename version no graba | El inline rename de versiones no persiste el custom_name |
| 16 | DataMatrix formato raro | Al añadir DataMatrix desde compliance, aparece con formato incorrecto |

### Mejoras UI - Versiones

| # | Tarea | Descripcion |
|---|-------|-------------|
| 8 | Simplificar info en lista | La lista del historial muestra informacion excesiva |
| 12 | Lapiz renombrar mas visible | Icono muy pequeño, colocarlo al lado de la version y mas grande |
| 11 | Preview de etiqueta en "Ver" | Mostrar preview visual de la etiqueta en el detalle de version |

### Compliance / Normativas

| # | Tarea | Descripcion |
|---|-------|-------------|
| 13 | Bloquear cambio de normativa | Analizar si permitir cambiar normativa tras seleccionarla |
| 14 | Normativa solo lectura en canvas | En editor, mostrar la norma sin selector (read-only) |
| 15 | Revisar avisos y "añadir campo" | Verificar comportamiento de avisos y accion de añadir campos faltantes |

### Plan de Abordaje Sugerido

1. **Primero bugs:** #9, #10, #16
2. **Luego UI versiones:** #8, #12 (rapidos), #11 (mas complejo)
3. **Compliance:** #13, #14, #15

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
  (si edita después: "v2 *")
  (al guardar: crea version con "Restaurado desde v2. Cambiados: ...")
```

### Flujo de Etiquetas Multiples

```
[/generate/data]       [/generate/design]      [/designs/:id/edit]
      │                       │                       │
 Subir Excel/CSV ──────► Elegir diseño ──────► Vincular columnas
      │                       │                       │
 UploadDataStore.put()        │              UploadDataStore.get()
```

### Streams y Assigns en LiveView

**Importante:** Los elementos renderizados con `phx-update="stream"` solo se actualizan cuando el stream cambia, NO cuando otros assigns cambian. Para UI interactiva dentro de streams, usar modales globales fuera del stream.

### Componentes de Funcion y Assigns

**Importante:** Los function components (`defp component(assigns)`) solo reciben los assigns que se les pasan explicitamente. Si se añaden nuevos assigns al socket, hay que pasarlos tambien en la invocacion del componente. Error comun: `KeyError key :new_assign not found`.

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
| 14 feb 2026 | 15 | Refactor historial versiones: solo guardado explicito, rename, indicador |
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 14 febrero 2026 (sesion 15)*
