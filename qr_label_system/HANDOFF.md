# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (14 febrero 2026) - Campo compliance_role, HRI parsing, Export/Import fix

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Campo `compliance_role` en Element schema | Completado |
| 2 | Deteccion por compliance_role en validadores (EU1169, FMD, GS1) | Completado |
| 3 | Dropdown "Rol normativo" en editor (condicional a normativa activa) | Completado |
| 4 | fix_action con compliance_role en botones "Agregar campo" | Completado |
| 5 | Auto-asignar compliance_role en plantillas de sistema (seeds) | Completado |
| 6 | Fix: export/import missing 11 fields (compliance_role + 10 mas) | Completado |
| 7 | Fix: DataMatrix fix_action con GS1 HRI valido | Completado |
| 8 | Fix: GS1 Checksum - parseo de formato HRI con parentesis | Completado |
| 9 | Fix: toolbar "ELEMENTOS" overflow (w-20 → w-24) | Completado |
| 10 | Tests compliance_role (4 unit + 2 LiveView) | Completado |

**Plan de referencia:** `.claude/plans/quirky-fluttering-zebra.md`

---

### Cambios por Area

#### Campo `compliance_role` (nuevo)

**Problema:** La deteccion de cumplimiento normativo usaba heuristicas regex sobre nombre/binding/texto. Fragil e impredecible cuando el usuario nombra elementos libremente.

**Solucion:** Campo explicito `compliance_role` en cada elemento. Los validadores lo comprueban primero y usan regex como fallback.

**Element schema (`element.ex`):**
- `field :compliance_role, :string` en embedded_schema
- Añadido al cast en changeset

**Design JSON (`design.ex`):**
- `compliance_role: element.compliance_role` en `element_to_json/1`

**Validadores (3 archivos):**
- `eu1169_validator.ex`: `detect_fields/1` busca primero por `compliance_role`, luego regex. 10 roles: `product_name`, `ingredients`, `allergens`, `net_quantity`, `best_before`, `manufacturer`, `origin`, `nutrition`, `lot`, `eu1169_barcode`
- `fmd_validator.ex`: misma logica. 9 roles: `product_name`, `active_ingredient`, `lot`, `expiry`, `national_code`, `serial`, `dosage`, `manufacturer`, `datamatrix_fmd`
- `gs1_validator.ex`: detecta barcodes con `compliance_role: "gs1_barcode"`. 1 rol
- Todos los `fix_action` maps incluyen `compliance_role` para auto-asignar al agregar campo

**Editor (`editor.ex`):**
- `"compliance_role"` en `@allowed_element_fields`
- Dropdown "Rol normativo" condicional: solo visible con normativa activa
- Muestra checkmark ✓ en roles ya asignados a otros elementos
- `compliance_roles_for/1` helper con labels por estandar
- `add_compliance_element` handler pasa `compliance_role` del fix_action
- Botones compliance panel: `phx-value-compliance_role={issue.fix_action[:compliance_role]}`

**Templates (`templates.exs`):**
- `SeedEl.t/6` y `SeedEl.bc/6` aceptan `cr:` option
- 10 plantillas con roles auto-asignados (3 eu1169, 3 fmd, 4 gs1)
- Solo elementos de datos reciben rol, no prefijos de label

#### Export/Import fix

**`designs.ex` — `export_element/1` y `import_element/1`:**
- Añadidos 11 campos que faltaban: `qr_logo_size`, `text_auto_fit`, `text_min_font_size`, `border_radius`, `image_filename`, `z_index`, `visible`, `locked`, `name`, `group_id` (con defaults), `compliance_role`

#### GS1 Checksum — formato HRI

**`gs1/checksum.ex`:**
- `parse_gs1_128/1` ahora soporta formato HRI con parentesis: `(01)03453120000011(17)261231(10)ABC123(21)SN456789`
- `looks_like_gs1?/1` detecta formato HRI
- Nueva funcion `parse_hri_format/1` con regex scan

#### UI fix

- Toolbar lateral: `w-20` → `w-24` + `overflow-hidden` para evitar desborde de "ELEMENTOS"

**Tests:** 35 tests, 0 failures

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
| 14 feb 2026 | 17 | Campo compliance_role, HRI parsing, export/import fix, template roles |
| 14 feb 2026 | 16 | Fix 2D barcode square rendering (render, format change, compliance) |
| 14 feb 2026 | 15 | Refactor versiones, compliance read-only, auditoria, SVG preview |
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 14 febrero 2026 (sesion 17)*
