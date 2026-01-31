# Handoff: Sistema de Generación de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con códigos QR, códigos de barras y texto dinámico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesión Actual (31 enero 2026)

### Lo Que Se Implementó

#### 1. Auto-ajuste del Canvas para Etiquetas Grandes

**Problema:** Cuando una etiqueta tenía dimensiones grandes (ej: 300x200mm), el canvas empujaba los paneles laterales fuera de la pantalla.

**Solución implementada:**

- **CSS Transform** para escalar visualmente el canvas sin afectar el sistema de coordenadas
- **Cálculo dinámico** del espacio disponible basado en el viewport menos los sidebars fijos
- **Posicionamiento absoluto** del wrapper de Fabric.js dentro de un contenedor con dimensiones escaladas

**Archivos modificados:**
- `assets/js/hooks/canvas_designer.js`:
  - `fitToContainer()` - Calcula zoom óptimo para que el canvas quepa
  - `applyZoom()` - Aplica CSS transform + ajusta dimensiones del contenedor
- `lib/qr_label_system_web/live/design_live/editor.ex`:
  - Wrapper del canvas con `max-w-full max-h-full overflow-hidden`
  - Handler `zoom_changed` para sincronizar estado del zoom
  - Handler `fit_to_view` para ajuste manual
  - Botón "Ajustar a la vista" en toolbar

**Comportamiento:**
- Al cargar el editor, el canvas se ajusta automáticamente
- Al redimensionar la ventana, se re-ajusta
- Los controles de zoom (+/-/reset) funcionan normalmente
- El botón de ajustar a vista permite re-ajustar manualmente
- Las coordenadas del mouse funcionan correctamente (Fabric.js detecta el CSS transform)

#### 2. Separación de Diseños por Tipo

**Cambios:**
- Campo `label_type` en el schema `Design` (`"single"` o `"multiple"`)
- Migración `20260131174618_add_label_type_to_designs.exs`
- Función `list_user_designs_by_type/2` en `Designs` context
- `/generate/single` solo muestra diseños tipo "single"
- `/generate/design` (múltiples) solo muestra diseños tipo "multiple"
- Al crear diseño desde cada flujo, se asigna el tipo correcto

#### 3. Eliminación de Batches/Historial (Seguridad)

**Razón:** Evitar almacenamiento de datos sensibles que podrían ser robados.

**Eliminado:**
- Tabla `label_batches` (migración `20260131175329_drop_label_batches.exs`)
- Módulo `QrLabelSystem.Batches`
- LiveViews de batches (`BatchLive.*`)
- Enlace "Historial" en navegación
- Referencias en schemas relacionados

**Nuevo flujo:**
- Los datos se procesan en memoria usando `UploadDataStore` (GenServer)
- Se imprimen directamente sin persistencia
- Los datos se borran al cerrar sesión

#### 4. Flujo Data-First Mejorado

**Cambios en `/generate/design` → Editor:**
- Al seleccionar un diseño existente, navega al editor
- Los datos permanecen en `UploadDataStore`
- En el editor se pueden asignar columnas a elementos
- Preview muestra datos reales con navegación entre filas
- Botón "Generar X etiquetas" (pendiente de implementar generación)

#### 5. Cambio de Layout: Sidebar → Header Horizontal

**Cambio:** Se migró de un sidebar izquierdo de 256px a un header horizontal para maximizar el ancho del contenido.

**Archivos:**
- `lib/qr_label_system_web/components/layouts/app.html.heex`

---

## Arquitectura Actual

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUJO DE GENERACIÓN                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   /generate                                                  │
│       │                                                      │
│       ├── "Etiqueta Única"                                   │
│       │       │                                              │
│       │       ▼                                              │
│       │   /generate/single (diseños type="single")           │
│       │       │                                              │
│       │       ▼                                              │
│       │   /generate/single/:id → Imprimir                    │
│       │                                                      │
│       └── "Múltiples Etiquetas"                              │
│               │                                              │
│               ▼                                              │
│           /generate/data (cargar Excel/CSV)                  │
│               │                                              │
│               ▼ (datos en UploadDataStore)                   │
│           /generate/design (diseños type="multiple")         │
│               │                                              │
│               ▼                                              │
│           /designs/:id/edit (Editor)                         │
│               • Asignar columnas a elementos                 │
│               • Preview con datos reales                     │
│               • Generar PDF (pendiente)                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Cómo Funciona el Auto-Fit del Canvas

```javascript
// 1. Calcular espacio disponible
const availableWidth = viewport - sidebars - padding
const availableHeight = viewport - header - toolbar - padding

// 2. Calcular zoom necesario
const scaleX = availableWidth / canvasWidth
const scaleY = availableHeight / canvasHeight
const fitZoom = Math.min(scaleX, scaleY, 1)  // No más de 100%

// 3. Aplicar zoom con CSS transform
this.el.style.width = scaledWidth + 'px'
this.el.style.height = scaledHeight + 'px'
this.el.style.position = 'relative'
this.el.style.overflow = 'hidden'

fabricWrapper.style.position = 'absolute'
fabricWrapper.style.transform = `scale(${zoom})`
fabricWrapper.style.transformOrigin = 'top left'
```

---

## Pendiente / Para Continuar

### Alta Prioridad

1. **Generación de PDF desde Editor**
   - Implementar botón "Generar X etiquetas" que genera PDF
   - Usar los datos de `UploadDataStore`
   - Aplicar bindings de columnas a elementos

2. **Preview Multi-Etiqueta**
   - Modal/grid mostrando todas las etiquetas
   - Permitir navegar y verificar antes de imprimir

### Media Prioridad

3. **Mejoras en Preview del Editor**
   - Renderizar QR/barcode reales con datos del preview
   - Actualmente muestra placeholders

4. **Configuración de Impresión**
   - Tamaño de papel
   - Márgenes
   - Opciones para impresora de rollo

5. **Limpieza de Código**
   - Eliminar referencias residuales a batches en:
     - `telemetry.ex`
     - `audit/log.ex`
     - Comentarios en `user.ex`

### Baja Prioridad

6. **Eliminar Soporte de BD Externa**
   - `data_sources/db_connector.ex` ya no se usa
   - Limpiar código relacionado

---

## Archivos Clave

| Archivo | Descripción |
|---------|-------------|
| `assets/js/hooks/canvas_designer.js` | Editor de canvas con Fabric.js, zoom, auto-fit |
| `lib/qr_label_system_web/live/design_live/editor.ex` | LiveView del editor |
| `lib/qr_label_system/upload_data_store.ex` | GenServer para datos en memoria |
| `lib/qr_label_system_web/live/generate_live/` | Flujo de generación |
| `lib/qr_label_system/designs.ex` | Context de diseños |

---

## Comandos Útiles

```bash
# Servidor de desarrollo
mix phx.server

# Tests
mix test

# Consola interactiva
iex -S mix

# Ver datos en UploadDataStore
QrLabelSystem.UploadDataStore.get(user_id)

# Limpiar datos de un usuario
QrLabelSystem.UploadDataStore.clear(user_id)
```

---

## Commits Recientes

```
6f6abb2 refactor(layout): Replace sidebar with horizontal header
f8be491 feat(generate): Improve data-first workflow with persistent upload storage
957635f security: Add authorization checks and remove debug code
7d21d23 security: Remove batch/history storage to prevent data theft
5fdd103 fix(editor): Multiple editor improvements and fixes
```

---

## Notas Técnicas

### UploadDataStore (GenServer)

Almacena datos cargados en memoria por usuario:

```elixir
# Guardar datos
UploadDataStore.put(user_id, rows, columns)

# Obtener datos
{rows, columns} = UploadDataStore.get(user_id)

# Limpiar
UploadDataStore.clear(user_id)
```

Los datos se mantienen entre navegaciones pero se pierden al reiniciar el servidor.

### CSS Transform + Fabric.js

Fabric.js automáticamente detecta CSS transforms y ajusta coordenadas:
- Compara `canvas.width` con `getBoundingClientRect().width`
- Calcula `cssScale` internamente
- Ajusta coordenadas del mouse en `getPointer()`

Por eso no necesitamos ajustar manualmente las coordenadas.

### Tipos de Etiqueta

- `"single"`: Contenido estático, se imprime N copias iguales
- `"multiple"`: Contenido dinámico desde datos, cada etiqueta diferente

---

*Handoff actualizado: 31 enero 2026*
