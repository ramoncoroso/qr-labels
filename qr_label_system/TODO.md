# Tareas Pendientes

## Alinear elementos en toolbar

**Ubicación**: Al lado del control de zoom en la barra de herramientas del editor

**Funcionalidad**:
- Añadir botón/opción "Alinear" junto al zoom
- Si no hay múltiples elementos seleccionados: mostrar mensaje "Seleccionar elementos a alinear"
- Si hay 2+ elementos seleccionados: mostrar opciones de alineación (izquierda, centro, derecha, arriba, medio, abajo)

**Archivos a modificar**:
- `lib/qr_label_system_web/live/design_live/editor.ex` - añadir botón en toolbar
- `assets/js/hooks/canvas_designer.js` - ya tiene funciones `alignElements()` implementadas

