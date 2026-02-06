# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (6 febrero 2026) - SVG Previews y Sistema de Categorias

### Resumen Ejecutivo

| # | Tarea | Estado |
|---|-------|--------|
| 1 | SVG thumbnails en pagina de seleccion de diseno | Completado |
| 2 | Botones de accion en tarjetas de diseno | Completado |
| 3 | Modal de previsualizacion ampliada | Completado |
| 4 | Sistema de categorias para organizar disenos | Completado |

---

### 1. SVG Thumbnails para Disenos

**Problema:** La pagina `/generate/design` solo mostraba un rectangulo vacio como preview.

**Solucion:** Crear modulo `SvgPreview` que genera SVG con representacion visual de elementos.

**Archivo creado:** `lib/qr_label_system/designs/svg_preview.ex`

```elixir
defmodule QrLabelSystem.Designs.SvgPreview do
  def generate(design, opts \\ []) do
    # Genera SVG escalado con:
    # - QR: patron simplificado con esquinas
    # - Barcode: lineas verticales
    # - Text: texto real con fuente y color
    # - Image: placeholder gris con icono
  end
end
```

**Nota importante:** El SVG necesita `style="pointer-events: none;"` para que los clics pasen al elemento padre.

---

### 2. Botones de Accion en Tarjetas (Opcion B)

**Antes:** Boton "Usar este diseno" en la parte inferior de la pagina.

**Despues:** Botones dentro de la tarjeta seleccionada:
- **Ampliar** - Abre modal con preview grande
- **Usar diseno** - Continua al siguiente paso

**Archivo modificado:** `lib/qr_label_system_web/live/generate_live/design_select.ex`

**Fix de tipos:** Comparacion `@selected_design_id == to_string(design.id)` porque phx-value devuelve strings.

---

### 3. Sistema de Categorias

**Caso de uso:** Almacen con etiquetas para estanterias, materiales, equipos, etc.

**Implementacion:**

| Componente | Descripcion |
|------------|-------------|
| **Modelo Category** | name, color, user_id |
| **Relacion** | Design belongs_to Category (opcional) |
| **Migracion** | `design_categories` + `category_id` en `label_designs` |

**Archivos creados:**
- `lib/qr_label_system/designs/category.ex`
- `priv/repo/migrations/20260206212231_create_categories.exs`

**Archivos modificados:**
- `lib/qr_label_system/designs/design.ex` - belongs_to :category
- `lib/qr_label_system/designs.ex` - funciones CRUD de categorias
- `lib/qr_label_system_web/live/design_live/index.ex` - UI completa

**Funciones agregadas en Designs:**
```elixir
list_user_categories/1
create_category/1, update_category/2, delete_category/1
list_user_designs_by_category/2
preload_category/1
```

---

### 4. Fix: Modal de Categorias con Streams

**Problema:** El dropdown de asignar categoria no aparecia al hacer clic.

**Causa raiz:** Con `phx-update="stream"`, los elementos dentro del stream NO se re-renderizan cuando cambia un assign externo.

**Solucion:** Usar modal global fuera del stream en lugar de dropdown dentro de cada tarjeta.

```elixir
# INCORRECTO - dentro del stream:
<%= if @assigning_category_to == design.id do %>
  <div class="dropdown">...</div>  # Nunca se renderiza
<% end %>

# CORRECTO - fuera del stream:
<%= if @assigning_category_to do %>
  <% design = Enum.find(@all_designs, ...) %>
  <div class="modal">...</div>  # Se renderiza correctamente
<% end %>
```

---

### Commits de Esta Sesion

```
d385ba1 fix: Use modal instead of dropdown for category assignment
0e23ce0 feat: Add category system for organizing designs
bf45afa feat: Add action buttons and preview modal to design cards
88b3440 feat: Add SVG thumbnail previews for designs in selection page
```

---

## Arquitectura Clave

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

### Mecanismo pending_selection_id

Previene deseleccion durante operaciones asincronas:

```
1. Usuario cambia binding
2. assign(:pending_selection_id, element_id)
3. Canvas recrea elemento, emite element_selected
4. Handler ve pending_selection_id == id, ignora evento
5. element_modified completa, limpia pending_selection_id
```

---

## UI de Categorias

```
┌─────────────────────────────────────┐
│  Filtrar por categoría  ▼  │ ⚙️    │
├─────────────────────────────────────┤
│  ○ Todas las categorías             │
│  ○ Sin categoría                    │
│  ──────────────────────             │
│  ● Estanterías                      │
│  ○ Materiales                       │
│  ○ Equipos                          │
└─────────────────────────────────────┘

Cada diseño muestra:
- Badge de categoria con color personalizado
- Boton de etiqueta para asignar/cambiar categoria
```

---

## Comandos Utiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Ejecutar migracion de categorias
mix ecto.migrate

# Tests
mix test

# Compilar (verificar cambios)
mix compile
```

---

## Plan para Continuar

### Problemas Conocidos

1. **Warning cosmetico:** `handle_event/3` clauses no agrupadas
   - En editor.ex e index.ex
   - No afecta funcionalidad

### Tareas Pendientes

| Tarea | Esfuerzo | Descripcion |
|-------|----------|-------------|
| **Preview de etiquetas con datos** | Alto | Navegar registros del Excel en editor |
| **Generacion PDF de lote** | Alto | PDF con todas las etiquetas |
| **Subcategorias** | Medio | Jerarquia de categorias (parent_id) |

---

## Historial de Sesiones Recientes

| Fecha | Sesion | Principales Cambios |
|-------|--------|---------------------|
| 6 feb 2026 | 14 | SVG previews, botones en tarjetas, sistema categorias |
| 6 feb 2026 | 13 | Fix compilacion, modal importacion con seleccion |
| 4 feb 2026 | 12 | Fix element loss, binding mode, UI texto duplicado |
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads, cleanup job |

---

*Handoff actualizado: 6 febrero 2026 (sesion 14)*
