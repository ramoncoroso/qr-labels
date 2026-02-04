# Tareas Pendientes

## Configurar carga automática de .env

**Estado**: ✅ Completado

**Solución implementada**:
Instalado `dotenvy` para cargar automáticamente archivos `.env` en dev/test.

Archivos soportados (en orden de prioridad):
- `.env`
- `.env.dev` / `.env.test`
- `.env.dev.local` / `.env.test.local`

**Archivos modificados**:
- `mix.exs` - agregada dependencia `dotenvy`
- `config/runtime.exs` - carga automática de .env

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

**Estado**: ✅ Completado
**Riesgo**: Medio
**Esfuerzo**: Bajo

**Solución implementada**:
1. Añadida función `FileSanitizer.validate_image_content/1` que valida magic bytes
2. Añadida función `FileSanitizer.detect_mime_type_from_file/1` para detección de MIME type
3. Modificado handler de upload en `editor.ex` para usar validación de magic bytes
4. El MIME type ahora se detecta del contenido real, no del `client_type` enviado por el cliente
5. Solo se permiten imágenes PNG, JPEG y GIF (SVG bloqueado por riesgo XSS)
6. 43 tests verifican la funcionalidad

**Archivos modificados**:
- `lib/qr_label_system/security/file_sanitizer.ex` - nuevas funciones de validación
- `lib/qr_label_system_web/live/design_live/editor.ex` - usa validación de magic bytes
- `test/qr_label_system/security/file_sanitizer_test.exs` - tests para nuevas funciones

## [SEGURIDAD] Reducir información en endpoints de health (producción)

**Estado**: ✅ Completado
**Riesgo**: Bajo-Medio
**Esfuerzo**: Bajo

**Solución implementada**:
1. En producción, `/api/health/detailed` omite: `uptime_seconds`, `version`, `elixir_version`, `otp_version`
2. En producción, `/api/metrics` omite: `uptime_seconds`, métricas detalladas de memoria
3. Se agregó configuración `config :qr_label_system, env: :prod|:dev|:test` para detectar entorno

**Archivos modificados**:
- `lib/qr_label_system_web/controllers/api/health_controller.ex`
- `config/runtime.exs` - agregado `env: :prod`
- `config/test.exs` - agregado `env: :test`

## [SEGURIDAD] Mejorar validación SQL (reemplazar regex)

**Estado**: ✅ Completado
**Riesgo**: Alto
**Esfuerzo**: Alto

**Solución implementada**:
La validación SQL fue mejorada significativamente con:
1. **Normalización Unicode** - Previene bypass con caracteres fullwidth (ＤＥＬＥＴＥ → DELETE)
2. **Patrones específicos por BD**:
   - PostgreSQL: `pg_read_file`, `pg_ls_dir`, `lo_import`, `lo_export`, `COPY`, `dblink`
   - MySQL: `LOAD DATA`, `UNHEX`, `CONV`
   - SQL Server: `OPENROWSET`, `OPENDATASOURCE`, `BULK INSERT`, `sys.tables`
3. **Bloqueo de SELECT INTO** - Previene creación de tablas
4. **Bloqueo de CTEs (WITH)** - Previene wrapping de operaciones maliciosas
5. **86 tests de seguridad** verifican la validación

**Archivos modificados**:
- `lib/qr_label_system/data_sources/db_connector.ex`
- `test/qr_label_system/data_sources/db_connector_test.exs`

## [SEGURIDAD] Configurar usuario BD read-only para data sources externos

**Estado**: ✅ Completado
**Riesgo**: Medio
**Esfuerzo**: Bajo

**Solución implementada**:
Se agregó nota de seguridad visible en el formulario de conexión a BD externa que recomienda usar usuario con permisos de solo lectura (SELECT).

**Archivos modificados**:
- `lib/qr_label_system_web/live/data_source_live/form_component.ex` - banner de advertencia en UI

## [SEGURIDAD] Eliminar credenciales hardcodeadas de documentación

**Estado**: ✅ Completado
**Riesgo**: Medio
**Esfuerzo**: Bajo

**Solución implementada**:
Reemplazadas credenciales explícitas por instrucción de ejecutar seeds.
Las credenciales ahora están solo en `priv/repo/seeds.exs` (no en documentación pública).

**Archivos modificados**:
- `README.md` - removidas credenciales, agregada instrucción de seeds
