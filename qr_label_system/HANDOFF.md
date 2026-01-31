# Handoff: Sistema de Generación de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con códigos QR, códigos de barras y texto dinámico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesión Actual (31 enero 2026) - Parte 5

### Lo Que Se Implementó

#### 1. Fix: Subida de Imágenes en el Editor

**Problema:** Las imágenes se subían pero no aparecían en el canvas, o aparecían brevemente y luego desaparecían.

**Causa Raíz:**
- Condición de carrera entre operaciones de guardado y eventos `load_design`
- El evento `load_design` revertía el estado del canvas después de cambios del usuario
- La búsqueda de elementos por ID no manejaba tipos string y number

**Solución:**
- Flag `canvas_loaded` en `editor.ex` para prevenir múltiples eventos `load_design`
- Tracking de `_lastSaveTime` en `canvas_designer.js` para ignorar `load_design` que llegan muy pronto después de guardar
- Búsqueda de elementos por ID mejorada en `updateElementImage()` para manejar tanto string como number

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `assets/js/hooks/canvas_designer.js`

#### 2. Fix: Cambios se Revertían Automáticamente (~3 segundos)

**Problema:** Los cambios hechos a las etiquetas se revertían automáticamente después de aproximadamente 3 segundos.

**Causa Raíz:**
- El hook `AutoHideFlash` enviaba evento `lv:clear-flash` después de 3 segundos
- Esto disparaba a LiveView a enviar eventos pendientes, incluyendo `load_design`
- El evento `load_design` revertía el canvas al último estado guardado

**Solución:**
- Modificado `auto_hide_flash.js` para solo remover el elemento DOM, sin enviar eventos a LiveView

**Archivos:**
- `assets/js/hooks/auto_hide_flash.js`

#### 3. Tiempo de Respuesta de Guardado Mejorado

**Problema:** Los guardados se sentían lentos/retrasados.

**Solución:**
- Reducido `SAVE_DEBOUNCE_MS` de 300ms a 100ms en `canvas_designer.js`
- Reducido TTL del caché de 5 minutos a 30 segundos en `designs.ex`

**Archivos:**
- `assets/js/hooks/canvas_designer.js`
- `lib/qr_label_system/designs.ex`

#### 4. Auto-Selección en Input de Contenido de Texto

**Funcionalidad:** Al hacer clic en el campo "Contenido del texto" ahora se selecciona todo el texto automáticamente para fácil reemplazo.

**Solución:**
- Añadido `onfocus="this.select()"` al input de contenido de texto

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`

#### 5. Hook AutoUploadSubmit Creado

**Funcionalidad:** Nuevo hook que automáticamente envía el formulario de subida cuando la carga de archivo llega al 100%.

**Archivos:**
- `assets/js/hooks/auto_upload_submit.js`

#### 6. Limpieza de Logs de Debug

- Removidos console.log/console.warn verbosos de archivos JavaScript
- Removidos logs de debug de archivos Elixir
- Solo se mantienen mensajes de error esenciales

**Archivos:**
- `assets/js/hooks/canvas_designer.js`
- `assets/js/hooks/auto_hide_flash.js`
- `assets/js/hooks/auto_upload_submit.js`
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `lib/qr_label_system/designs.ex`
- `lib/qr_label_system/designs/design.ex`

---

## Detalles Técnicos Clave

### Arquitectura de Persistencia del Canvas

El editor de canvas usa Fabric.js para renderizado y LiveView para gestión de estado. Puntos clave:

1. **Schema Embebido con `on_replace: :delete`**: Los elementos se almacenan como schemas embebidos. La opción `on_replace: :delete` significa que los elementos no incluidos en una actualización serán eliminados. El cliente debe SIEMPRE enviar TODOS los elementos en cada guardado.

2. **Flujo de Guardado:**
   ```
   Usuario modifica elemento → saveElements() [debounce 100ms] → pushEvent("element_modified", {elements}) → LiveView actualiza DB → (respuesta ignorada)
   ```

3. **Flujo de Carga (solo inicial):**
   ```
   evento canvas_ready → LiveView verifica flag canvas_loaded → push_event("load_design") → JS carga elementos
   ```

4. **Protección Contra Condiciones de Carrera:**
   - Flag `canvas_loaded` en LiveView previene múltiples eventos `load_design`
   - `_lastSaveTime` en JS ignora `load_design` si llega dentro de 1 segundo de un guardado
   - Flag `_isInitialLoad` asegura que `load_design` solo funcione en el primer montaje

---

## Sesión Anterior (31 enero 2026) - Parte 4

### Lo Que Se Implementó

#### 1. Migración de Sidebar a Header Horizontal

**Cambio:** Reemplazada la barra lateral izquierda (256px) por un header horizontal para maximizar el espacio de contenido.

**Estructura:**
```
┌──────────────────────────────────────────────────────────────────────┐
│ [Logo] QR Label System     [+ Generar]  [Diseños]        [User ▼]   │
└──────────────────────────────────────────────────────────────────────┘
```

**Archivos:** `lib/qr_label_system_web/components/layouts/app.html.heex`

#### 2. Sistema de Backup/Restore de Diseños

**Funcionalidad:**
- Botón "Exportar todo" - descarga JSON con todos los diseños del usuario
- Botón "Importar" - carga archivo JSON de backup
- Eliminado el botón de exportar individual de cada diseño

**Archivos:**
- `lib/qr_label_system/designs.ex` - funciones `export_all_designs_to_json/1` e `import_designs_from_json/2`
- `lib/qr_label_system_web/live/design_live/index.ex` - UI y eventos

#### 3. Mejoras en Lista de Diseños (/designs)

- Botones más grandes (w-10 h-10)
- Botón "Vista previa" añadido
- Redirección de "Nuevo Diseño" a `/generate`
- Layout de `/designs/new` actualizado para coincidir con el flujo de generación

#### 4. Mensajes Flash Mejorados

**Cambios:**
- Posición centrada en la pantalla a la altura del toolbar
- Texto más grande y en negrita
- Auto-hide después de 3 segundos con fade-out
- Hook `AutoHideFlash` en `assets/js/hooks/auto_hide_flash.js`

**Archivos:** `lib/qr_label_system_web/components/core_components.ex`

#### 5. Fix: Actualización de Propiedades de Elementos

**Problema:** Al cambiar propiedades en el panel (ej. contenido de texto), no se actualizaba el canvas.

**Causa:** El canvas perdía la selección cuando el usuario hacía clic en los inputs del panel de propiedades.

**Solución:**
1. El servidor ahora envía el ID del elemento junto con el evento `update_element_property`
2. El canvas busca el elemento por ID en lugar de depender de `getActiveObject()`
3. Input de "Contenido" envuelto en form para que `phx-change` funcione correctamente

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `assets/js/hooks/canvas_designer.js` - función `updateElementById()`

#### 6. Fix: Redimensionamiento de Texto

**Problema:** Al redimensionar un texto en el canvas y hacer clic en otro lugar, volvía al tamaño anterior.

**Causa:** Para textboxes, Fabric.js modifica `width` directamente (no usa scale), pero el código guardaba el ancho viejo de `elementData`.

**Solución:** Caso específico en `saveElementsImmediate()` que lee dimensiones actuales del objeto textbox.

---

## Arquitectura Actual

### Flujo de Actualización de Propiedades

```
[Panel de Propiedades]
    ↓ phx-change="update_element" (field, value)
[Servidor Phoenix]
    ↓ push_event("update_element_property", {id, field, value})
[Hook CanvasDesigner]
    ↓ updateElementById(id, field, value)
[Fabric.js Object]
    ↓ obj.set(property, value)
[Canvas Render]
```

### Archivos Clave

| Archivo | Descripción |
|---------|-------------|
| `components/layouts/app.html.heex` | Layout con header horizontal |
| `assets/js/hooks/canvas_designer.js` | Editor de canvas con Fabric.js |
| `assets/js/hooks/auto_hide_flash.js` | Auto-hide para mensajes flash |
| `assets/js/hooks/auto_upload_submit.js` | Auto-submit para uploads |
| `lib/qr_label_system/designs.ex` | Contexto con backup/restore |
| `lib/qr_label_system/designs/design.ex` | Schema Ecto para diseños |
| `lib/qr_label_system_web/live/design_live/editor.ex` | LiveView del editor |
| `lib/qr_label_system_web/live/design_live/index.ex` | Lista de diseños |

---

## Pendiente / Para Continuar

### Alta Prioridad

1. **Generación de PDF desde Editor** ⬅️ PRÓXIMO PASO PRINCIPAL
   - Implementar botón "Generar X etiquetas" que genera PDF
   - Usar los datos de `UploadDataStore`
   - Aplicar bindings de columnas a elementos

2. **Preview Multi-Etiqueta**
   - Mostrar cómo se verá cada etiqueta con datos reales

### Media Prioridad

3. **Mejoras en Preview del Editor** (QR/barcode reales en lugar de placeholders)
4. **Configuración de Impresión** (tamaño de página, márgenes, etiquetas por página)

### Baja Prioridad

5. **Limpieza de Código** (referencias a batches obsoletas)
6. **Drag and Drop** (hook DraggableElements no monta - click funciona como alternativa)

---

## Comandos Útiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Tests
mix test

# Consola interactiva
iex -S mix
```

---

## Bugs Conocidos y Soluciones

### Propiedades no se actualizan en canvas

**Síntoma:** Cambiar valores en el panel de propiedades no afecta el canvas.
**Solución:** Verificar que el input esté dentro de un `<form>` con `phx-change`.

### Textbox vuelve a tamaño original

**Síntoma:** Al redimensionar texto y hacer clic fuera, vuelve al tamaño anterior.
**Solución:** Ya arreglado - el código ahora lee dimensiones actuales del textbox.

### Imagen aparece y desaparece

**Síntoma:** Al subir imagen, aparece brevemente y luego desaparece.
**Solución:** Ya arreglado - protección contra eventos `load_design` que llegan después de guardado.

### Hook DraggableElements no monta

**Síntoma:** El módulo carga pero `mounted()` no se ejecuta.
**Estado:** En investigación. Click funciona como alternativa.

---

*Handoff actualizado: 31 enero 2026 (sesión 5)*
