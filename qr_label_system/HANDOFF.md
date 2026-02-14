# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (14 febrero 2026) - Auditoria de seguridad y robustez

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Auditoria completa de seguridad y bugs (auth, input, JS, data) | Completado |
| 2 | CRITICAL: Race condition en `create_snapshot` version_number | Completado |
| 3 | CRITICAL: `String.to_integer` sin guard en `new.ex` | Completado |
| 4 | HIGH: Ownership check faltante en `data_source_live/show.ex` | Completado |
| 5 | HIGH: Ownership check faltante en duplicate de `index.ex` | Completado |
| 6 | HIGH: 13 instancias de `Integer.parse` inseguro en `index.ex` | Completado |
| 7 | HIGH: Cache no invalidado en operaciones de tags | Completado |
| 8 | HIGH: Memory leak en `sortable_layers.js` (handlers no limpiados) | Completado |
| 9 | Fix: Warning de compilacion por agrupacion de clausulas en `editor.ex` | Completado |

---

### Cambios por Area

#### Auditoria de seguridad

Se lanzaron 4 agentes de auditoria en paralelo cubriendo:
- Autenticacion y control de acceso
- Validacion de inputs y sanitizacion
- Seguridad client-side (JS)
- Integridad de datos y race conditions

Se identificaron ~50 issues clasificados como CRITICAL, HIGH, MEDIUM, LOW. Se corrigieron todos los CRITICAL y HIGH.

#### CRITICAL: Race condition en version_number (`versioning.ex`)

**Problema:** `next_version_number` + `Repo.insert` no estaban dentro de una transaccion. Dos llamadas concurrentes a `create_snapshot` podian obtener el mismo numero de version.

**Solucion:** Envolver la creacion de version en `Repo.transaction` con `FOR UPDATE` row lock en la tabla `designs`. El cleanup async se ejecuta fuera de la transaccion.

#### CRITICAL: String.to_integer sin guard (`new.ex`)

**Problema:** `String.to_integer(template_id)` en `handle_event("select_template")` crashea con input invalido.

**Solucion:** Reemplazado por `Integer.parse` + pattern match. Input invalido retorna `{:noreply, socket}`. Logica extraida a `defp do_select_template/2` con clausula nil.

#### HIGH: Ownership checks faltantes

**`data_source_live/show.ex`:**
- Añadido check `data_source.user_id != current_user.id` en `mount/3`
- Redirige a `/data-sources` con flash de error si no es propietario

**`design_live/index.ex` (duplicate):**
- Añadida clausula guard `design when design.user_id != current_user.id` en handler `"duplicate"`
- Retorna flash de error "No tienes permiso para duplicar este diseño"

#### HIGH: Integer.parse inseguro (`index.ex`)

**Problema:** 13 instancias de `{id_int, ""} = Integer.parse(id)` que crashean con `MatchError` si el input no es un entero valido. Un atacante podria enviar valores arbitrarios via WebSocket.

**Solucion:**
- Añadido helper `defp safe_int/1` que retorna `nil` en lugar de crashear
- Todos los handlers restructurados con `case`/`if` para manejar `nil` gracefully
- Handlers afectados: `start_rename`, `cancel_rename`, `start_edit_desc`, `cancel_edit_desc`, `toggle_import_selection`, `toggle_tag_filter`, `open_tag_input`, `close_tag_input`, `select_tag_suggestion`, `remove_tag_from_design`, `do_add_tag`

#### HIGH: Cache invalidation en tags (`designs.ex`)

**Problema:** `add_tag_to_design` y `remove_tag_from_design` no invalidaban el cache del diseno, causando datos stale si el diseno se accedia via cache despues de modificar tags.

**Solucion:** Añadido `Cache.delete(:designs, {:design, design.id})` en ambas funciones.

#### HIGH: Memory leak en sortable_layers.js

**Problema:** `initSortable()` (llamado en cada `updated()`) añadia handlers `mousedown` a los drag handles sin remover los anteriores. Solo los handlers `document`-level (mousemove/mouseup) se limpiaban.

**Solucion:** Los handlers de mousedown se almacenan en `this._handleListeners` y se remueven en `cleanup()` junto con los handlers de documento.

#### Fix: Warning de compilacion en editor.ex

`defp do_save_rename_version` estaba entre clausulas de `handle_event/3`, rompiendo el agrupamiento. Movida despues del ultimo `handle_event`.

### Issues evaluados y descartados

| Issue | Razon |
|-------|-------|
| Debug route `/debug/editor/:id` sin auth | Ya esta dentro de `if dev_routes`, solo existe en dev |
| `user_id` requerido en audit log | Eventos de sistema podrian no tener user_id, cambio riesgoso |
| Memory leak en `draggable_elements.js` | Ya tiene cleanup correcto con `_cleanupFns` pattern |
| Race condition load_design vs save en canvas_designer.js | Complejo, bajo impacto real |

### Commits de Esta Sesion

```
c92681e Fix CRITICAL and HIGH security/robustness issues from audit
```

---

## Plan Pendiente: Refactor Version History System

> **Archivo del plan:** `~/.claude/plans/polymorphic-moseying-shannon.md`

### Estado del Plan

El plan describe un refactor completo del sistema de versiones. **La mayoria de los pasos ya estan implementados** de sesiones anteriores:

| Step | Descripcion | Estado |
|------|-------------|--------|
| 1 | Migracion `custom_name` en `design_versions` | Completado (`20260214120000`) |
| 2 | Schema: campo `custom_name` + `rename_changeset` | Completado |
| 3A | `restore_version/3` simplificado (sin crear version) | Completado |
| 3B | `rename_version/3` | Completado |
| 3C | `generate_change_summary/2` | Completado |
| 3D | `diff_against_previous/2` | Completado |
| 3E | `compute_hash` cleanup | Completado |
| 4 | Eliminar auto-snapshot de `update_design/3` | Completado |
| 5A | Assigns: `has_unversioned_changes`, `current_version_number`, `restored_from_version` | Completado |
| 5B | `do_save_elements`: autosave vs explicit save paths | Completado |
| 5C | `restore_version` handler sin crear version | Completado |
| 5D | Version rename handlers (start/save/cancel/update) | Completado |
| 5E | `handle_select_version` con `diff_against_previous` | Completado |
| 5F | Undo/redo marcan `has_unversioned_changes` | Completado |
| 5G | Template: indicador `v3 *`, badge "actual", custom_name, rename UI | Completado |
| 6 | Tests | **Pendiente de verificar** |

**Todo el plan esta implementado.** Falta verificar que los tests cubran los nuevos escenarios (ver Step 6 del plan).

---

## Sesion Anterior (14 febrero 2026) - Thumbnails, DataMatrix, compliance_role, GS1 HRI

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

## Arquitectura Clave

### Flujo de Versiones (refactorizado)

```
Autosave (cada cambio)         Guardar (boton explicito)
       │                              │
  update_design()               update_design()
  sin crear version             + create_snapshot() [con FOR UPDATE lock]
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
- **Integer.parse seguro**: nunca usar `{id, ""} = Integer.parse(str)` con input de usuario. Usar un helper `safe_int/1` que retorna `nil` en lugar de crashear con MatchError
- **Cache en tags**: al modificar relaciones many-to-many (tags), invalidar el cache de la entidad padre (design) explicitamente
- **Clausulas agrupadas**: en LiveView, todas las clausulas de `handle_event/3` deben estar juntas sin `defp` intermedias, o el compilador da warning con `--warnings-as-errors`
- **Transacciones en version creation**: usar `FOR UPDATE` lock en la fila del design para serializar creacion concurrente de versiones

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

# Compilar (con warnings como errores)
mix compile --warnings-as-errors
```

---

## Historial de Sesiones Recientes

| Fecha | Sesion | Principales Cambios |
|-------|--------|---------------------|
| 14 feb 2026 | 19 | Auditoria seguridad: race condition fix, ownership checks, safe Integer.parse, cache tags |
| 14 feb 2026 | 18 | Canvas thumbnails, DataMatrix deselect fix, GS1 HRI, change info dedup |
| 14 feb 2026 | 17 | Campo compliance_role, HRI parsing, export/import fix, template roles |
| 14 feb 2026 | 16 | Fix 2D barcode square rendering (render, format change, compliance) |
| 14 feb 2026 | 15 | Refactor versiones, compliance read-only, auditoria, SVG preview |
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 14 febrero 2026 (sesion 19)*
