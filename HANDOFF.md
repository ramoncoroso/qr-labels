# HANDOFF: Sistema de Etiquetas QR - Production Ready

## Resumen Ejecutivo

Sistema web **production-ready** para generar etiquetas con códigos QR y de barras personalizados.

| Aspecto | Detalle |
|---------|---------|
| **Stack** | Elixir + Phoenix LiveView + PostgreSQL |
| **Frontend** | TailwindCSS + Fabric.js + QRCode.js + JsBarcode |
| **Infra** | Docker + Nginx + SSL |
| **Generación QR** | Client-side (navegador del usuario) |

---

## Estado Actual del Proyecto

**Fecha de última actualización:** 2026-01-31

### Progreso de Fases

| Fase | Descripción | Estado | Notas |
|------|-------------|--------|-------|
| 1 | Proyecto Phoenix + Auth | ✅ Completado | Estructura base creada |
| 2 | Contextos Backend | ✅ Completado | Accounts, Designs, DataSources, Batches, Audit |
| 3 | UI Base + Navegación | ✅ Completado | LiveView components |
| 4 | Editor Visual Canvas | ✅ Completado | Fabric.js integrado |
| 5 | Importación Excel/BD | ✅ Completado | Excel parser + DB connector |
| 6 | Generación QR/Barras | ✅ Completado | Client-side generation |
| 7 | Sistema Impresión | ✅ Completado | PDF + Print engine |
| 8 | Production Hardening | ⚠️ Parcial | Ver issues de seguridad |
| 9 | Testing & Docs | ❌ Pendiente | Sin tests implementados |

---

## Auditoría de Código Realizada (2025-01-29)

Se realizó una auditoría completa del código. A continuación los hallazgos:

### 🔴 Issues de Seguridad CRÍTICOS

| Severidad | Issue | Ubicación | Descripción |
|-----------|-------|-----------|-------------|
| **CRÍTICO** | API sin autenticación | `router.ex:102-112` | Los endpoints `/api/*` no tienen middleware de auth |
| **ALTO** | RBAC no implementado | `user_auth.ex`, `router.ex` | Los roles (admin/operator/viewer) existen pero no se validan |
| **ALTO** | Sin rotación de credenciales | `data_source.ex` | Credenciales BD encriptadas pero sin mecanismo de rotación |

### 🟠 Issues de Seguridad MODERADOS

| Issue | Ubicación | Descripción |
|-------|-----------|-------------|
| Session signing salt hardcodeado | `endpoint.ex:10` | Salt `"vQ8sKL3x"` debería ser generado con `mix phx.gen.secret` |
| Path traversal en uploads | `generate_live/data_source.ex:33` | `entry.client_name` no sanitizado |
| Default encryption key insegura | `config.exs:61` | Key placeholder en config de desarrollo |
| Sin rate limiting | Todas las rutas | Vulnerable a ataques de fuerza bruta |
| Remember cookie 60 días | `user_auth.ex:13-14` | Tiempo excesivo para sesiones |

### 🟡 Issues de Calidad de Código

| Issue | Ubicación | Descripción |
|-------|-----------|-------------|
| **Sin tests** | `test/` | Directorio vacío - 0% coverage |
| N+1 queries | `batches.ex:226-235` | Estadísticas de batch hacen queries separados |
| Missing preloads | `batch_live/show.ex:8-10` | Falta preload de asociaciones |
| Lógica duplicada | accounts, batches, designs, audit | Paginación repetida en 4 archivos |
| Código duplicado | `batch_live/index.ex`, `show.ex` | Mapeo de status/colores repetido |
| Missing indexes | `20240101000006_create_audit_logs.exs` | Faltan índices en audit_logs |
| Sin límite de archivo | `excel_parser.ex` | Uploads Excel sin tamaño máximo |
| Magic numbers | `batch_live/print.ex:70-85` | Valores hardcodeados sin constantes |

### ✅ Aspectos Positivos

- **Separación de contextos correcta** - Accounts, Designs, Batches, DataSources aislados
- **Changesets de Ecto robustos** - Validación fuerte en passwords y emails
- **CSRF protection habilitado**
- **Encriptación a nivel de campo** - Cloak para credenciales BD
- **Phoenix auto-escapa templates** - Protección XSS
- **Renovación de sesión en login** - Previene session fixation

---

## Arquitectura del Sistema

### Principio Clave

**CADA FILA DEL EXCEL = 1 ETIQUETA CON CÓDIGOS ÚNICOS**

```
Excel:                              Etiquetas generadas:
┌─────────┬───────────┬────────┐    ┌────────────────┐ ┌────────────────┐
│ ID      │ Paciente  │ Fecha  │    │ ████  García   │ │ ████  López    │
├─────────┼───────────┼────────┤ →  │ ████  M-001    │ │ ████  M-002    │
│ M-001   │ García    │ 15/01  │    │ ████  15/01    │ │ ████  15/01    │
│ M-002   │ López     │ 15/01  │    └────────────────┘ └────────────────┘
│ M-003   │ Martín    │ 16/01  │    QR único: M-001    QR único: M-002
└─────────┴───────────┴────────┘
```

### Estructura de Archivos

```
qr_label_system/
├── lib/
│   ├── qr_label_system/           # Core Business Logic
│   │   ├── accounts/              # Auth + usuarios
│   │   │   ├── user.ex            # Schema usuario con roles
│   │   │   └── user_token.ex      # Tokens de sesión
│   │   ├── designs/               # Diseños etiquetas
│   │   │   ├── design.ex          # Schema diseño
│   │   │   └── element.ex         # Elementos (QR, barcode, text)
│   │   ├── data_sources/          # Fuentes de datos
│   │   │   ├── data_source.ex     # Schema data source
│   │   │   ├── db_connector.ex    # Conexión BD externa
│   │   │   └── excel_parser.ex    # Parser Excel/CSV
│   │   ├── batches/               # Lotes generados
│   │   │   ├── batch.ex           # Schema batch
│   │   │   └── batches.ex         # Context
│   │   ├── audit/                 # Logs de auditoría
│   │   │   ├── log.ex             # Schema log
│   │   │   └── audit.ex           # Context
│   │   ├── vault.ex               # Cloak encryption vault
│   │   └── encrypted.ex           # Tipos encriptados
│   │
│   └── qr_label_system_web/       # Web Layer
│       ├── router.ex              # Rutas
│       ├── endpoint.ex            # HTTP endpoint
│       ├── user_auth.ex           # Auth pipeline
│       ├── components/            # UI components
│       └── live/
│           ├── design_live/       # Editor canvas
│           │   ├── editor.ex
│           │   ├── index.ex
│           │   └── show.ex
│           ├── data_source_live/  # Gestión datos
│           ├── batch_live/        # Generar + imprimir
│           │   ├── index.ex
│           │   ├── new.ex
│           │   ├── show.ex
│           │   └── print.ex
│           ├── generate_live/     # Workflow generación
│           │   ├── index.ex
│           │   ├── data_source.ex
│           │   ├── mapping.ex
│           │   └── preview.ex
│           └── auth_live/         # Login/registro
│
├── assets/js/hooks/               # Frontend Hooks
│   ├── canvas_designer.js         # Fabric.js editor
│   ├── code_generator.js          # QR + Barcode generation
│   ├── excel_reader.js            # Excel parsing client-side
│   ├── label_preview.js           # Preview labels
│   └── print_engine.js            # Print + PDF export
│
├── priv/repo/migrations/          # DB Migrations
│   ├── 20240101000001_create_users.exs
│   ├── 20240101000002_create_users_tokens.exs
│   ├── 20240101000003_create_label_designs.exs
│   ├── 20240101000004_create_data_sources.exs
│   ├── 20240101000005_create_label_batches.exs
│   └── 20240101000006_create_audit_logs.exs
│
├── config/
│   ├── config.exs                 # Config base
│   ├── dev.exs                    # Config desarrollo
│   ├── prod.exs                   # Config producción
│   ├── runtime.exs                # Config runtime (env vars)
│   └── test.exs                   # Config tests
│
└── docker/
    ├── Dockerfile
    ├── docker-compose.yml
    └── nginx/                     # Nginx config
```

---

## Base de Datos

| Tabla | Propósito | Campos Clave |
|-------|-----------|--------------|
| `users` | Autenticación + roles | email, hashed_password, role (admin/operator/viewer) |
| `users_tokens` | Tokens de sesión | user_id, token, context |
| `label_designs` | Diseños de etiquetas | name, width_mm, height_mm, elements (JSONB) |
| `data_sources` | Fuentes de datos | type, name, db_config (encrypted) |
| `label_batches` | Lotes generados | design_id, data_source_id, status, column_mapping |
| `audit_logs` | Trazabilidad | user_id, action, resource_type, changes |

---

## Características Implementadas

### Diseño Libre
- ✅ Dimensiones personalizables (0-500 mm)
- ✅ Elementos arrastrables: QR, código barras, texto, líneas, imágenes
- ✅ Vinculación de elementos a columnas del Excel
- ✅ Exportar/Importar diseños como JSON

### Fuentes de Datos
- ✅ Upload Excel (.xlsx) y CSV
- ✅ Conexión a BD externa (PostgreSQL, MySQL, SQL Server)
- ✅ Preview de columnas y datos

### Códigos Soportados
- ✅ **QR**: Cualquier contenido, error correction configurable
- ✅ **Barras**: CODE128, CODE39, EAN-13, EAN-8, UPC-A, ITF-14

### Impresión
- ✅ Hojas A4/Carta con etiquetas adhesivas
- ✅ Rollos de impresora (Zebra, Brother, Dymo)
- ✅ Exportación PDF con jsPDF

### Seguridad (Parcial)
- ✅ Autenticación con bcrypt
- ✅ Encriptación de credenciales BD con Cloak
- ⚠️ Roles definidos pero no enforced
- ❌ API sin protección
- ❌ Rate limiting

---

## Dependencias

### Elixir (mix.exs)
```elixir
{:phoenix, "~> 1.7.10"}
{:phoenix_live_view, "~> 0.20.1"}
{:ecto_sql, "~> 3.10"}
{:postgrex, ">= 0.0.0"}
{:myxql, "~> 0.6"}           # MySQL
{:tds, "~> 2.3"}             # SQL Server
{:bcrypt_elixir, "~> 3.0"}
{:cloak_ecto, "~> 1.2"}
{:xlsxir, "~> 1.6"}
{:nimble_csv, "~> 1.2"}
{:oban, "~> 2.17"}
{:esbuild, "~> 0.8"}
{:tailwind, "~> 0.2.0"}
```

### JavaScript (package.json)
```json
{
  "qrcode": "^1.5.3",
  "jsbarcode": "^3.11.6",
  "fabric": "^5.3.0",
  "xlsx": "^0.18.5",
  "jspdf": "^2.5.1",
  "phoenix": "...",
  "phoenix_live_view": "..."
}
```

---

## Próximos Pasos (Prioridad)

### 🔴 Prioridad Alta - Seguridad

1. **Agregar autenticación a API**
   - Archivo: `lib/qr_label_system_web/router.ex`
   - Acción: Agregar pipeline `:api_auth` con token validation

2. **Implementar RBAC**
   - Archivo: `lib/qr_label_system_web/user_auth.ex`
   - Acción: Crear plugs `require_admin/2`, `require_operator/2`
   - Aplicar en rutas según rol requerido

3. **Rate Limiting**
   - Agregar `{:hammer, "~> 6.1"}` a deps
   - Implementar rate limit en login y API

4. **Sanitizar nombres de archivo**
   - Archivo: `lib/qr_label_system_web/live/generate_live/data_source.ex`
   - Acción: Usar `Path.basename/1` y sanitizar caracteres especiales

### 🟠 Prioridad Media - Calidad

5. **Escribir Tests**
   - Tests unitarios para contextos (Accounts, Designs, Batches)
   - Tests de integración para LiveViews
   - Coverage mínimo recomendado: 80%

6. **Optimizar N+1 Queries**
   - Archivo: `lib/qr_label_system/batches.ex`
   - Acción: Usar `Ecto.Query.preload/3` y subqueries para stats

7. **Extraer código duplicado**
   - Crear módulo `QrLabelSystem.Pagination` compartido
   - Crear helper `BatchHelpers` para status colors

8. **Agregar índices faltantes**
   - Nueva migración para índices en `audit_logs`

### 🟡 Prioridad Baja - Mejoras

9. **Límite de tamaño de archivo**
   - Configurar `max_file_size` en upload config

10. **Generar session salt seguro**
    - Ejecutar `mix phx.gen.secret`
    - Actualizar `endpoint.ex`

11. **Documentación de API**
    - Agregar `{:open_api_spex, "~> 3.18"}` o similar

---

## Cómo Continuar el Desarrollo

### Setup Local

```bash
# 1. Ir al directorio del proyecto
cd C:\Users\rcoroso\ia\qr\qr_label_system

# 2. Instalar dependencias Elixir
mix deps.get

# 3. Instalar dependencias JS
cd assets && npm install && cd ..

# 4. Crear y migrar BD
mix ecto.setup

# 5. Iniciar servidor
mix phx.server

# 6. Acceder en http://localhost:4000
```

### Credenciales de Desarrollo

- **Email:** admin@example.com
- **Password:** admin123456

### Comandos Útiles

```bash
# Ejecutar tests
mix test

# Formatear código
mix format

# Verificar código
mix credo

# Generar migración
mix ecto.gen.migration nombre_migracion

# Reset BD
mix ecto.reset
```

---

## Verificación Final (Checklist)

### Funcionalidad
- [ ] Login/logout funciona
- [ ] Crear diseño con QR + texto
- [ ] Subir Excel de 10,000 filas
- [ ] Cada etiqueta tiene código ÚNICO
- [ ] Imprimir en A4 y rollo
- [ ] Exportar PDF

### Seguridad
- [ ] API autenticada
- [ ] RBAC funcionando
- [ ] Rate limiting activo
- [ ] Uploads sanitizados

### Producción
- [ ] Docker build exitoso
- [ ] Health check responde
- [ ] SSL configurado
- [ ] Variables de entorno configuradas

---

## Archivos de Referencia

- **Este handoff:** `C:\Users\rcoroso\ia\qr\HANDOFF.md`
- **Proyecto principal:** `C:\Users\rcoroso\ia\qr\qr_label_system\`
- **Config Claude:** `C:\Users\rcoroso\ia\qr\.claude\settings.local.json`

---

## Historial de Cambios

| Fecha | Cambio |
|-------|--------|
| 2025-01-29 | Auditoría completa de seguridad y código |
| 2025-01-29 | Documentación de issues encontrados |
| 2025-01-29 | Actualización de HANDOFF con próximos pasos |
| 2025-01-29 | **IMPLEMENTACIÓN DE FIXES DE SEGURIDAD Y CALIDAD** |

---

## Cambios Implementados (2025-01-29)

### Seguridad

#### 1. Autenticación API (`lib/qr_label_system_web/plugs/api_auth.ex`)
- Nuevo plug para autenticar requests API via Bearer token
- Validación de tokens de sesión existentes
- API endpoints ahora requieren autenticación

#### 2. RBAC - Control de Acceso Basado en Roles (`lib/qr_label_system_web/plugs/rbac.ex`)
- Plugs `require_admin`, `require_operator`, `require_viewer`
- Callbacks `on_mount` para LiveViews
- Autorización a nivel de recurso

#### 3. Rate Limiting (`lib/qr_label_system_web/plugs/rate_limiter.ex`)
- Dependencia `hammer` agregada a `mix.exs`
- Rate limit en login: 5 intentos/minuto por IP
- Rate limit en API: 100 requests/minuto por usuario
- Rate limit en uploads: 10/minuto por usuario

#### 4. Sanitización de Archivos (`lib/qr_label_system/security/file_sanitizer.ex`)
- Prevención de path traversal attacks
- Sanitización de nombres de archivo
- Validación de extensiones permitidas
- Validación de MIME types por magic bytes

#### 5. Sesiones Seguras (`lib/qr_label_system_web/endpoint.ex`)
- Nuevo `signing_salt` seguro (32 bytes)
- Agregado `encryption_salt` para encriptar contenido
- `same_site: "Strict"` para mejor protección CSRF
- `max_age: 7 días` (antes era indefinido)

#### 6. Límite de Tamaño de Archivo
- Upload Excel limitado a 10MB en `generate_live/data_source.ex`
- Limpieza automática de archivos temporales

#### 7. Health Check Endpoint (`lib/qr_label_system_web/controllers/api/health_controller.ex`)
- `/api/health` público para monitoreo
- Verifica conexión a base de datos

### Calidad de Código

#### 8. Optimización N+1 Queries (`lib/qr_label_system/batches.ex`)
- `get_user_stats/1` ahora usa una sola query con aggregates condicionales
- Nuevo `get_global_stats/0` para dashboard admin

#### 9. Módulo de Paginación (`lib/qr_label_system/pagination.ex`)
- Lógica de paginación centralizada
- Validación de parámetros
- Límite máximo de 100 items por página

#### 10. Helpers Compartidos (`lib/qr_label_system_web/helpers/batch_helpers.ex`)
- Colores y labels de status centralizados
- Funciones de formato de fecha
- Iconos SVG para estados

#### 11. Índices de Base de Datos
- Nueva migración `20240101000007_add_audit_logs_indexes.exs`
- Índices para user_id, action, resource_type, inserted_at
- Índices compuestos para queries comunes

### Tests

#### 12. Suite de Tests Básica
- `test/test_helper.exs` - Configuración
- `test/support/data_case.ex` - Case para tests de datos
- `test/support/conn_case.ex` - Case para tests de conexión
- `test/support/fixtures/accounts_fixtures.ex` - Fixtures de usuarios
- `test/qr_label_system/accounts_test.exs` - Tests de Accounts
- `test/qr_label_system/pagination_test.exs` - Tests de Pagination
- `test/qr_label_system/security/file_sanitizer_test.exs` - Tests de seguridad
- `test/qr_label_system_web/plugs/rbac_test.exs` - Tests de RBAC
- `test/qr_label_system_web/controllers/api/health_controller_test.exs` - Tests de Health

---

## Archivos Nuevos Creados

```
lib/qr_label_system_web/plugs/
├── api_auth.ex           # Autenticación API
├── rbac.ex               # Control de acceso por roles
└── rate_limiter.ex       # Rate limiting

lib/qr_label_system_web/controllers/api/
└── health_controller.ex  # Health check

lib/qr_label_system_web/helpers/
└── batch_helpers.ex      # Helpers de batch

lib/qr_label_system/
├── pagination.ex         # Paginación compartida
└── security/
    └── file_sanitizer.ex # Sanitización de archivos

priv/repo/migrations/
└── 20240101000007_add_audit_logs_indexes.exs

test/
├── test_helper.exs
├── support/
│   ├── data_case.ex
│   ├── conn_case.ex
│   └── fixtures/
│       └── accounts_fixtures.ex
├── qr_label_system/
│   ├── accounts_test.exs
│   ├── pagination_test.exs
│   └── security/
│       └── file_sanitizer_test.exs
└── qr_label_system_web/
    ├── plugs/
    │   └── rbac_test.exs
    └── controllers/api/
        └── health_controller_test.exs
```

---

## Estado Actual de Issues

### Resueltos ✅

| Issue | Estado |
|-------|--------|
| API sin autenticación | ✅ Implementado |
| RBAC no enforced | ✅ Implementado |
| Sin rate limiting | ✅ Implementado |
| Path traversal en uploads | ✅ Corregido |
| Session salt hardcodeado | ✅ Actualizado |
| Sin encryption salt | ✅ Agregado |
| Sin límite tamaño archivo | ✅ Agregado (10MB) |
| N+1 queries en stats | ✅ Optimizado |
| Código duplicado | ✅ Extraído a módulos |
| Índices faltantes | ✅ Migración creada |
| Sin tests | ✅ Suite básica creada |

### Pendientes de Verificación

| Issue | Acción Requerida |
|-------|------------------|
| Ejecutar migración | `mix ecto.migrate` |
| Instalar dependencias | `mix deps.get` |
| Ejecutar tests | `mix test` |
| Verificar en producción | Configurar env vars para salts |

---

## Variables de Entorno para Producción

```bash
# Sesiones (generar con: mix phx.gen.secret 32)
SESSION_SIGNING_SALT=tu_salt_de_firma_seguro
SESSION_ENCRYPTION_SALT=tu_salt_de_encriptacion

# Cloak (encriptación de credenciales BD)
CLOAK_KEY=tu_clave_cloak_base64

# Base de datos
DATABASE_URL=postgres://user:pass@host/db

# Phoenix
SECRET_KEY_BASE=tu_secret_key_base_muy_largo
PHX_HOST=tu-dominio.com
```

---

## Cambios Implementados (2025-01-31) - Correcciones del Editor

### Resumen
Se implementaron 5 correcciones importantes en el editor de etiquetas:

### 1. ✅ QR/Barcode: Tamaño ahora se guarda correctamente

**Archivos:**
- `assets/js/hooks/canvas_designer.js`
- `lib/qr_label_system_web/live/design_live/editor.ex`

**Problema:** El tamaño del QR/Barcode cambiaba visualmente pero revertía al mover el elemento. Esto era causado por dos problemas:
1. `elementData` se desincronizaba con el tamaño visual
2. `@selected_element` en el servidor quedaba desactualizado después de guardar

**Solución (Multi-parte):**

**A. Usar el tamaño visual como fuente de verdad** (canvas_designer.js - `saveElementsImmediate`):
```javascript
if (obj.type === 'group') {
  // Siempre usar las dimensiones visuales reales
  const visualWidthMM = obj.getScaledWidth() / PX_PER_MM
  const visualHeightMM = obj.getScaledHeight() / PX_PER_MM
  width = visualWidthMM
  height = visualHeightMM
  // Sincronizar elementData con visual
  if (data.width !== width || data.height !== height) {
    data.width = width
    data.height = height
    obj.elementData = data
  }
}
```

**B. Recrear grupos desde propiedades panel** (canvas_designer.js - `updateSelectedElement`):
```javascript
case 'width':
  if (obj.type === 'group') {
    this.recreateGroupAtSize(obj, value, data.height)
    return // recreateGroupAtSize handles save
  }
```

**C. Sincronizar selected_element con design** (editor.ex - `element_modified` handler):
```elixir
# Después de actualizar design, sincronizar selected_element
updated_selected =
  if socket.assigns.selected_element do
    selected_id = Map.get(socket.assigns.selected_element, :id) ||
                  Map.get(socket.assigns.selected_element, "id")
    Enum.find(updated_design.elements || [], fn el ->
      (Map.get(el, :id) || Map.get(el, "id")) == selected_id
    end)
  end
socket
|> assign(:design, updated_design)
|> assign(:selected_element, updated_selected)
```

**D. Normalizar escala después de drag-resize** (canvas_designer.js):
```javascript
// Después de guardar, recrear grupos con escala != 1
this.elements.forEach((obj, id) => {
  if (obj._pendingRecreate && obj.type === 'group') {
    const { width, height } = obj._pendingRecreate
    delete obj._pendingRecreate
    this.recreateGroupWithoutSave(obj, width, height)
  }
})
```

### 2. ✅ Layout: Paneles ya no desaparecen

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

**Problema:** Cuando el canvas era muy ancho, los paneles laterales (Capas, Propiedades) eran empujados fuera de la vista.

**Solución:** Se agregaron clases CSS de flexbox:
- `flex-shrink-0` a los paneles laterales para que no se compriman
- `min-w-0` al área del canvas para que pueda reducirse

Paneles modificados:
- Left sidebar (w-20): `flex-shrink-0`
- Layers panel (w-56): `flex-shrink-0`
- Properties panel (w-72): `flex-shrink-0`
- Canvas area: `min-w-0`

### 3. ✅ Zoom con rueda del ratón

**Archivos:**
- `assets/js/hooks/canvas_designer.js`
- `lib/qr_label_system_web/live/design_live/editor.ex`

**Funcionalidad:** Ctrl/Cmd + scroll del ratón sobre el canvas ahora hace zoom.

**Implementación JS:**
```javascript
container.addEventListener('wheel', (e) => {
  if (e.ctrlKey || e.metaKey) {
    e.preventDefault()
    const delta = e.deltaY > 0 ? -10 : 10
    const currentZoom = this._currentZoom * 100
    const newZoom = Math.max(50, Math.min(200, currentZoom + delta))
    this.pushEvent("update_zoom_from_wheel", { zoom: newZoom })
  }
}, { passive: false })
```

**Handler Elixir:**
```elixir
def handle_event("update_zoom_from_wheel", %{"zoom" => zoom}, socket) do
  new_zoom = max(50, min(200, round(zoom)))
  {:noreply,
   socket
   |> assign(:zoom, new_zoom)
   |> push_event("update_zoom", %{zoom: new_zoom})}
end
```

### 4. ✅ Dropdown de columnas: Ya muestra las columnas del Excel

**Archivos:**
- `lib/qr_label_system_web/live/design_live/new.ex`
- `lib/qr_label_system_web/live/generate_live/design_select.ex`
- `lib/qr_label_system_web/live/design_live/editor.ex`

**Problema:** El flujo data-first perdía las columnas del Excel porque el flash expiraba después de múltiples navegaciones:
1. `/generate/data` → flash con columnas
2. `/generate/design` → lee flash, pero al ir a "nuevo diseño"...
3. `/designs/new` → crea diseño → `/designs/{id}/edit`
4. Editor: flash ya expiró, columnas perdidas

**Solución:**
1. `new.ex` ahora lee y preserva `upload_data` y `upload_columns` del flash
2. Al guardar el diseño, `new.ex` re-pone los datos en flash antes de redirigir
3. `design_select.ex` y `editor.ex` ahora leen de flash primero, y de session como fallback

### 5. ✅ Navegación simplificada

**Archivo:** `lib/qr_label_system_web/components/layouts/app.html.heex`

**Cambios:**
- Eliminado: "Datos para etiquetas" (`/data-sources`) - ya no es necesario con el flujo data-first
- Renombrado: "Combinar e imprimir" → "Historial"
- Renombrado: "Diseños de etiquetas" → "Diseños"
- Actualizado icono de Historial a un reloj

---

## Tests Pendientes (Próxima Sesión)

### Test 1: QR/Barcode size (CRÍTICO)
```
1. Crear diseño nuevo
2. Añadir elemento QR (tamaño default 20mm)
3. En panel de propiedades, cambiar Ancho a 30mm
4. Verificar que el QR cambia visualmente de tamaño
5. Hacer clic en otra parte del canvas (fuera del QR)
6. Verificar que el QR mantiene el tamaño 30mm
7. Seleccionar el QR de nuevo y MOVERLO arrastrando
8. Verificar que el QR SIGUE siendo 30mm después de mover
9. Guardar diseño y recargar página
10. Verificar que QR mantiene tamaño 30mm
```
**Nota:** El paso 7-8 es crítico - anteriormente el tamaño revertía al mover.

### Test 2: Layout
```
1. Crear diseño muy ancho (ej: 200mm x 50mm)
2. Verificar que paneles de Capas y Propiedades siempre son visibles
3. Verificar que el canvas tiene scroll horizontal
```

### Test 3: Zoom wheel
```
1. En el editor, posicionar mouse sobre el canvas
2. Ctrl + scroll arriba = zoom in
3. Ctrl + scroll abajo = zoom out
4. Verificar que el porcentaje de zoom se actualiza en la UI
```

### Test 4: Columnas dropdown
```
1. Ir a `/generate` → "Múltiples etiquetas"
2. Cargar Excel con columnas: Producto, SKU, Precio
3. Continuar → "Nuevo Diseño"
4. Crear el diseño y entrar al editor
5. Añadir elemento texto
6. Verificar que "Vincular a columna" muestra: Producto, SKU, Precio
```

### Test 5: Navegación
```
1. Verificar que solo aparecen "Diseños" e "Historial" en el sidebar
2. Verificar que los flujos siguen funcionando correctamente
```

---

## Archivos Modificados (2025-01-31)

| Archivo | Cambio |
|---------|--------|
| `assets/js/hooks/canvas_designer.js` | +45 líneas: width/height para grupos, wheel zoom |
| `lib/qr_label_system_web/components/layouts/app.html.heex` | Simplificación navegación |
| `lib/qr_label_system_web/live/design_live/editor.ex` | +40 líneas: layout fix, wheel handler, session fallback |
| `lib/qr_label_system_web/live/design_live/new.ex` | +27 líneas: preservar datos upload |
| `lib/qr_label_system_web/live/generate_live/design_select.ex` | +13 líneas: session fallback |

---

## Historial de Cambios (Actualizado)

| Fecha | Cambio |
|-------|--------|
| 2025-01-29 | Auditoría completa de seguridad y código |
| 2025-01-29 | Documentación de issues encontrados |
| 2025-01-29 | Actualización de HANDOFF con próximos pasos |
| 2025-01-29 | **IMPLEMENTACIÓN DE FIXES DE SEGURIDAD Y CALIDAD** |
| 2025-01-31 | **CORRECCIONES DEL EDITOR DE ETIQUETAS** (5 fixes) |
| 2026-01-31 | **MEJORAS EN FLUJO DE GENERACIÓN Y EDITOR** |

---

## Cambios Implementados (2026-01-31) - Mejoras Completas

### Resumen
Se implementaron mejoras significativas en el flujo de generación de etiquetas y el editor visual.

### 1. ✅ UploadDataStore - Almacenamiento temporal robusto

**Archivo nuevo:** `lib/qr_label_system/upload_data_store.ex`

**Problema:** Los datos del Excel se perdían al navegar entre páginas porque el flash de Phoenix expira después de una lectura.

**Solución:** GenServer con ETS para almacenamiento temporal en memoria:
- Datos almacenados por user_id
- Expiración automática después de 30 minutos
- Limpieza periódica cada 5 minutos
- Integrado en Application supervision tree

**Uso:**
```elixir
# Guardar datos del upload
UploadDataStore.put(user_id, data, columns)

# Recuperar datos
{data, columns} = UploadDataStore.get(user_id)

# Limpiar datos
UploadDataStore.clear(user_id)
```

### 2. ✅ Campo label_type en diseños

**Archivo nuevo:** `priv/repo/migrations/20260131174618_add_label_type_to_designs.exs`

**Cambio:** Se agregó campo `label_type` a la tabla `label_designs`:
- Valores: `"single"` o `"multiple"`
- Default: `"single"`
- Índice compuesto con `user_id`

**Propósito:** Distinguir entre diseños para etiqueta única vs diseños para múltiples etiquetas (con columnas vinculadas).

### 3. ✅ Mejoras en el Editor Canvas

**Archivo:** `assets/js/hooks/canvas_designer.js`

**Cambios principales (+362 líneas):**

1. **QR/Barcode mantienen tamaño al mover:**
   - El tamaño visual es la fuente de verdad
   - `elementData` se sincroniza automáticamente
   - Grupos se recrean con escala normalizada

2. **Zoom con rueda del mouse:**
   - Ctrl/Cmd + scroll sobre el canvas
   - Rango: 50% - 200%
   - Actualización en tiempo real del slider

3. **Mejor manejo de grupos:**
   - `recreateGroupAtSize()` para cambios desde panel de propiedades
   - `recreateGroupWithoutSave()` para normalización post-drag
   - Preservación de elementData en todas las operaciones

### 4. ✅ Preview de etiquetas mejorado

**Archivo:** `assets/js/hooks/label_preview.js`

**Cambios:** Mejor renderizado de la previsualización de etiquetas con datos reales.

### 5. ✅ Flujo de generación simplificado

**Archivos modificados:**
- `lib/qr_label_system_web/live/generate_live/index.ex`
- `lib/qr_label_system_web/live/generate_live/data_first.ex`
- `lib/qr_label_system_web/live/generate_live/design_select.ex`
- `lib/qr_label_system_web/live/generate_live/single_select.ex`
- `lib/qr_label_system_web/live/design_live/new.ex`

**Mejoras:**
- UI más limpia y centrada
- Uso de UploadDataStore para persistir datos entre navegaciones
- Mejor integración entre flujo data-first y creación de diseños
- Columnas del Excel ahora disponibles correctamente en el editor

### 6. ✅ Contexto Designs actualizado

**Archivo:** `lib/qr_label_system/designs.ex`

**Nuevo:** Función `list_user_designs_by_type/2` para filtrar diseños por tipo.

---

## Archivos Nuevos Creados (2026-01-31)

```
lib/qr_label_system/
└── upload_data_store.ex     # GenServer para datos temporales

priv/repo/migrations/
└── 20260131174618_add_label_type_to_designs.exs  # Migración label_type
```

---

## Archivos Modificados (2026-01-31)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system/application.ex` | Agregado UploadDataStore al supervision tree |
| `lib/qr_label_system/designs.ex` | +12 líneas: list_user_designs_by_type/2 |
| `assets/js/hooks/canvas_designer.js` | +362 líneas: mejoras en grupos y zoom |
| `assets/js/hooks/label_preview.js` | +39 líneas: mejor renderizado |
| `lib/qr_label_system_web/live/design_live/new.ex` | +61 líneas: integración con UploadDataStore |
| `lib/qr_label_system_web/live/generate_live/data_first.ex` | +17 líneas: uso de UploadDataStore |
| `lib/qr_label_system_web/live/generate_live/design_select.ex` | Refactorización para UploadDataStore |
| `lib/qr_label_system_web/live/generate_live/index.ex` | UI mejorada |
| `lib/qr_label_system_web/live/generate_live/single_select.ex` | Ajustes menores |

---

## Próximos Pasos (Plan de Continuación)

### 🔴 Alta Prioridad

1. **Ejecutar migración pendiente**
   ```bash
   cd qr_label_system && mix ecto.migrate
   ```

2. **Probar flujo completo data-first:**
   - Subir Excel → Crear diseño → Vincular columnas → Generar etiquetas
   - Verificar que las columnas persisten a través de todas las navegaciones

3. **Probar tamaño de QR/Barcode:**
   - Cambiar tamaño desde panel de propiedades
   - Mover el elemento y verificar que mantiene el tamaño
   - Guardar y recargar para verificar persistencia

### 🟠 Media Prioridad

4. **Completar flujo de impresión:**
   - Verificar preview con datos reales
   - Probar exportación a PDF
   - Probar impresión directa

5. **Tests automatizados:**
   - Agregar tests para UploadDataStore
   - Tests de integración para flujo data-first
   - Tests para canvas_designer.js (Jest)

### 🟡 Baja Prioridad

6. **Optimizaciones:**
   - Cache de diseños frecuentes
   - Lazy loading de datos grandes
   - Compresión de imágenes en etiquetas

7. **UX:**
   - Indicadores de progreso más claros
   - Mensajes de error más descriptivos
   - Atajos de teclado en el editor

---

## Comandos para Continuar

```bash
# Ir al directorio del proyecto
cd /Users/coroso/ia/qr/qr_label_system

# Instalar dependencias si es necesario
mix deps.get

# Ejecutar migraciones pendientes
mix ecto.migrate

# Iniciar servidor
mix phx.server

# Acceder en http://localhost:4000
```

---

## Notas Técnicas Importantes

### UploadDataStore
- **Ubicación:** Memoria (ETS)
- **Expiración:** 30 minutos
- **Limpieza:** Cada 5 minutos
- **Identificador:** user_id (entero)

### label_type
- `"single"`: Diseños para etiqueta única (sin columnas vinculadas)
- `"multiple"`: Diseños para múltiples etiquetas (con columnas del Excel)

### Grupos en Fabric.js
- QR y Barcode son grupos (imagen + texto opcional)
- Al redimensionar, usar `recreateGroupAtSize()` para mantener proporciones
- El `elementData` debe sincronizarse con el tamaño visual

---

## Cambios Implementados (2026-02-02) - Fix consume_uploaded_entries

### Resumen

Se corrigió un bug crítico que impedía que los archivos Excel se procesaran correctamente en el flujo de etiquetas múltiples. La causa raíz era un patrón incorrecto en el manejo del resultado de `consume_uploaded_entries`.

### El Problema

`consume_uploaded_entries/3` de Phoenix LiveView devuelve una lista con los valores retornados por el callback. Si el callback retorna `{:ok, value}`, el resultado es `[{:ok, value}]`, **no** `[value]`.

**Código incorrecto:**
```elixir
# El callback retorna {:ok, file_path}
consume_uploaded_entries(socket, :data_file, fn %{path: path}, entry ->
  {:ok, dest}
end)

# Este pattern NO coincide porque uploaded_files es [{:ok, dest}]
case uploaded_files do
  [file_path] when is_binary(file_path) ->  # ❌ NUNCA COINCIDE
    ...
end
```

**Código correcto:**
```elixir
case uploaded_files do
  [{:ok, file_path}] ->  # ✅ COINCIDE CORRECTAMENTE
    ...
end
```

### Archivos Corregidos

| Archivo | Función Afectada | Problema |
|---------|------------------|----------|
| `lib/qr_label_system_web/live/generate_live/data_first.ex` | `upload_file` | Excel/CSV no se procesaban en flujo data-first |
| `lib/qr_label_system_web/live/design_live/index.ex` | `import_backup` | Importación de backups JSON no funcionaba |
| `lib/qr_label_system_web/live/design_live/editor.ex` | `upload_element_image` | Subida de imágenes para elementos no funcionaba |

### Impacto

- **Excel upload en etiquetas múltiples:** Las cabeceras del Excel ahora aparecen correctamente en las opciones de "vincular" (binding)
- **Import de backups:** Los archivos JSON de backup ahora se importan correctamente
- **Imágenes en editor:** Las imágenes subidas para elementos ahora se procesan correctamente

### Commits

| Hash | Descripción |
|------|-------------|
| `742e39f` | fix: Excel file upload pattern matching in data-first flow |
| `87f0771` | fix: Pattern matching for consume_uploaded_entries in index and editor |

### Verificación

Todos los tests pasan: **667 tests, 0 failures**

### Lección Aprendida

Siempre verificar que el pattern matching coincida con lo que realmente retorna la función. `consume_uploaded_entries` pasa el valor retornado por el callback directamente a la lista de resultados, incluyendo la tupla `{:ok, ...}` si el callback la retorna.

---

## Historial de Cambios (Actualizado)

| Fecha | Cambio |
|-------|--------|
| 2025-01-29 | Auditoría completa de seguridad y código |
| 2025-01-29 | Documentación de issues encontrados |
| 2025-01-29 | Actualización de HANDOFF con próximos pasos |
| 2025-01-29 | **IMPLEMENTACIÓN DE FIXES DE SEGURIDAD Y CALIDAD** |
| 2025-01-31 | **CORRECCIONES DEL EDITOR DE ETIQUETAS** (5 fixes) |
| 2026-01-31 | **MEJORAS EN FLUJO DE GENERACIÓN Y EDITOR** |
| 2026-02-02 | **FIX: consume_uploaded_entries pattern matching** (3 archivos) |
| 2026-02-04 | **MEJORAS EN CLASIFICACIÓN, GUARDADO Y UNDO/REDO** |

---

## Cambios Implementados (2026-02-04) - Clasificación y Undo/Redo

### Resumen

Se implementaron mejoras significativas en la organización de diseños, protección del guardado, y sistema de deshacer/rehacer.

### 1. ✅ Clasificación de etiquetas en "Mis diseños"

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

**Funcionalidad:**
- **Pestañas de filtro** en la parte superior: Todas | Únicas | Múltiples
- **Badges** en cada tarjeta indicando el tipo de etiqueta:
  - "Única" (gris) - etiquetas sin vinculación de datos
  - "Múltiple" (púrpura) - etiquetas con data binding
- **Contadores** en cada pestaña mostrando cantidad de diseños
- **Renombrado** de "Diseños de etiquetas" a "Mis diseños"

**Cambios en navegación:**
- Header del layout actualizado de "Diseños" a "Mis diseños"

**Archivos modificados:**
- `lib/qr_label_system_web/live/design_live/index.ex` - Pestañas, filtros, badges
- `lib/qr_label_system_web/components/layouts/app.html.heex` - Navegación

### 2. ✅ Protección del guardado contra pérdida de datos

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `assets/js/hooks/canvas_designer.js`

**Problema:** El botón "Guardar" a veces enviaba un array vacío de elementos, borrando todos los elementos existentes. Esto ocurría cuando el canvas no estaba completamente inicializado.

**Solución en el servidor (editor.ex):**
```elixir
def handle_event("element_modified", %{"elements" => elements_json}, socket) do
  current_element_count = length(design.elements || [])
  new_element_count = length(elements_json || [])

  # Rechazar arrays vacíos si el diseño tiene elementos
  if new_element_count == 0 and current_element_count > 0 do
    Logger.warning("element_modified received empty array - ignoring")
    {:noreply, put_flash(socket, :error, "El canvas no está listo. Intenta guardar de nuevo.")}
  else
    do_save_elements(socket, design, elements_json)
  end
end
```

**Solución en JavaScript (canvas_designer.js):**
```javascript
saveElementsImmediate() {
  // No guardar si el canvas no está inicializado
  if (this._isDestroyed || !this.elements || !this._isInitialized) {
    console.warn('Canvas not ready, skipping save')
    return
  }
  if (!this.canvas || !this.labelBounds) {
    console.warn('Canvas or labelBounds not ready, skipping save')
    return
  }
  // ... resto del guardado
}
```

### 3. ✅ Sistema Undo/Redo mejorado

**Archivos:**
- `lib/qr_label_system_web/live/design_live/editor.ex`
- `assets/js/hooks/canvas_designer.js`

**Cambios realizados:**

1. **Botones movidos al toolbar** - De la parte inferior del sidebar izquierdo al toolbar superior, junto a los controles de zoom:
   ```
   [ ↩ ↪ ]  [ ZOOM  -  100%  +  |  ⛶ ]  [ ALINEAR... ]
   ```

2. **Historial inicializado correctamente** - El estado inicial del diseño se guarda al montar:
   ```elixir
   # Antes: history vacío, undo nunca funcionaba
   |> assign(:history, [])
   |> assign(:history_index, -1)

   # Ahora: estado inicial guardado
   |> assign(:history, [design.elements || []])
   |> assign(:history_index, 0)
   ```

3. **Nuevo evento `reload_design`** - Fuerza la recarga del canvas en undo/redo:
   ```javascript
   // JavaScript
   this.handleEvent("reload_design", ({ design }) => {
     if (design && !this._isDestroyed) {
       this.loadDesign(design)  // Forzado, sin condiciones
     }
   })
   ```

   ```elixir
   # Elixir - undo/redo usan reload_design
   |> push_event("reload_design", %{design: Design.to_json(updated_design)})
   ```

4. **Historial guardado antes de añadir elementos**:
   ```elixir
   def handle_event("add_element", %{"type" => type}, socket) do
     design = socket.assigns.design
     # ... crear elemento ...
     case Designs.update_design(design, %{elements: new_elements}) do
       {:ok, updated_design} ->
         socket
         |> push_to_history(design)  # Guardar estado ANTERIOR
         |> assign(:design, updated_design)
         # ...
     end
   end
   ```

5. **Límite reducido a 10 estados**:
   ```elixir
   @max_history_size 10  # Antes era 50
   ```

**Flujo de undo/redo:**
- Cada acción (añadir elemento, mover, redimensionar, eliminar) guarda el estado anterior
- Máximo 10 acciones memorizadas
- Deshacer restaura el estado anterior y actualiza el canvas
- Rehacer vuelve al estado siguiente

---

## Archivos Modificados (2026-02-04)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system_web/live/design_live/index.ex` | +70 líneas: pestañas, filtros, badges, contadores |
| `lib/qr_label_system_web/components/layouts/app.html.heex` | Renombrado "Diseños" → "Mis diseños" |
| `lib/qr_label_system_web/live/design_live/editor.ex` | +30 líneas: protección guardado, undo/redo mejorado |
| `assets/js/hooks/canvas_designer.js` | +15 líneas: verificaciones save, evento reload_design |

---

## Commits (2026-02-04)

| Hash | Descripción |
|------|-------------|
| (varios) | feat: Classify designs as single/multiple with tabs and badges |
| (varios) | feat: Rename to "Mis diseños" in header and navigation |
| `eafeec8` | feat: Improve undo/redo system and move buttons to toolbar |

---

## Tests Recomendados

### Test 1: Clasificación de diseños
```
1. Ir a /designs (Mis diseños)
2. Verificar que aparecen pestañas: Todas | Únicas | Múltiples
3. Crear diseño "single" y verificar que tiene badge "Única"
4. Crear diseño "multiple" y verificar que tiene badge "Múltiple"
5. Filtrar por cada pestaña y verificar que muestra correctamente
```

### Test 2: Protección del guardado
```
1. Abrir editor de una etiqueta con elementos
2. Hacer clic en "Guardar" inmediatamente
3. Verificar que los elementos NO se borran
4. Añadir un QR y guardar inmediatamente
5. Ir a Mis diseños y volver a abrir - QR debe estar presente
```

### Test 3: Undo/Redo
```
1. Abrir editor de una etiqueta vacía
2. Añadir QR (estado 1)
3. Añadir Texto (estado 2)
4. Añadir Barcode (estado 3)
5. Hacer clic en Deshacer (↩) - Barcode desaparece
6. Hacer clic en Deshacer (↩) - Texto desaparece
7. Hacer clic en Rehacer (↪) - Texto vuelve
8. Verificar que los cambios se reflejan tanto en canvas como en capas
```
