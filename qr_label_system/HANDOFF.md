# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (1 febrero 2026) - QR/Barcode Real en Canvas

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
   - Considerar: deshabilitar formatos incompatibles en dropdown

2. **Preview Multi-Etiqueta con Datos Reales**
   - Los QR/barcodes ahora funcionan en canvas
   - Falta integrar con datos de Excel para preview de multiples etiquetas

### Media Prioridad

3. **Configuracion de Impresion**
   - Tamano de pagina, margenes, etiquetas por pagina

4. **Tests para Validacion de Barcode**
   - Unit tests para `validateBarcodeContent()`

### Baja Prioridad

5. **Limpieza de Codigo**
   - Referencias obsoletas a batches
   - Consolidar duplicacion entre hooks

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
| 1 feb 2026 | 7 | QR/barcode real en canvas, validacion formatos, PropertyFields hook |
| 31 ene 2026 | 6 | Drag and drop reimplementado, cleanup de hooks |
| 31 ene 2026 | 5 | Upload de imagenes, fix guardado automatico |
| 31 ene 2026 | 4 | Header horizontal, backup/restore |

---

*Handoff actualizado: 1 febrero 2026 (sesion 7)*
