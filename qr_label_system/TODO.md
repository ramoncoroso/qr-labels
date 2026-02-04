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

## Etiquetas múltiples sin conexión a Excel

**Estado**: Pendiente

**Funcionalidad**:
- Añadir botón/opción para crear etiquetas múltiples sin necesidad de conectar un archivo Excel
- Permitir al usuario especificar cantidad de etiquetas a generar
- Útil para etiquetas con datos estáticos o códigos secuenciales

---

# Mejoras de Seguridad

## [SEGURIDAD] Validar MIME type con magic bytes en uploads

**Estado**: Pendiente
**Riesgo**: Medio
**Esfuerzo**: Bajo

**Problema**:
El upload de imágenes en `editor.ex:616` confía en `entry.client_type` (controlado por el cliente). Un atacante podría enviar archivos polyglot con extensión válida pero contenido malicioso.

**Solución**:
Usar `FileSanitizer.validate_file_content/2` que ya existe pero no se usa en el flujo de upload de imágenes.

**Archivos a modificar**:
- `lib/qr_label_system_web/live/design_live/editor.ex` - agregar validación de magic bytes antes de procesar

## [SEGURIDAD] Reducir información en endpoints de health (producción)

**Estado**: Pendiente
**Riesgo**: Bajo-Medio
**Esfuerzo**: Bajo

**Problema**:
Los endpoints `/api/health/detailed` y `/api/metrics` (ahora protegidos por admin) aún exponen versiones de Elixir/OTP, uptime y memoria. Si credenciales admin se comprometen, facilita ataques dirigidos.

**Opciones**:
1. Reducir información en `config_env() == :prod`
2. Mover a red privada/observabilidad interna (Prometheus, Grafana)
3. Eliminar versiones y mantener solo métricas operacionales

**Archivos a modificar**:
- `lib/qr_label_system_web/controllers/api/health_controller.ex`

## [SEGURIDAD] Mejorar validación SQL (reemplazar regex)

**Estado**: Pendiente
**Riesgo**: Alto
**Esfuerzo**: Alto

**Problema**:
La validación SQL en `db_connector.ex:39-85` usa regex que puede ser evadida:
- `SELECT * INTO new_table` (no bloqueado)
- CTEs maliciosos: `WITH x AS (...) DELETE FROM users`
- Funciones peligrosas: `pg_read_file()`, `lo_import()`
- Unicode bypass: `ＤＥＬＥＴＥ`

**Opciones**:
1. **Parser SQL real** - Usar librería que parsee AST del SQL
2. **Vistas predefinidas** - Solo permitir queries a vistas creadas por el backend
3. **Usuario BD read-only** - Ejecutar con usuario que solo tenga SELECT en tablas específicas

**Recomendación**: Opción 2 o 3 son más seguras que mejorar el regex.

**Archivos a modificar**:
- `lib/qr_label_system/data_sources/db_connector.ex`

## [SEGURIDAD] Eliminar credenciales hardcodeadas de documentación

**Estado**: Pendiente
**Riesgo**: Medio
**Esfuerzo**: Bajo

**Problema**:
Los archivos README.md y HANDOFF.md contienen credenciales de desarrollo explícitas (`admin@example.com` / `admin123456`). Estas pueden:
- Copiarse accidentalmente a producción
- Usarse por atacantes que encuentren el repositorio
- Crear falsa sensación de seguridad

**Ubicación**:
- `README.md` líneas 202-203
- `qr_label_system/README.md` líneas 202-203
- `HANDOFF.md` líneas 333-334

**Solución**:
Reemplazar credenciales explícitas por instrucciones genéricas:
```markdown
# Crear usuario admin en desarrollo
mix run -e "QrLabelSystem.Accounts.create_admin_user()"
# O usar seeds: mix run priv/repo/seeds.exs
```

**Archivos a modificar**:
- `README.md`
- `qr_label_system/README.md`
- `HANDOFF.md`
