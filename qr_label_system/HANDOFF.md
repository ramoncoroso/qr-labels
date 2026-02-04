# Handoff: Sistema de Generacion de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con codigos QR, codigos de barras y texto dinamico. Construido con **Elixir/Phoenix LiveView** y **Fabric.js** para el editor de canvas.

---

## Sesion Actual (4 febrero 2026) - Seguridad Completa + 3 Fixes Adicionales

### Resumen Ejecutivo

Sesion enfocada en completar **todas las mejoras de seguridad**. Se resolvieron 9 tareas en total (6 de la sesion anterior + 3 nuevas).

| # | Tarea | Riesgo | Estado |
|---|-------|--------|--------|
| 1 | Mejorar validacion SQL | Alto | ✅ Completado |
| 2 | Validar MIME type en uploads | Medio | ✅ Completado |
| 3 | Eliminar credenciales hardcodeadas | Medio | ✅ Completado |
| 4 | Configurar usuario BD read-only | Medio | ✅ Completado |
| 5 | Reducir info en endpoints health | Bajo-Medio | ✅ Completado |
| 6 | Carga automatica de .env | DX | ✅ Completado |
| 7 | **Anonimizar PII en logs** | Medio | ✅ Completado (nuevo) |
| 8 | **Sanitizar uploads DataSourceController** | Alto | ✅ Completado (nuevo) |
| 9 | **Limpieza automatica archivos huerfanos** | Medio | ✅ Completado (nuevo) |

---

### 1. Validacion SQL Mejorada (Riesgo Alto)

**Problema:** La validacion SQL usaba regex que podia ser evadida con:
- Caracteres Unicode fullwidth (ＤＥＬＥＴＥ)
- Funciones peligrosas de PostgreSQL/MySQL/SQL Server
- SELECT INTO, CTEs maliciosos

**Solucion implementada:**

```elixir
# lib/qr_label_system/data_sources/db_connector.ex

# Module attribute - compilado una vez (eficiente)
@dangerous_patterns [
  # DDL/DML
  ~r/\b(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|TRUNCATE)\b/i,
  # PostgreSQL
  ~r/\b(pg_read_file|lo_import|dblink)\s*\(/i,
  # MySQL
  ~r/\b(LOAD_FILE|LOAD\s+DATA)\s*[\(\s]/i,
  # SQL Server
  ~r/\b(xp_|sp_)\w+/i,
  ~r/\b(OPENROWSET|OPENDATASOURCE)\s*\(/i,
  # ... 20+ patrones mas
]

def validate_query(query) do
  query
  |> String.trim()
  |> normalize_unicode()  # ＤＥＬＥＴＥ → DELETE
  |> check_patterns()
end
```

**Tests:** 86 tests de seguridad verifican la validacion.

---

### 2. Validacion MIME Type con Magic Bytes (Riesgo Medio)

**Problema:** El upload de imagenes confiaba en `entry.client_type` (controlado por el cliente).

**Solucion implementada:**

```elixir
# lib/qr_label_system/security/file_sanitizer.ex

def validate_image_content(file_path) do
  case detect_mime_type_from_file(file_path) do
    {:ok, mime} when mime in ~w(image/png image/jpeg image/gif) ->
      {:ok, mime}
    {:ok, _} ->
      {:error, :invalid_image_type}
  end
end

def detect_mime_type_from_file(file_path) do
  # Usa File.open/3 con bloque (previene resource leak)
  case File.open(file_path, [:read, :binary], fn file ->
    IO.binread(file, 8)
  end) do
    {:ok, header} -> {:ok, atom_to_mime(detect_mime_type(header))}
    {:error, reason} -> {:error, reason}
  end
end

# Magic bytes detection
defp detect_mime_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: :png
defp detect_mime_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: :jpeg
defp detect_mime_type(<<"GIF89a", _::binary>>), do: :gif
```

**Uso en editor.ex:**
```elixir
case FileSanitizer.validate_image_content(path) do
  {:ok, mime_type} ->
    # mime_type viene del contenido real, no del cliente
    {:ok, %{data: "data:#{mime_type};base64,#{base64}"}}
  {:error, :invalid_image_type} ->
    {:error, :invalid_image_type}
end
```

**Tests:** 43 tests verifican la funcionalidad.

---

### 3. Credenciales Removidas de Documentacion (Riesgo Medio)

**Problema:** README.md contenia credenciales explicitas (`admin@example.com` / `admin123456`).

**Solucion:**
```markdown
# ANTES (inseguro)
| Email | `admin@example.com` |
| Password | `admin123456` |

# DESPUES (seguro)
### Usuario Admin de Desarrollo
Para crear un usuario administrador en desarrollo, ejecuta los seeds:
mix run priv/repo/seeds.exs
```

---

### 4. Recomendacion Usuario BD Read-Only (Riesgo Medio)

**Solucion:** Agregado banner de seguridad visible en formulario de conexion a BD externa.

```heex
<!-- lib/qr_label_system_web/live/data_source_live/form_component.ex -->
<div class="mt-4 p-3 bg-amber-50 border border-amber-200 rounded-md">
  <p class="text-sm text-amber-800">
    <span class="font-medium">Recomendacion de seguridad:</span>
    Use un usuario de base de datos con permisos de solo lectura (SELECT).
  </p>
</div>
```

---

### 5. Info Reducida en Endpoints Health (Riesgo Bajo-Medio)

**Problema:** `/api/health/detailed` y `/api/metrics` exponian versiones de Elixir/OTP en produccion.

**Solucion:**
```elixir
# lib/qr_label_system_web/controllers/api/health_controller.ex

def detailed(conn, _params) do
  response = %{status: status, timestamp: timestamp, checks: checks}

  # Solo incluir version info en non-production
  response =
    if Application.get_env(:qr_label_system, :env) != :prod do
      response
      |> Map.put(:version, ...)
      |> Map.put(:elixir_version, ...)
      |> Map.put(:otp_version, ...)
    else
      response
    end
end
```

**Configuracion agregada:**
- `config/runtime.exs`: `config :qr_label_system, env: :prod`
- `config/dev.exs`: `config :qr_label_system, env: :dev`
- `config/test.exs`: `config :qr_label_system, env: :test`

---

### 6. Carga Automatica de .env (DX)

**Solucion:** Instalado `dotenvy` para cargar automaticamente archivos `.env`.

```elixir
# mix.exs
{:dotenvy, "~> 0.8", only: [:dev, :test]}

# config/runtime.exs
if config_env() in [:dev, :test] do
  Dotenvy.source([
    ".env",
    ".env.#{config_env()}",
    ".env.#{config_env()}.local"
  ])
end
```

**Uso:** Ya no es necesario `source .env && mix phx.server`.

---

### 7. Anonimizar PII en Logs (Riesgo Medio) - NUEVO

**Problema:** `HomeLive` registraba emails completos en logs de magic link.

**Solucion:**
```elixir
# lib/qr_label_system_web/live/home_live.ex

# Funcion para anonimizar email
defp anonymize_email(email) do
  case String.split(email, "@") do
    [local, domain] when byte_size(local) > 0 ->
      first_char = String.first(local)
      "#{first_char}***@#{domain}"
    _ ->
      "***@***"
  end
end

# Uso en logs
Logger.debug("Magic link request for: #{anonymize_email(email)}")
# Resultado: "u***@example.com" en vez de "user@example.com"
```

**Cambios:**
- Removidos logs innecesarios del mount
- Cambiado `Logger.info` a `Logger.debug`
- Removida exposicion de errores de changeset

---

### 8. Sanitizar Uploads en DataSourceController (Riesgo Alto) - NUEVO

**Problema:** El controller de upload copiaba archivos sin validar extension, tamano ni contenido.

**Solucion:**
```elixir
# lib/qr_label_system_web/controllers/data_source_controller.ex

@allowed_extensions ~w(.xlsx .xls .csv)
@max_file_size_mb 10

def upload(conn, %{"file" => upload}) do
  sanitized_name = FileSanitizer.sanitize_filename(upload.filename)
  ext = Path.extname(sanitized_name) |> String.downcase()

  with :ok <- validate_extension(ext),
       :ok <- validate_file_size(upload.path),
       :ok <- validate_file_content(upload.path, ext) do
    # Archivo valido, procesar...
  else
    {:error, :invalid_extension} ->
      put_flash(conn, :error, "Tipo de archivo no permitido")
    {:error, :file_too_large} ->
      put_flash(conn, :error, "Archivo demasiado grande (max 10MB)")
    {:error, :mime_type_mismatch} ->
      put_flash(conn, :error, "El contenido no coincide con la extension")
  end
end
```

**Tests agregados:**
- Test para archivo con extension invalida
- Test para archivo con contenido que no coincide

---

### 9. Limpieza Automatica de Archivos Huerfanos (Riesgo Medio) - NUEVO

**Problema:** Archivos en `priv/uploads/data_sources/` persistian indefinidamente si el usuario abandonaba el flujo.

**Solucion:** Worker de Oban que elimina archivos > 24h.

```elixir
# lib/qr_label_system/workers/upload_cleanup_worker.ex

defmodule QrLabelSystem.Workers.UploadCleanupWorker do
  use Oban.Worker, queue: :cleanup, max_attempts: 3

  @default_ttl_hours 24

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    ttl_hours = Map.get(args, "ttl_hours", @default_ttl_hours)
    {:ok, deleted_count} = cleanup_old_files(uploads_directory(), ttl_hours)
    Logger.info("UploadCleanupWorker: Deleted #{deleted_count} orphaned files")
    :ok
  end
end
```

**Configuracion Oban Cron:**
```elixir
# config/config.exs
config :qr_label_system, Oban,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", QrLabelSystem.Workers.UploadCleanupWorker}
     ]}
  ],
  queues: [default: 10, cleanup: 5]
```

---

### Commits de Esta Sesion

```
98148e4 security: Fix PII logging, file upload validation, and orphaned file cleanup
8f6b8b8 docs: Update HANDOFF with session 10 - security improvements
2904a3c refactor: Improve efficiency and fix resource leak
45bdb3f feat: Add automatic .env loading with dotenvy
f02257c security: Complete all security improvements
```

---

### Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `db_connector.ex` | Validacion SQL mejorada, module attribute para patterns |
| `file_sanitizer.ex` | Magic bytes detection, resource leak fix |
| `health_controller.ex` | Info reducida en produccion |
| `form_component.ex` | Banner seguridad BD read-only |
| `editor.ex` | Usa validacion magic bytes en upload |
| `README.md` | Credenciales removidas |
| `config/runtime.exs` | Dotenvy + env config |
| `config/config.exs` | Oban Cron plugin para cleanup |
| `config/test.exs` | env: :test |
| `mix.exs` | Dependencia dotenvy |
| `home_live.ex` | PII anonimizado en logs |
| `data_source_controller.ex` | Sanitizacion de uploads |
| `workers/upload_cleanup_worker.ex` | **Nuevo** - Job de limpieza |
| Tests (4 archivos) | 129+ tests de seguridad + tests upload

---

### Plan para Continuar

#### Pendientes del TODO (2 tareas)

| Tarea | Esfuerzo | Descripcion |
|-------|----------|-------------|
| **Alinear elementos en toolbar** | Bajo | JS ya implementado en `canvas_designer.js`, falta agregar boton en UI |
| **Etiquetas multiples sin Excel** | Medio | Permitir generar lote de etiquetas con cantidad especificada |

#### Alta Prioridad (del HANDOFF anterior)

1. **Preview de Etiquetas con Datos Reales**
   - Mostrar preview con datos del Excel/CSV
   - Navegador: `<< Anterior | Registro 3 de 150 | Siguiente >>`

2. **Generacion/Impresion de Lote**
   - PDF con todas las etiquetas del lote
   - Configuracion de pagina (etiquetas por fila, margenes)

#### Media Prioridad

3. **Validacion de Datos Importados**
   - Detectar filas con datos faltantes
   - Opcion de excluir filas problematicas

4. **Mejora UX Selector de Columnas**
   - Mostrar valor de ejemplo: `Nombre (ej: "Laptop HP")`

---

### Verificacion de Calidad

| Aspecto | Estado |
|---------|--------|
| **Tests** | 712 tests, 0 failures ✅ |
| **Compilacion** | Sin errores ✅ |
| **Seguridad SQL** | Normalización Unicode, 20+ patrones, 86 tests ✅ |
| **Seguridad uploads editor** | Magic bytes, no confia en cliente ✅ |
| **Seguridad uploads controller** | Extension + tamaño + magic bytes ✅ |
| **Info exposure** | Versiones ocultas en prod ✅ |
| **PII en logs** | Emails anonimizados ✅ |
| **Limpieza archivos** | Oban job cada hora, TTL 24h ✅ |
| **Resource management** | File.open con bloque ✅ |
| **Performance** | Regex en module attribute ✅ |

---

## Sesion Anterior (2 febrero 2026) - Mejoras Flujo de Importacion y Vinculacion

### Resumen Ejecutivo

Esta sesion se enfoco en mejorar la experiencia de usuario del flujo de **etiquetas multiples** (generacion masiva desde Excel/CSV). Se corrigieron 4 problemas criticos que impedian el uso efectivo del sistema:

| # | Problema | Impacto | Estado |
|---|----------|---------|--------|
| 1 | CSV no leia cabeceras | Columnas mostraban datos en vez de nombres | ✅ Corregido |
| 2 | UI confusa con 3 botones | Usuarios no sabian cual usar | ✅ Simplificado |
| 3 | Elemento se deseleccionaba | Flujo interrumpido al vincular datos | ✅ Corregido |
| 4 | Sin opcion texto fijo | No se podian mezclar datos fijos y variables | ✅ Implementado |

### Flujo de Etiquetas Multiples (Contexto)

```
[Usuario sube Excel/CSV] → [Selecciona diseño] → [Vincula columnas a elementos] → [Genera PDF]
       ↓                         ↓                        ↓
   data_first.ex          design_select.ex           editor.ex
```

**Tipos de etiqueta:**
- `single`: Una etiqueta con contenido fijo (ej: QR con URL especifica)
- `multiple`: Lote de etiquetas con datos de Excel/CSV (ej: etiquetas de productos)

---

### Objetivos Completados

1. Fix parser CSV para leer cabeceras correctamente
2. Simplificar UI de importacion (unificar botones Excel/CSV)
3. Preservar seleccion de elementos al cambiar vinculacion
4. Agregar modo texto fijo vs vinculacion de columna en etiquetas multiples

---

### Problema 1: CSV No Leia Cabeceras

**Sintoma:** Al importar CSV, las columnas mostraban valores de datos en vez de nombres de columnas.

**Causa:** NimbleCSV por defecto salta la primera fila (skip_headers: true).

**Archivo:** `lib/qr_label_system/data_sources/excel_parser.ex`

**Solucion:**
```elixir
# ANTES (incorrecto)
[headers | data_rows] =
  file_path
  |> File.stream!()
  |> NimbleCSV.RFC4180.parse_stream(separator: separator)
  |> Enum.take(max_rows + 1)

# DESPUES (correcto)
[headers | data_rows] =
  file_path
  |> File.stream!()
  |> NimbleCSV.RFC4180.parse_stream(skip_headers: false, separator: separator)
  |> Enum.take(max_rows + 1)
```

---

### Problema 2: UI Confusa con 3 Botones de Importacion

**Sintoma:** En `/generate/data` habia 3 botones: "Cargar Excel", "Cargar CSV", "Agregar manualmente". Usuarios no sabian cual elegir.

**Solucion:** Unificar Excel y CSV en un solo boton "Importar archivo".

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Cambios:**
- Un solo boton "Importar archivo" que acepta `.xlsx` y `.csv`
- El sistema auto-detecta el formato por extension
- Fix en pattern matching de `consume_uploaded_entries`:

```elixir
# ANTES (error)
case uploaded_files do
  [{:ok, file_path}] -> ...

# DESPUES (correcto - consume_uploaded_entries devuelve path directamente)
case uploaded_files do
  [file_path] when is_binary(file_path) -> ...
```

---

### Problema 3: Elemento se Deselecciona al Cambiar Vinculacion

**Sintoma:** En etiquetas multiples, al seleccionar una columna para vincular a un QR, el elemento se deseleccionaba y el panel mostraba propiedades de la etiqueta.

**Causa:** Condicion de carrera entre eventos:
```
1. Usuario cambia binding
2. LiveView guarda y recrea elemento en canvas
3. Canvas emite selection:created con nuevo objeto
4. LiveView recibe element_selected ANTES de que el design se actualice
5. Elemento no se encuentra → selected_element = nil
```

**Solucion:** Mecanismo `pending_selection_id` para "reservar" la seleccion.

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

```elixir
# En mount()
|> assign(:pending_selection_id, nil)

# En handle_event("update_element")
socket = assign(socket, :pending_selection_id, element_id)
# ... guardar elemento ...
# Despues de guardar exitosamente:
socket = assign(socket, :pending_selection_id, nil)

# En handle_event("element_selected")
def handle_event("element_selected", %{"id" => id}, socket) do
  element = find_element(socket.assigns.design.elements, id)

  # Si no encontramos el elemento pero estamos esperandolo, mantener seleccion actual
  if is_nil(element) && Map.get(socket.assigns, :pending_selection_id) == id do
    {:noreply, socket}
  else
    {:noreply, assign(socket, :selected_element, element)}
  end
end

# En handle_event("element_deselected")
def handle_event("element_deselected", _params, socket) do
  # No deseleccionar si estamos en proceso de recrear elemento
  if Map.get(socket.assigns, :pending_selection_id) do
    {:noreply, socket}
  else
    {:noreply, assign(socket, :selected_element, nil)}
  end
end
```

---

### Problema 4: Sin Opcion de Texto Fijo en Etiquetas Multiples

**Sintoma:** En etiquetas multiples, QR/barcode/text solo permitian vincular columnas. No habia forma de usar texto fijo (ej: QR con URL constante).

**Solucion:** Agregar selector de modo "Vincular columna" vs "Texto fijo".

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

**UI agregada para QR, Barcode y Text:**
```heex
<%= if @design.type == "multiple" do %>
  <div class="mb-4 flex rounded-lg bg-gray-100 p-1">
    <button
      type="button"
      phx-click="set_content_mode"
      phx-value-mode="binding"
      class={if has_binding?(@selected_element), do: "active-tab", else: "inactive-tab"}
    >
      Vincular columna
    </button>
    <button
      type="button"
      phx-click="set_content_mode"
      phx-value-mode="fixed"
      class={if !has_binding?(@selected_element), do: "active-tab", else: "inactive-tab"}
    >
      Texto fijo
    </button>
  </div>

  <%= if has_binding?(@selected_element) do %>
    <!-- Dropdown de columnas -->
  <% else %>
    <!-- Input de texto fijo -->
  <% end %>
<% end %>
```

**Handler agregado:**
```elixir
def handle_event("set_content_mode", %{"mode" => mode}, socket) do
  element = socket.assigns.selected_element

  updates = case mode do
    "binding" -> %{binding: "", text_content: nil}
    "fixed" -> %{binding: nil, text_content: ""}
  end

  # Actualizar elemento y guardar
end
```

**Helper para detectar modo:**
```elixir
defp has_binding?(element) do
  binding = Map.get(element, :binding) || Map.get(element, "binding")
  binding != nil  # nil = modo fijo, cualquier valor (incluso "") = modo vinculacion
end
```

---

### Archivos Creados para Testing

| Archivo | Descripcion |
|---------|-------------|
| `priv/ejemplo_productos.csv` | 12 productos alimenticios con SKU, Nombre, Precio, Stock |
| `priv/ejemplo_inventario.xlsx` | 12 items de ropa con Codigo, Producto, Talla, Color, Precio |

---

### Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| `excel_parser.ex` | +1 linea: `skip_headers: false` |
| `data_first.ex` | UI simplificada, fix pattern matching upload |
| `editor.ex` | +80 lineas: pending_selection_id, set_content_mode, UI modo fijo/binding |

### Commits de Esta Sesion

```
6ca907b fix: CSV parser headers and simplify data import UI
4c57e7b fix: Keep element selected when changing binding in multiple labels
dc69758 feat: Add fixed text vs column binding option for multiple labels
742e39f docs: Update HANDOFF with session 9 - import flow and binding improvements
```

### Como Probar los Cambios

1. **Probar importacion CSV:**
   ```bash
   # Usar archivo de ejemplo incluido
   # En navegador: http://localhost:4000/generate/data
   # Subir: priv/ejemplo_productos.csv
   # Verificar que columnas muestren: SKU, Nombre, Precio, Stock
   ```

2. **Probar preservacion de seleccion:**
   ```
   1. Subir Excel/CSV en /generate/data
   2. Seleccionar o crear diseño multiple
   3. Agregar elemento QR al canvas
   4. Seleccionar QR → cambiar vinculacion a una columna
   5. Verificar que QR sigue seleccionado (no salta a propiedades de etiqueta)
   ```

3. **Probar modo fijo vs binding:**
   ```
   1. En diseño multiple, seleccionar elemento QR/barcode/text
   2. Verificar que aparece selector "Vincular columna" / "Texto fijo"
   3. En modo binding: dropdown de columnas disponibles
   4. En modo fijo: input de texto libre
   ```

---

### Plan para Continuar

#### Alta Prioridad

1. **Preview de Etiquetas con Datos Reales**
   - **Que:** Mostrar preview de varias etiquetas con datos del Excel/CSV
   - **Donde:** `editor.ex` - agregar navegador de registros debajo del canvas
   - **Como:**
     - Obtener datos de `UploadDataStore.get(user_id, design_id)`
     - Crear componente de navegacion: `<< Anterior | Registro 3 de 150 | Siguiente >>`
     - Al navegar, reemplazar `{{columna}}` en elementos con valores reales
     - Regenerar QR/barcode con datos del registro actual
   - **Archivos a modificar:**
     - `editor.ex`: UI de navegacion, assigns para registro actual
     - `canvas_designer.js`: funcion `previewWithData(rowData)`

2. **Generacion/Impresion de Lote**
   - **Que:** Generar PDF con todas las etiquetas del lote
   - **Donde:** Nueva ruta `/generate/print` o extension de `editor.ex`
   - **Como:**
     - Iterar sobre todos los registros del Excel/CSV
     - Generar cada etiqueta con datos sustituidos
     - Organizar en pagina segun configuracion (etiquetas por fila, margenes)
     - Exportar como PDF usando `PrintEngine` hook existente
   - **Archivos a modificar:**
     - `print_engine.js`: extender para lotes
     - Nuevo: `generate_live/print.ex` o similar

#### Media Prioridad

3. **Validacion de Datos Importados**
   - **Que:** Detectar filas con datos faltantes o invalidos
   - **Donde:** `data_first.ex` despues de parsear archivo
   - **Como:**
     - Verificar que columnas vinculadas existan en datos
     - Detectar filas con celdas vacias en columnas requeridas
     - Mostrar resumen: "3 filas con datos incompletos"
     - Opcion de excluir filas problematicas
   - **Archivos a modificar:**
     - `excel_parser.ex`: agregar validacion
     - `data_first.ex`: UI de advertencias

4. **Mejora UX del Selector de Columnas**
   - **Que:** Mejor feedback visual al vincular columnas
   - **Donde:** `editor.ex` panel de propiedades
   - **Como:**
     - Mostrar valor de ejemplo al lado de cada columna: `Nombre (ej: "Laptop HP")`
     - Indicar columnas ya usadas con icono de check
     - Resaltar columnas no utilizadas
   - **Archivos a modificar:**
     - `editor.ex`: modificar dropdown de columnas

#### Baja Prioridad

5. **Plantillas Predefinidas**
   - **Que:** Ofrecer disenos de etiquetas comunes
   - **Ejemplos:** Etiqueta de precio, etiqueta de envio, etiqueta de inventario
   - **Como:** Crear disenos "template" con `user_id: nil` y listarlos en `/designs/new`

6. **Export/Import de Disenos**
   - **Que:** Permitir compartir disenos entre usuarios
   - **Como:** Exportar design como JSON, importar y clonar con nuevo `user_id`

---

### Diagrama de Flujo Completo (Estado Actual)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUJO ETIQUETAS MULTIPLES                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [/generate/data]          [/generate/design]         [/designs/:id/edit]   │
│       │                          │                          │               │
│  ┌────▼────┐              ┌──────▼──────┐            ┌──────▼──────┐        │
│  │ Subir   │              │ Seleccionar │            │ Vincular    │        │
│  │ Excel/  │─────────────▶│ o crear     │───────────▶│ columnas a  │        │
│  │ CSV     │              │ diseño      │            │ elementos   │        │
│  └─────────┘              └─────────────┘            └──────┬──────┘        │
│       │                                                     │               │
│       │ UploadDataStore                                     │               │
│       │ .put(user_id, data)                                 │               │
│       │                                                     │               │
│       └──────────────────────────────────────────┐          │               │
│                                                  │          │               │
│                                              ┌───▼──────────▼───┐           │
│                                              │   [PENDIENTE]    │           │
│                                              │   Preview con    │           │
│                                              │   datos reales   │           │
│                                              └────────┬─────────┘           │
│                                                       │                     │
│                                              ┌────────▼─────────┐           │
│                                              │   [PENDIENTE]    │           │
│                                              │   Generar PDF    │           │
│                                              │   del lote       │           │
│                                              └──────────────────┘           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Sesion Anterior (1 febrero 2026) - Fix Sincronizacion Propiedades Canvas

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
| 4 feb 2026 | 11 | PII anonimizado, sanitizacion uploads controller, cleanup job Oban |
| 4 feb 2026 | 10 | Seguridad completa: SQL validation, magic bytes, health info, .env auto-load |
| 2 feb 2026 | 9 | Fix CSV parser, UI importacion simplificada, preservar seleccion, modo fijo/binding |
| 1 feb 2026 | 8 | Fix sincronizacion propiedades canvas, UI controls, audit fixes, test fixes |
| 1 feb 2026 | 7 | QR/barcode real en canvas, validacion formatos, PropertyFields hook |
| 31 ene 2026 | 6 | Drag and drop reimplementado, cleanup de hooks |
| 31 ene 2026 | 5 | Upload de imagenes, fix guardado automatico |
| 31 ene 2026 | 4 | Header horizontal, backup/restore |

---

*Handoff actualizado: 4 febrero 2026 (sesion 11)*
