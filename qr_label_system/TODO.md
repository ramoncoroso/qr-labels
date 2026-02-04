# Tareas Pendientes

## Configurar carga automática de .env

**Estado**: Pendiente

El archivo `.env` fue creado con el nuevo `SECRET_KEY_BASE`, pero el proyecto no tiene una librería para cargarlo automáticamente.

**Opciones**:

1. **Manual** - Ejecutar `source .env && mix phx.server` cada vez
2. **Automático** - Instalar `dotenvy` (recomendado):
   ```elixir
   # En mix.exs, agregar a deps:
   {:dotenvy, "~> 0.8"}
   ```
   Luego en `config/runtime.exs`:
   ```elixir
   if config_env() == :dev do
     Dotenvy.source([".env", ".env.#{config_env()}.local"])
   end
   ```

## Alinear elementos en toolbar

**Estado**: Pendiente (feature anterior)

**Ubicación**: Al lado del control de zoom en la barra de herramientas del editor

**Funcionalidad**:
- Añadir botón/opción "Alinear" junto al zoom
- Si no hay múltiples elementos seleccionados: mostrar mensaje "Seleccionar elementos a alinear"
- Si hay 2+ elementos seleccionados: mostrar opciones de alineación (izquierda, centro, derecha, arriba, medio, abajo)

**Archivos a modificar**:
- `lib/qr_label_system_web/live/design_live/editor.ex` - añadir botón en toolbar
- `assets/js/hooks/canvas_designer.js` - ya tiene funciones `alignElements()` implementadas
