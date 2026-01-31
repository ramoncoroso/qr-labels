# Handoff: Sistema de Generación de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con códigos QR, códigos de barras y texto dinámico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesión Actual (31 enero 2026) - Parte 4

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

#### 5. Traducciones a Español

- "Preview" → "Vista previa" en el editor

#### 6. Fix: Actualización de Propiedades de Elementos

**Problema:** Al cambiar propiedades en el panel (ej. contenido de texto), no se actualizaba el canvas.

**Causa:** El canvas perdía la selección cuando el usuario hacía clic en los inputs del panel de propiedades.

**Solución:**
1. El servidor ahora envía el ID del elemento junto con el evento `update_element_property`
2. El canvas busca el elemento por ID en lugar de depender de `getActiveObject()`
3. Input de "Contenido" envuelto en form para que `phx-change` funcione correctamente

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `assets/js/hooks/canvas_designer.js` - función `updateElementById()`

#### 7. Fix: Redimensionamiento de Texto

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
| `lib/qr_label_system/designs.ex` | Contexto con backup/restore |
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

### Hook DraggableElements no monta

**Síntoma:** El módulo carga pero `mounted()` no se ejecuta.
**Estado:** En investigación. Click funciona como alternativa.

---

*Handoff actualizado: 31 enero 2026 (sesión 4)*
