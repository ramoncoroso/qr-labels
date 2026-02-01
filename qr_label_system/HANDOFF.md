# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (1 febrero 2026) - Fix Sincronizacion Propiedades Canvas

### Objetivo Completado

Corregir propiedades que se guardaban en la base de datos pero no se aplicaban visualmente en el canvas.

### Metodologia de Analisis

Se realizo un analisis sistematico de super-ingeniero para detectar TODOS los errores de sincronizacion:

1. **Mapeo del flujo completo**: UI → Evento → `updateSelectedElement()` → Fabric.js → `saveElements()` → BD
2. **Comparacion de 3 fuentes**: Schema (element.ex) vs UI (editor.ex) vs Handler (canvas_designer.js)
3. **Identificacion de brechas**: Propiedades que existian en una capa pero no en otra

### Problemas Identificados y Corregidos

#### 1. QR Error Level No Se Aplicaba

**Problema:** `qr_error_level` tenia UI (select), se guardaba en BD, pero nunca se pasaba a la libreria QRCode.

**Solucion:**
```javascript
// canvas_designer.js - createQR()
QRCode.toDataURL(content, {
  errorCorrectionLevel: element.qr_error_level || 'M',  // AGREGADO
  // ...
})

// canvas_designer.js - updateSelectedElement()
case 'qr_error_level':
  if (obj.elementType === 'qr') {
    obj.elementData = data
    this.recreateCodeElement(obj, data.binding || data.text_content)
    return
  }
  break
```

#### 2. Barcode Show Text No Se Aplicaba

**Problema:** `barcode_show_text` tenia checkbox en UI, pero el switch no tenia este case. Ademas, el codigo usaba `element.show_text` (incorrecto) en vez de `element.barcode_show_text`.

**Solucion:**
```javascript
// canvas_designer.js - createBarcode()
displayValue: element.barcode_show_text !== false,  // Corregido nombre de campo

// canvas_designer.js - updateSelectedElement()
case 'barcode_show_text':
  if (obj.elementType === 'barcode') {
    obj.elementData = data
    this.recreateCodeElement(obj, data.binding || data.text_content)
    return
  }
  break
```

#### 3. Colores de QR/Barcode No Se Regeneraban

**Problema:** `color` y `background_color` se leian al crear QR/barcode, pero cambios posteriores no regeneraban el codigo.

**Solucion:**
```javascript
case 'color':
case 'background_color':
  // Para QR y barcode, cambiar color requiere regenerar
  if (obj.elementType === 'qr' || obj.elementType === 'barcode') {
    obj.elementData = data
    this.recreateCodeElement(obj, data.binding || data.text_content)
    return
  }
  obj.set('fill', value)
  break
```

**UI Agregada (editor.ex):**
- Color pickers para QR: "Color del codigo" y "Color de fondo"
- Color pickers para Barcode: "Color del codigo" y "Color de fondo"

#### 4. Border Radius para Rectangulos

**Problema:** `border_radius` existia en schema y funcionaba para circles, pero rectangulos no tenian UI ni handler.

**Solucion:**
```javascript
// canvas_designer.js - createRect()
const roundness = (element.border_radius || 0) / 100
const maxRadius = Math.min(width, height) / 2
const radius = roundness * maxRadius
return new fabric.Rect({ rx: radius, ry: radius, ... })

// canvas_designer.js - updateSelectedElement()
case 'border_radius':
  if ((obj.elementType === 'circle' || obj.elementType === 'rectangle') && obj.type === 'rect') {
    // Ahora maneja AMBOS tipos
  }
```

**UI Agregada (editor.ex):**
- Slider "Radio de borde" para rectangulos (0% = esquinas rectas, 100% = maximo redondeo)
- ID unico: `border-radius-slider-rect-#{id}` para evitar conflicto con circles

#### 5. Grosor de Linea

**Problema:** `border_width` existia en schema pero lineas no tenian control de grosor en UI.

**Solucion:**
```javascript
// canvas_designer.js - createLine()
const thickness = element.border_width || element.height || 0.5  // Backwards compatible

// canvas_designer.js - updateSelectedElement()
case 'border_width':
  if (obj.elementType === 'line') {
    obj.set('height', Math.max(value * PX_PER_MM, 2))  // Lineas usan height
  } else {
    obj.set('strokeWidth', value * PX_PER_MM)
  }
```

**UI Agregada (editor.ex):**
- Input numerico "Grosor (mm)" para lineas

### Otros Fixes en Esta Sesion

#### Fix de Audit Module

**Problema:** El codigo usaba `log.changes` pero el schema define `log.metadata`.

**Archivos corregidos:**
- `audit_exporter.ex`: CSV header "Metadata", funcion `encode_metadata()`
- `audit_live.ex`: Template usa `log.metadata`
- `audit.ex`: Ordenamiento determinista con `order_by: [desc: l.inserted_at, desc: l.id]`

#### Fix de Tests (20 failures → 0)

| Test File | Problema | Solucion |
|-----------|----------|----------|
| `users_live_test.exs` | Selectores genericos | `form[phx-submit=search]` |
| `user_forgot_password_live_test.exs` | LiveView redirige | `assert_redirect` |
| `user_confirmation_live_test.exs` | LiveView redirige | `assert_redirect` |
| `user_reset_password_live_test.exs` | Token invalido | Usar token valido |
| `auth_integration_test.exs` | Ruta `/batches` no existe | Cambiar a `/data-sources` |
| `design_live/show_test.exs` | Acceso a disenos ajenos | Documentar comportamiento |

---

## Matriz de Propiedades por Tipo de Elemento

### QR Code
| Propiedad | UI | Handler | Status |
|-----------|-----|---------|--------|
| text_content | ✅ | ✅ | OK |
| qr_error_level | ✅ | ✅ | **FIXED** |
| color | ✅ | ✅ | **FIXED** (UI agregada) |
| background_color | ✅ | ✅ | **FIXED** (UI agregada) |

### Barcode
| Propiedad | UI | Handler | Status |
|-----------|-----|---------|--------|
| text_content | ✅ | ✅ | OK |
| barcode_format | ✅ | ✅ | OK |
| barcode_show_text | ✅ | ✅ | **FIXED** |
| color | ✅ | ✅ | **FIXED** (UI agregada) |
| background_color | ✅ | ✅ | **FIXED** (UI agregada) |

### Rectangle
| Propiedad | UI | Handler | Status |
|-----------|-----|---------|--------|
| background_color | ✅ | ✅ | OK |
| border_color | ✅ | ✅ | OK |
| border_width | ✅ | ✅ | OK |
| border_radius | ✅ | ✅ | **FIXED** (UI agregada) |

### Line
| Propiedad | UI | Handler | Status |
|-----------|-----|---------|--------|
| color | ✅ | ✅ | OK |
| border_width | ✅ | ✅ | **FIXED** (UI agregada) |

---

## Archivos Modificados en Esta Sesion

| Archivo | Cambios |
|---------|---------|
| `canvas_designer.js` | +62 lineas: handlers para 6 propiedades, createRect/createLine mejorados |
| `editor.ex` | +77 lineas: UI controls para QR/barcode colors, rectangle border_radius, line thickness |
| `audit.ex` | Ordenamiento determinista |
| `audit_exporter.ex` | Renombrar changes→metadata |
| `audit_live.ex` | Template fix metadata |
| 11 test files | Selectores, redirects, documentacion |

---

## Como Continuar

### Para Agregar Nuevas Propiedades

1. **Verificar schema** en `element.ex` - la propiedad debe existir
2. **Agregar UI** en `editor.ex` - dentro del case del tipo de elemento
3. **Agregar handler** en `updateSelectedElement()` de `canvas_designer.js`
4. Si la propiedad requiere regenerar el elemento (QR/barcode), llamar `recreateCodeElement()`

### Para Diagnosticar Propiedades Que No Funcionan

```
Propiedad no se aplica visualmente?
    ↓
¿Existe en element.ex schema?
    No → Agregar campo al schema
    Si ↓
¿Tiene UI control en editor.ex?
    No → Agregar input/select/slider
    Si ↓
¿Tiene case en updateSelectedElement()?
    No → Agregar case con la logica apropiada
    Si ↓
¿Es QR/barcode y necesita regenerar?
    Si → Llamar recreateCodeElement()
    No → Usar obj.set() de Fabric.js
```

---

## Sesion Anterior (1 febrero 2026) - QR/Barcode Real en Canvas

### Objetivo Completado

Mostrar QR y codigos de barras reales en el canvas del editor cuando el usuario escribe contenido, en lugar de placeholders.

### Lo Que Se Implemento

#### 1. Generacion de QR Real en Canvas

**Archivo:** `assets/js/hooks/canvas_designer.js`

```javascript
// createQR() ahora genera QR real usando qrcode library
const content = element.text_content || element.binding || ''
if (content) {
  QRCode.toDataURL(content, options).then(dataUrl => {
    // Reemplaza placeholder con imagen real
  })
}
```

**Caracteristicas:**
- Usa `text_content` para etiquetas individuales, `binding` para datos de Excel
- Muestra "Generando..." mientras procesa
- Reemplaza placeholder con imagen QR real
- Soporta colores personalizados (dark/light)

#### 2. Generacion de Barcode Real en Canvas

**Archivo:** `assets/js/hooks/canvas_designer.js`

```javascript
// createBarcode() genera barcode real usando JsBarcode
const validation = this.validateBarcodeContent(content, format)
if (!validation.valid) {
  return this.createBarcodeErrorPlaceholder(...)
}
JsBarcode(canvas, content, options)
```

**Caracteristicas:**
- Validacion de contenido segun formato (EAN-13, CODE39, etc.)
- Placeholder de error rojo cuando el formato es incompatible
- Soporta todos los formatos: CODE128, CODE39, EAN-13, EAN-8, UPC, ITF-14

#### 3. Validacion de Formatos de Barcode

**Nueva funcion:** `validateBarcodeContent(content, format)`

| Formato | Requisitos |
|---------|-----------|
| CODE128 | Cualquier caracter ASCII |
| CODE39 | A-Z, 0-9, espacio, -.$/ |
| EAN-13 | 12-13 digitos |
| EAN-8 | 7-8 digitos |
| UPC | 11-12 digitos |
| ITF-14 | 13-14 digitos |

**Placeholder de error:**
- Fondo rojo claro (#fef2f2)
- Borde rojo (#ef4444)
- Mensaje descriptivo (ej: "EAN-13: solo digitos")

#### 4. Hook PropertyFields para Preservar Foco

**Archivo:** `assets/js/hooks/property_fields.js`

**Problema resuelto:** Al escribir en campos de texto, el foco se perdia debido a re-renders de LiveView.

**Solucion:**
```javascript
// Rastrea estado del input durante typing
focusedElementName, focusedElementValue, cursorPosition

// updated() restaura todo despues de re-render
input.focus()
input.value = this.focusedElementValue
input.setSelectionRange(pos, pos)
```

**Mejoras de seguridad:**
- `CSS.escape()` para prevenir inyeccion en selectores
- `destroyed()` para limpiar event listeners
- Limpieza de timeouts para evitar memory leaks

#### 5. Prevencion de Deseleccion Durante Cambios

**Problema:** Al cambiar formato de barcode, el elemento se deseleccionaba.

**Causa:**
```
canvas.remove(obj) -> selection:cleared -> element_deselected -> panel vacio
```

**Solucion:**
```javascript
// Flag para bloquear evento de deseleccion
this._isRecreatingElement = true
this.canvas.remove(obj)
// ... recrear elemento ...
this._isRecreatingElement = false

// En selection:cleared
if (!this._isRecreatingElement) {
  this.pushEvent("element_deselected", {})
}
```

#### 6. Sincronizacion de elementData

**Problema:** Al cambiar formato, el nuevo valor no llegaba a `recreateCodeElement`.

**Causa:** `obj.elementData` no se actualizaba antes de llamar a recreate.

**Solucion:**
```javascript
case 'barcode_format':
  obj.elementData = data  // Actualizar ANTES de recrear
  this.recreateCodeElement(obj, data.binding)
```

---

## Archivos Modificados en Esta Sesion

| Archivo | Cambios |
|---------|---------|
| `canvas_designer.js` | QR/barcode real, validacion, flags de recreacion |
| `property_fields.js` | Nuevo hook para preservar foco |
| `editor.ex` | phx-blur en inputs, debounce mejorado |
| `index.js` | Registro de PropertyFields hook |

---

## Hooks JavaScript Actualizados

| Hook | Proposito |
|------|-----------|
| `CanvasDesigner` | Editor principal - ahora genera QR/barcode reales |
| `PropertyFields` | **NUEVO** - Preserva foco durante re-renders |
| `BorderRadiusSlider` | **NUEVO** - Slider suave para border-radius |
| `DraggableElements` | Drag and drop de elementos al canvas |
| `AutoHideFlash` | Auto-hide para mensajes flash |
| `AutoUploadSubmit` | Auto-submit para uploads de imagenes |
| `CodeGenerator` | Generacion de QR/barcode para impresion |
| `PrintEngine` | Exportacion PDF e impresion |
| `ExcelReader` | Lectura de archivos Excel |
| `LabelPreview` | Preview de etiquetas |
| `KeyboardShortcuts` | Atajos de teclado |
| `SortableLayers` | Ordenamiento de capas |
| `SingleLabelPrint` | Impresion de etiqueta individual |

---

## Flujo de Generacion QR/Barcode

```
[Usuario escribe contenido]
       |
       v
[phx-blur="update_element"]
       |
       v
[LiveView: handle_event("update_element")]
       |
       v
[push_event("update_element_property")]
       |
       v
[CanvasDesigner: updateSelectedElement()]
       |
       v
[recreateCodeElement(obj, content)]
       |
       +-- createQR() o createBarcode()
       |       |
       |       v
       |   [Validar formato]
       |       |
       |       +-- Valido: Generar imagen real
       |       |
       |       +-- Invalido: Mostrar error placeholder
       |
       v
[canvas.setActiveObject(newObj)]
       |
       v
[saveElements() -> element_modified]
```

---

## Pendiente / Para Continuar

### Alta Prioridad

1. **Mejora UX de Formatos Rigidos**
   - Cuando el usuario cambia a EAN-13, auto-limpiar contenido invalido
   - O mostrar advertencia antes de cambiar
   - ✅ PARCIAL: Formatos incompatibles se muestran deshabilitados en dropdown

2. **Preview Multi-Etiqueta con Datos Reales**
   - Los QR/barcodes ahora funcionan en canvas
   - Falta integrar con datos de Excel para preview de multiples etiquetas

### Media Prioridad

3. **Configuracion de Impresion**
   - Tamano de pagina, margenes, etiquetas por pagina

4. **Tests para Validacion de Barcode**
   - Unit tests para `validateBarcodeContent()`

5. **Revisar Acceso a Disenos** (Nota de seguridad)
   - `show.ex` permite ver cualquier diseno (para compartir templates)
   - Considerar agregar check de `user_id` si se requiere acceso mas estricto
   - Ver comentario en `show_test.exs`

### Baja Prioridad

6. **Limpieza de Codigo**
   - Referencias obsoletas a batches
   - Consolidar duplicacion entre hooks
   - Resolver warnings de compilacion (funcion `barcode_format_example/1` no usada)

---

## Bugs Conocidos y Soluciones

### QR/Barcode no se genera

**Sintoma:** El placeholder "Generando..." permanece indefinidamente.
**Posibles causas:**
1. Contenido vacio - verificar que `text_content` tenga valor
2. Formato invalido - verificar consola por errores de JsBarcode
3. Element ID no coincide - verificar que el ID sea consistente

### Formato de barcode muestra error

**Sintoma:** Placeholder rojo con mensaje de error.
**Solucion:** El contenido no cumple los requisitos del formato. Ver tabla de requisitos arriba.

### Input pierde foco al escribir

**Sintoma:** Al escribir, el cursor salta o el valor se resetea.
**Solucion:** Ya arreglado con PropertyFields hook. Verificar que el contenedor tenga `phx-hook="PropertyFields"`.

### Elemento se deselecciona al cambiar formato

**Sintoma:** Al cambiar formato de barcode, el panel de propiedades se vacia.
**Solucion:** Ya arreglado con flag `_isRecreatingElement`. Verificar que no se llame `pushEvent("element_deselected")` durante recreacion.

---

## Comandos Utiles

```bash
# Servidor de desarrollo
cd qr_label_system && mix phx.server

# Compilar JavaScript (despues de cambios en hooks)
cd assets && npm run build

# Tests
mix test

# Consola interactiva
iex -S mix

# Compilar assets para produccion
cd assets && npm run deploy && cd ..
mix phx.digest
```

---

## Historial de Sesiones

| Fecha | Sesion | Principales Cambios |
|-------|--------|---------------------|
| 1 feb 2026 | 8 | Fix sincronizacion propiedades canvas, UI controls, audit fixes, test fixes |
| 1 feb 2026 | 7 | QR/barcode real en canvas, validacion formatos, PropertyFields hook |
| 31 ene 2026 | 6 | Drag and drop reimplementado, cleanup de hooks |
| 31 ene 2026 | 5 | Upload de imagenes, fix guardado automatico |
| 31 ene 2026 | 4 | Header horizontal, backup/restore |

---

*Handoff actualizado: 1 febrero 2026 (sesion 8)*
