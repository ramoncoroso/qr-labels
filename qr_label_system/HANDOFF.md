# Handoff: Sistema de Generación de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con códigos QR, códigos de barras y texto dinámico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesión Actual (31 enero 2026) - Parte 3

### Lo Que Se Implementó

#### 1. Corrección de Acceso a Campos de Elementos

**Problema:** Al crear elementos rectangle, line o image, aparecía error:
```
** (KeyError) key :binding not found in: %{...}
```

**Causa:** El template accedía directamente a `@element.binding` pero cuando los elementos vienen de vuelta del JavaScript canvas, son mapas planos que pueden no tener todas las claves.

**Solución:** Cambiar accesos directos a `Map.get/2`:
```elixir
# Antes (fallaba):
value={@element.binding || ""}

# Después (funciona):
value={Map.get(@element, :binding) || ""}
```

**Archivos modificados:**
- `lib/qr_label_system_web/live/design_live/editor.ex` líneas 1554, 1565

#### 2. Panel de Propiedades Específico por Tipo de Elemento

**Problema:** Rectangle y line no tenían propiedades editables en el panel derecho.

**Solución:** Añadidos paneles específicos:
- **Línea**: Color
- **Rectángulo**: Color de fondo, color de borde, ancho de borde
- **Imagen**: Ya tenía uploader de imagen

```elixir
<% "line" -> %>
  <div class="border-t pt-4 space-y-3">
    <div>
      <label>Color</label>
      <input type="color" value={Map.get(@element, :color) || "#000000"} ... />
    </div>
  </div>

<% "rectangle" -> %>
  <div class="border-t pt-4 space-y-3">
    <div><label>Color de fondo</label><input type="color" .../></div>
    <div><label>Color de borde</label><input type="color" .../></div>
    <div><label>Ancho de borde (mm)</label><input type="number" .../></div>
  </div>
```

#### 3. Configuración de Drag and Drop (EN PROGRESO)

**Estado:** El módulo JavaScript carga pero el hook `mounted()` no se ejecuta.

**Configuración actual:**
- Hook `DraggableElements` en `assets/js/hooks/draggable_elements.js`
- Registrado en `assets/js/hooks/index.js`
- Toolbar con `id="element-toolbar" phx-hook="DraggableElements"`
- Botones con `class="draggable-element" data-element-type="xxx"`
- Canvas tiene `setupDragAndDrop()` para recibir drops

**Problema a resolver:**
- El console.log de nivel módulo aparece ("DraggableElements module loaded!")
- Pero `mounted()` nunca se llama
- Posible causa: conflicto con cómo LiveView maneja el hook en ese elemento específico

**Para depurar:**
1. Verificar en DevTools → Elements que el div tiene `id="element-toolbar"` y `phx-hook="DraggableElements"`
2. Verificar que no hay errores de JavaScript en la consola
3. Probar mover el hook a un elemento más simple para aislar el problema

---

## Sesión Anterior (31 enero 2026) - Parte 2

### Lo Que Se Implementó

#### 1. Mejora de Visibilidad del Botón "Volver a selección de modo"

**Archivos:** `single_select.ex`, `data_first.ex`

#### 2. Botón de Renombrar Movido al Editor

**Archivos:** `index.ex`, `editor.ex`

#### 3. Simplificación de Controles de Ajuste (Grid)

Eliminado "Imán", solo queda "Rejilla" con función `alignAllElementsToGrid()`.

#### 4. Nombres Secuenciales para Elementos

"Código QR 1", "Código QR 2", etc.

#### 5. Offset de Posición para Nuevos Elementos

5mm de offset por elemento del mismo tipo.

#### 6. Campo `binding: nil` en todos los elementos

Añadido a rectangle, line, image en `create_default_element/2`.

---

## Pendiente / Para Continuar

### Alta Prioridad

1. **Generación de PDF desde Editor** ⬅️ PRÓXIMO PASO PRINCIPAL
   - Implementar botón "Generar X etiquetas" que genera PDF
   - Usar los datos de `UploadDataStore`
   - Aplicar bindings de columnas a elementos

2. **Arreglar Drag and Drop** (si se desea esta funcionalidad)
   - El hook DraggableElements no monta correctamente
   - Mientras tanto, el CLICK funciona perfectamente para añadir elementos

### Media Prioridad

3. **Preview Multi-Etiqueta**
4. **Mejoras en Preview del Editor** (QR/barcode reales)
5. **Configuración de Impresión**

### Baja Prioridad

6. **Limpieza de Código** (referencias a batches)
7. **Eliminar Soporte de BD Externa**

---

## Archivos Clave

| Archivo | Descripción |
|---------|-------------|
| `assets/js/hooks/canvas_designer.js` | Editor de canvas con Fabric.js |
| `assets/js/hooks/draggable_elements.js` | Hook para drag (no funciona aún) |
| `lib/qr_label_system_web/live/design_live/editor.ex` | LiveView del editor |
| `lib/qr_label_system/upload_data_store.ex` | GenServer para datos en memoria |

---

## Comandos Útiles

```bash
# Servidor de desarrollo
mix phx.server

# Tests
mix test

# Consola interactiva
iex -S mix
```

---

## Bugs Conocidos y Soluciones

### KeyError: key :binding not found

**Síntoma:** Error al crear/seleccionar elementos.
**Solución:** Usar `Map.get(@element, :field)` en lugar de `@element.field` en templates.

### Hook DraggableElements no monta

**Síntoma:** El módulo carga pero `mounted()` no se ejecuta.
**Estado:** En investigación. Click funciona como alternativa.

---

*Handoff actualizado: 31 enero 2026 (sesión 3)*
