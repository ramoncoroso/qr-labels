# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (31 enero 2026) - Parte 6

### Lo Que Se Implemento

#### 1. Fix: Drag and Drop de Elementos al Canvas

**Problema:** El drag and drop desde la barra de herramientas al canvas no funcionaba. Al arrastrar un elemento, se comportaba igual que un click (se anadia en posicion por defecto).

**Causa Raiz:**
- El drag nativo del navegador (HTML5 Drag and Drop API) no funcionaba correctamente
- Los eventos `dragstart` no se disparaban de forma consistente
- Habia conflictos entre los eventos de click y drag

**Solucion:**
Reimplementacion completa del sistema de drag usando eventos de mouse manuales:

```javascript
// Enfoque manual (mas confiable que drag nativo)
mousedown -> mousemove -> mouseup

// Click: si el movimiento es < 5px
// Drag: si el movimiento es >= 5px, muestra ghost y permite soltar en canvas
```

**Caracteristicas:**
- Umbral de 5px para distinguir click de drag
- Ghost visual (etiqueta azul) que sigue el cursor durante drag
- Resaltado del canvas cuando el cursor pasa sobre el
- Evento custom `element-drop` para comunicacion entre hooks
- Click simple sigue funcionando (aniade en posicion por defecto)

**Archivos:**
- `assets/js/hooks/draggable_elements.js` - Reescrito completamente
- `assets/js/hooks/canvas_designer.js` - Actualizado `setupDragAndDrop()`
- `lib/qr_label_system_web/live/design_live/editor.ex` - Removido `phx-click` de botones

#### 2. Refactor: Mejoras de Calidad de Codigo

**Problemas corregidos:**
- **Memory leak**: Los event listeners de `mousedown` nunca se limpiaban
- **Rendimiento**: `document.getElementById()` se llamaba en cada `mousemove`
- **Falta de cleanup**: El hook no tenia `destroyed()`

**Soluciones:**
- Anadido `destroyed()` que limpia todos los event listeners
- Cache del canvas container en `getCanvasContainer()`
- Uso de `classList.toggle()` para manipulacion de clases mas limpia
- Array `_cleanupFns` para rastrear funciones de limpieza

---

## Arquitectura del Drag and Drop

### Flujo de Comunicacion

```
[Boton Elemento]
    |
    v (mousedown)
[DraggableElements Hook]
    |
    +-- Click (< 5px movimiento)
    |       |
    |       v
    |   pushEvent('add_element', {type})
    |       |
    |       v
    |   [LiveView] -> posicion por defecto
    |
    +-- Drag (>= 5px movimiento)
            |
            v
        CustomEvent('element-drop', {type, x, y})
            |
            v
        [CanvasDesigner Hook]
            |
            v
        pushEvent('add_element_at', {type, x, y})
            |
            v
        [LiveView] -> posicion exacta del drop
```

### Validacion de Seguridad (Backend)

```elixir
@valid_element_types ~w(qr barcode text line rectangle image)

def handle_event("add_element", %{"type" => type}, socket)
    when type in @valid_element_types do
  # Solo tipos validos permitidos
end
```

---

## Sesiones Anteriores

### Sesion 5 (31 enero 2026)

- Fix: Subida de imagenes en el editor
- Fix: Cambios se revertian automaticamente
- Tiempo de respuesta de guardado mejorado
- Auto-seleccion en input de contenido de texto
- Hook AutoUploadSubmit creado
- Limpieza de logs de debug

### Sesion 4 (31 enero 2026)

- Migracion de sidebar a header horizontal
- Sistema de backup/restore de disenos
- Mejoras en lista de disenos
- Mensajes flash mejorados
- Fix: Actualizacion de propiedades de elementos
- Fix: Redimensionamiento de texto

---

## Detalles Tecnicos Clave

### Arquitectura de Persistencia del Canvas

1. **Schema Embebido con `on_replace: :delete`**: Los elementos se almacenan como schemas embebidos. El cliente debe SIEMPRE enviar TODOS los elementos en cada guardado.

2. **Flujo de Guardado:**
   ```
   Usuario modifica -> saveElements() [debounce 100ms] -> pushEvent("element_modified") -> DB
   ```

3. **Proteccion Contra Condiciones de Carrera:**
   - Flag `canvas_loaded` en LiveView previene multiples `load_design`
   - `_lastSaveTime` en JS ignora `load_design` si llega dentro de 1 segundo de un guardado

### Estructura de Hooks JavaScript

| Hook | Proposito |
|------|-----------|
| `CanvasDesigner` | Editor principal con Fabric.js |
| `DraggableElements` | Drag and drop de elementos al canvas |
| `AutoHideFlash` | Auto-hide para mensajes flash |
| `AutoUploadSubmit` | Auto-submit para uploads de imagenes |
| `CodeGenerator` | Generacion de QR/barcode |
| `PrintEngine` | Exportacion PDF e impresion |
| `ExcelReader` | Lectura de archivos Excel |
| `LabelPreview` | Preview de etiquetas |
| `KeyboardShortcuts` | Atajos de teclado |
| `SortableLayers` | Ordenamiento de capas |
| `SingleLabelPrint` | Impresion de etiqueta individual |

---

## Pendiente / Para Continuar

### Alta Prioridad

1. **Generacion de PDF desde Editor**
   - Implementar boton "Generar X etiquetas" que genera PDF
   - Usar los datos de `UploadDataStore`
   - Aplicar bindings de columnas a elementos

2. **Preview Multi-Etiqueta**
   - Mostrar como se vera cada etiqueta con datos reales

### Media Prioridad

3. **Mejoras en Preview del Editor** (QR/barcode reales en lugar de placeholders)
4. **Configuracion de Impresion** (tamano de pagina, margenes, etiquetas por pagina)

### Baja Prioridad

5. **Limpieza de Codigo** (referencias a batches obsoletas)
6. **Tests E2E** para flujos criticos

---

## Comandos Utiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Tests
mix test

# Consola interactiva
iex -S mix

# Compilar assets para produccion
cd assets && npm run deploy && cd ..
mix phx.digest
```

---

## Bugs Conocidos y Soluciones

### Propiedades no se actualizan en canvas

**Sintoma:** Cambiar valores en el panel de propiedades no afecta el canvas.
**Solucion:** Verificar que el input este dentro de un `<form>` con `phx-change`.

### Textbox vuelve a tamano original

**Sintoma:** Al redimensionar texto y hacer clic fuera, vuelve al tamano anterior.
**Solucion:** Ya arreglado - el codigo ahora lee dimensiones actuales del textbox.

### Imagen aparece y desaparece

**Sintoma:** Al subir imagen, aparece brevemente y luego desaparece.
**Solucion:** Ya arreglado - proteccion contra eventos `load_design` que llegan despues de guardado.

### Drag and drop no funciona

**Sintoma:** Arrastrar elementos tiene el mismo comportamiento que click.
**Solucion:** Ya arreglado - reimplementado con eventos de mouse manuales.

---

*Handoff actualizado: 31 enero 2026 (sesion 6)*
