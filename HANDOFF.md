# HANDOFF: Sistema de Etiquetas QR - Production Ready

## Resumen Ejecutivo

Sistema web **production-ready** para generar etiquetas con códigos QR y de barras personalizados.

| Aspecto | Detalle |
|---------|---------|
| **Stack** | Elixir + Phoenix LiveView + PostgreSQL |
| **Frontend** | TailwindCSS + Fabric.js + bwip-js (21 formatos barcode/QR) |
| **Infra** | Docker + Nginx + SSL |
| **Generación QR** | Client-side (navegador del usuario) |

---

## Estado Actual del Proyecto

**Fecha de última actualización:** 2026-02-08

### Progreso de Fases Base

| Fase | Descripción | Estado | Notas |
|------|-------------|--------|-------|
| 1 | Proyecto Phoenix + Auth | ✅ Completado | Estructura base creada |
| 2 | Contextos Backend | ✅ Completado | Accounts, Designs, DataSources, Batches, Audit |
| 3 | UI Base + Navegación | ✅ Completado | LiveView components |
| 4 | Editor Visual Canvas | ✅ Completado | Fabric.js integrado |
| 5 | Importación Excel/BD | ✅ Completado | Excel parser + DB connector |
| 6 | Generación QR/Barras | ✅ Completado | Client-side generation, bwip-js |
| 7 | Sistema Impresión | ✅ Completado | PDF + Print engine (label-sized pages) |
| 8 | Production Hardening | ⚠️ Parcial | Ver issues de seguridad |
| 9 | Testing & Docs | ✅ Completado | 739 tests, 0 failures |

### Progreso del Plan de Producto (ver `PLAN_PRODUCTO.md`)

| Fase | Descripción | Estado | Notas |
|------|-------------|--------|-------|
| 1.1 | Biblioteca de plantillas por industria | ✅ Completado | 30 plantillas en 5 categorías, seeds, `/templates` |
| 1.2 | Formatos de código de barras industriales | ✅ Completado | bwip-js, 21 formatos, QR con logo embebido |
| 1.3 | Campos calculados y variables dinámicas | Pendiente | Motor `{{expresiones}}` en JS |
| 1.4 | Exportación ZPL (Zebra) | Pendiente | Generador server-side Elixir |

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
│   │   │   ├── element.ex         # Elementos (QR, barcode, text)
│   │   │   └── tag.ex             # Tags many-to-many
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
│           │   └── index.ex
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
│   ├── barcode_generator.js       # Módulo compartido bwip-js (QR + 21 formatos barcode)
│   ├── canvas_designer.js         # Fabric.js editor
│   ├── code_generator.js          # QR + Barcode generation
│   ├── excel_reader.js            # Excel parsing client-side
│   ├── label_preview.js           # Preview labels
│   ├── print_engine.js            # Print + PDF export (label-sized pages)
│   ├── single_label_print.js      # Print single labels (PDF-based)
│   ├── qr_logo_upload.js          # QR logo file upload hook
│   └── scroll_to.js               # Smooth scroll hook
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
| `design_tags` | Tags para organizar diseños | name, color, user_id (unique: user_id+name) |
| `design_tag_assignments` | Tabla pivot diseño↔tag | design_id, tag_id (unique: design_id+tag_id) |

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

### Códigos Soportados (21 formatos via bwip-js)
- ✅ **QR**: Cualquier contenido, error correction configurable (L/M/Q/H), logo embebido opcional
- ✅ **1D General**: CODE128, CODE39, CODE93, Codabar, MSI, Pharmacode
- ✅ **1D Retail**: EAN-13, EAN-8, UPC-A, ITF-14, GS1 DataBar, GS1 DataBar Stacked, GS1 DataBar Expanded
- ✅ **1D Supply Chain**: GS1-128
- ✅ **2D**: DataMatrix, PDF417, Aztec, MaxiCode
- ✅ **Postal**: POSTNET, PLANET, Royal Mail 4-State

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
  "bwip-js": "^4.8.0",
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

---

## Cambios Implementados (2026-02-04 Continuación) - Reorganización Header

### Resumen

Se reorganizó completamente la barra superior del editor para mejorar la accesibilidad de los controles y optimizar el espacio.

### ✅ Nueva estructura del Header (3 secciones)

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

```
┌──────────────┬──────────────────────────────────────────────────────┬───────────────────────┐
│  Izquierda   │                        Centro                        │       Derecha         │
├──────────────┼──────────────────────────────────────────────────────┼───────────────────────┤
│ ← Volver     │ [↩] [↪] | [🔍-] [100%] [🔍+] [⛶] | 100.0 × 100.0 mm │ Vista previa  Guardar │
│ Nombre       │                                                      │                       │
└──────────────┴──────────────────────────────────────────────────────┴───────────────────────┘
```

**Cambios realizados:**

1. **Undo/Redo movidos al centro del header:**
   - Botones con fondo `bg-gray-100`, iconos de 20px (w-5 h-5)
   - Estados deshabilitados visualmente (`bg-gray-50 text-gray-300 cursor-not-allowed`)
   - Tooltips con atajos de teclado (Ctrl+Z, Ctrl+Y)

2. **Zoom movido al centro del header:**
   - Mismos estilos que undo/redo para consistencia visual
   - Separado de undo/redo por línea vertical
   - Incluye: zoom out, porcentaje (clickeable para reset), zoom in, fit to view

3. **Dimensiones movidas al centro:**
   - A la derecha de los controles de zoom
   - Separadas por línea vertical
   - Formato: `100.0 × 100.0 mm`

4. **Toolbar del canvas simplificada:**
   - Eliminados undo/redo y zoom (ahora en header)
   - Padding reducido de `p-8` a `p-4`
   - Eliminado `justify-center` para subir el canvas
   - Solo muestra controles de **alineación** cuando hay 2+ elementos seleccionados

### Beneficios

- **Mejor accesibilidad:** Controles principales siempre visibles en el header
- **Más espacio para el canvas:** Toolbar simplificada, menos elementos flotantes
- **Consistencia visual:** Todos los controles principales en la misma zona
- **Información contextual:** Dimensiones siempre visibles junto a los controles

---

## Archivos Modificados (2026-02-04 Continuación)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system_web/live/design_live/editor.ex` | +73/-71 líneas: header 3 secciones, toolbar simplificada |

---

## Próximos Pasos (Plan de Continuación)

### 🔴 Alta Prioridad

1. **Reglas visuales (rulers)**
   - Agregar reglas en mm alrededor del canvas
   - Sincronizar con zoom del canvas

2. **Probar los cambios del header**
   - Verificar undo/redo funcionando desde el header
   - Verificar zoom funcionando desde el header
   - Verificar alineación aparece solo con 2+ elementos

### 🟠 Media Prioridad

3. **Mejorar feedback visual**
   - Indicador de guardado automático
   - Toast notifications para acciones

4. **Atajos de teclado adicionales**
   - Ctrl+S para guardar
   - Delete para eliminar elemento seleccionado

### 🟡 Baja Prioridad

5. **Optimizaciones de rendimiento**
   - Debounce en auto-save
   - Lazy loading de elementos pesados

---

## Cambios Implementados (2026-02-06) - Miniaturas de diseños y fix layout

### Resumen

Se reemplazó el icono genérico azul-índigo en la página `/designs` con miniaturas server-side que muestran el aspecto real de cada etiqueta. También se corrigió un crash en `/generate` causado por `@conn` en el layout.

**Plan de referencia:** Transcripción completa en `.claude/projects/-Users-coroso-ia-qr/efece49d-1c34-4bdf-9375-f9deb305009b.jsonl`

### 1. ✅ Miniaturas de etiquetas en `/designs`

**Archivo nuevo:** `lib/qr_label_system_web/components/design_components.ex`

**Enfoque:** Componente funcional Phoenix que renderiza una versión miniatura de la etiqueta usando HTML/CSS inline, sin dependencias JS adicionales.

**Componentes:**

- **`design_thumbnail/1`** - Componente público
  - Attrs: `design` (requerido), `max_width` (default 80), `max_height` (default 64)
  - Calcula escala: `min(max_w / label_w_px, max_h / label_h_px)`
  - Contenedor con `position: relative; overflow: hidden`, bg/border del diseño
  - Filtra elementos visibles, ordena por z_index
  - Sin elementos: muestra "Sin elementos"

- **`thumbnail_element/1`** - Componente privado, despacha por tipo:
  - `qr`: SVG simplificado con 3 finder patterns
  - `barcode`: Barras verticales CSS simuladas
  - `text`: Texto real escalado (min 2px font-size), con color/weight/alignment
  - `line`: div con background-color
  - `rectangle`: div con bg, border, border-width escalados
  - `circle`: Como rectangle pero con border-radius porcentual
  - `image`: Placeholder gris con icono SVG (SIN incluir image_data base64)

**Archivo modificado:** `lib/qr_label_system_web/live/design_live/index.ex`
- Añadido `import QrLabelSystemWeb.DesignComponents`
- Reemplazado icono gradiente azul (div 12x12 con SVG) por `<.design_thumbnail>`

### 2. ✅ Fix crash KeyError `@conn` en LiveViews

**Archivo:** `lib/qr_label_system_web/components/layouts/app.html.heex`

**Problema:** La línea `@conn.request_path` causaba KeyError en todas las LiveViews porque `@conn` solo existe en controllers, no en LiveViews (que usan `@socket`).

**Solución:** Eliminada la condición `:if={not String.starts_with?(@conn.request_path, "/generate")}` del enlace "Generar". El enlace ahora se muestra siempre.

---

## Archivos Modificados (2026-02-06)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system_web/components/design_components.ex` | **NUEVO** - 233 líneas: componente de miniaturas |
| `lib/qr_label_system_web/live/design_live/index.ex` | +4/-4 líneas: import + uso de design_thumbnail |
| `lib/qr_label_system_web/components/layouts/app.html.heex` | -1 línea: eliminado `@conn.request_path` |

---

## Commits (2026-02-06)

| Hash | Descripción |
|------|-------------|
| `5514ac6` | feat: Add server-side design thumbnails to /designs page |

---

## Verificación (2026-02-06)

- [x] `/designs` muestra miniaturas visuales en lugar del icono azul genérico
- [x] `/generate` ya no crashea con KeyError
- [x] Compila sin warnings nuevos (`mix compile`)
- [ ] Probar con cada tipo de elemento (qr, barcode, text, line, rectangle, circle, image)
- [ ] Probar diseño sin elementos muestra "Sin elementos"
- [ ] Probar elementos con `visible: false` no aparecen
- [ ] Duplicar diseño y verificar miniatura nueva
- [ ] Probar distintas proporciones (horizontal, vertical, cuadrado)

---

## Cambios Implementados (2026-02-06 Sesión 2) - Limpieza UX de /designs y mejoras /generate/data

### Resumen

Sesión enfocada en simplificar la experiencia en `/designs` eliminando redundancias y mejorando la interacción directa con las tarjetas de diseño. También se mejoró el feedback en `/generate/data`.

### 1. ✅ Eliminada página show de diseños

**Archivos eliminados:**
- `lib/qr_label_system_web/live/design_live/show.ex`
- `test/qr_label_system_web/live/design_live/show_test.exs`

**Archivos modificados:**
- `lib/qr_label_system_web/router.ex` - Eliminada ruta `/designs/:id`
- `lib/qr_label_system_web/live/design_live/index.ex` - Eliminado botón "Vista previa" (icono ojo)

**Razón:** La página show era redundante porque el editor (`/designs/:id/edit`) ya permite ver y editar el diseño completo.

### 2. ✅ Tarjetas clickeables para ir al editor

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

Toda la zona izquierda de cada tarjeta (thumbnail, nombre, dimensiones, elementos) ahora es un enlace que navega a `/designs/:id/edit`. Se reemplazó el `<div>` contenedor por `<.link navigate={...}>`.

### 3. ✅ Eliminado botón "Editar" redundante

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

El botón de editar (icono lápiz) se eliminó ya que la tarjeta completa ahora lleva al editor.

### 4. ✅ Botones Duplicar y Eliminar con texto + icono

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

Los botones de acción ahora muestran icono + texto con colores al estilo de `/generate/data`:
- **Duplicar:** purple (bg-purple-50, text-purple-700)
- **Eliminar:** red (bg-red-50, text-red-600)

Se eliminaron los tooltips ya que el texto es visible.

### 5. ✅ Badges de tipo movidos a la zona de info

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

Los badges "Única"/"Múltiple" y "Plantilla" se movieron de la derecha (junto a botones) a la izquierda, inline con "X elementos" en la línea de info. Estilo simplificado sin gradientes ni iconos SVG.

### 6. ✅ Subtítulo de página actualizado

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

Subtítulo cambiado de "Crea y administra tus diseños de etiquetas personalizadas" a "Pulsa sobre un diseño para editarlo en el canvas. Usa los botones para duplicar o eliminar."

### 7. ✅ Auto-scroll a datos procesados en /generate/data

**Archivos:**
- `assets/js/hooks/scroll_to.js` - **NUEVO** - Hook que escucha evento `scroll_to` y hace scroll suave
- `assets/js/hooks/index.js` - Registrado hook ScrollTo
- `lib/qr_label_system_web/live/generate_live/data_first.ex` - push_event scroll_to después de procesar archivo o pegar datos

**Problema:** Al procesar datos, la tabla de preview aparecía debajo del fold sin feedback visual.
**Solución:** Scroll automático a la sección `#data-preview` después de procesar.

### 8. ✅ Barra de progreso simplificada en /generate/data

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

Eliminado el pseudo-paso "Modo múltiple" (check verde) del flujo data-first. Ahora ambos flujos muestran 3 pasos numerados consistentemente:
- Flujo desde `/designs`: 1. Cargar datos → 2. Editar diseño → 3. Imprimir
- Flujo data-first: 1. Cargar datos → 2. Elegir diseño → 3. Imprimir

### 9. ✅ Botón "Vincular/Cambiar datos" en editor

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

Para diseños de tipo "múltiple", se añadió un botón en el toolbar del editor (sección derecha, antes de "Vista previa"):
- **Sin datos cargados:** "Vincular datos" (estilo indigo)
- **Con datos cargados:** "Cambiar datos" (estilo amber)

Navega a `/generate/data/:design_id` para cargar o reemplazar datos.

---

## Commits (2026-02-06 Sesión 2)

| Hash | Descripción |
|------|-------------|
| `2ac482f` | refactor: Remove redundant design show page and preview button |
| `e06d6b7` | feat: Make design card clickable to navigate to editor |
| `f87a0e9` | refactor: Remove redundant edit button from design cards |
| `45da9b7` | style: Add text labels to duplicate and delete buttons on design cards |
| `f46fdb9` | style: Move label type badges to left side of design cards |
| `8298136` | docs: Update designs page subtitle with usage instructions |
| `22d2ef0` | feat: Auto-scroll to data preview after processing on /generate/data |
| `cf6d5a8` | fix: Remove misleading "Modo múltiple" pseudo-step from progress bar |
| `7a63ace` | feat: Add data link/change button to editor toolbar for multiple designs |

---

## Archivos Nuevos (2026-02-06 Sesión 2)

```
assets/js/hooks/scroll_to.js    # Hook para scroll suave a elementos
```

## Archivos Eliminados (2026-02-06 Sesión 2)

```
lib/qr_label_system_web/live/design_live/show.ex           # Página show redundante
test/qr_label_system_web/live/design_live/show_test.exs     # Tests de show
```

## Archivos Modificados (2026-02-06 Sesión 2)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system_web/router.ex` | Eliminada ruta `/designs/:id` |
| `lib/qr_label_system_web/live/design_live/index.ex` | Tarjetas clickeables, botones con texto, badges reubicados, subtítulo |
| `lib/qr_label_system_web/live/design_live/editor.ex` | Botón vincular/cambiar datos en toolbar |
| `lib/qr_label_system_web/live/generate_live/data_first.ex` | Auto-scroll, barra progreso simplificada |
| `assets/js/hooks/index.js` | Registrado ScrollTo hook |

---

## Cambios Implementados (2026-02-07) - Reemplazo de Categorías por Tags (many-to-many)

### Resumen

Se reemplazó completamente el sistema de categorías (one-to-many) por un sistema de tags (many-to-many) que permite asignar múltiples etiquetas a cada diseño. Incluye creación inline con autocompletado, filtrado por chips, y gestión dinámica directa en las tarjetas.

### 1. ✅ Migración de BD

**Archivo nuevo:** `priv/repo/migrations/20260207200000_replace_categories_with_tags.exs`

- Crea tabla `design_tags` (name, color, user_id) con unique index en `(user_id, name)`
- Crea tabla pivot `design_tag_assignments` (design_id, tag_id) sin PK propio
- Migra datos existentes: categorías → tags via SQL INSERT...SELECT
- Migra asignaciones: category_id → tabla pivot
- Elimina columna `category_id` de `label_designs`
- Elimina tabla `design_categories`
- Rollback completo en `down/0`

### 2. ✅ Schema Tag

**Archivo nuevo:** `lib/qr_label_system/designs/tag.ex`

- Schema sobre tabla `design_tags`
- Campos: name, color (default "#6366F1")
- `belongs_to :user`, `many_to_many :designs` via `design_tag_assignments`
- Changeset: validación nombre 1-50 chars, color hex, unique per user

### 3. ✅ Schema Design actualizado

**Archivo:** `lib/qr_label_system/designs/design.ex`

- Reemplazado `belongs_to :category` → `many_to_many :tags, Tag, join_through: "design_tag_assignments"`
- Eliminado `:category_id` del changeset
- Eliminado `put_change(:category_id, ...)` del `duplicate_changeset`

### 4. ✅ Contexto Designs actualizado

**Archivo:** `lib/qr_label_system/designs.ex`

Eliminadas todas las funciones de categoría. Nuevas funciones de tags:
- `list_user_tags/1`, `get_tag/1`, `get_tag!/1`, `create_tag/1`, `delete_tag/1`
- `find_or_create_tag/3` — busca por nombre, crea si no existe (clave para UX inline)
- `add_tag_to_design/2` — insert en pivot con `on_conflict: :nothing`
- `remove_tag_from_design/2` — delete de pivot
- `preload_tags/1`, `search_user_tags/2` (autocompletado por prefijo, limit 10)
- `list_user_designs_by_tags/2` — filtro con semántica "todos los tags deben coincidir" (GROUP BY + HAVING COUNT)
- `duplicate_design` actualizado para copiar tags via `Repo.insert_all`

### 5. ✅ Eliminado category.ex

**Archivo eliminado:** `lib/qr_label_system/designs/category.ex`

### 6. ✅ UI completa en index.ex

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

**Nuevos assigns:** `tags`, `active_tag_ids`, `tag_input`, `tag_suggestions`, `tagging_design_id`

**Nuevos event handlers:**
- `toggle_tag_filter` / `clear_tag_filters` — filtrado por chips de tags
- `open_tag_input` / `close_tag_input` — input inline en tarjeta
- `tag_input_change` — autocompletado al escribir
- `add_tag_to_design` / `select_tag_suggestion` — crear/asignar tag
- `remove_tag_from_design` — quitar tag

**UI:**
- Chips de tags clickeables en zona de filtros con "Limpiar filtros"
- Múltiples chips de tags en cada tarjeta con "x" para quitar
- Botón "+ Tag" siempre visible (chip con borde dashed)
- Eliminados todos los modales de categoría (~155 líneas)

### 7. ✅ Bug fixes aplicados

| Bug | Causa | Solución |
|-----|-------|----------|
| Click en + Tag navega al canvas | Tag chips dentro de `<.link navigate=...>` | Movidos fuera del link |
| + Tag button invisible | `opacity-0 group-hover/card:opacity-100` | Chip siempre visible con borde dashed |
| Click en + Tag no hace nada | Stream items no re-renderizan por cambio de assigns | `stream_insert` en open/close_tag_input |

### 8. ✅ Layout de tarjetas mejorado

- Thumbnail en columna izquierda spanning altura completa
- Tags separados de medidas con más espaciado (`mt-3`)
- Thumbnail reducido a 80x80px para que el texto dicte la altura de la tarjeta

---

## Archivos Nuevos (2026-02-07)

```
priv/repo/migrations/
└── 20260207200000_replace_categories_with_tags.exs

lib/qr_label_system/designs/
└── tag.ex
```

## Archivos Eliminados (2026-02-07)

```
lib/qr_label_system/designs/category.ex
```

## Archivos Modificados (2026-02-07)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system/designs/design.ex` | many_to_many :tags en vez de belongs_to :category |
| `lib/qr_label_system/designs.ex` | Todas las funciones de categoría → funciones de tags |
| `lib/qr_label_system_web/live/design_live/index.ex` | UI completa de tags, layout tarjetas, bug fixes |

## Commits (2026-02-07)

| Hash | Descripción |
|------|-------------|
| `314c984` | feat: Replace categories with tags (many-to-many) |
| `6458708` | fix: Move tag chips outside link and make +Tag button always visible |
| `c45b059` | fix: Improve design card layout - thumbnail spans full height, tags separated |

## Verificación (2026-02-07 — sesión tags)

- [x] `mix ecto.migrate` ejecuta sin errores
- [x] `mix compile` sin warnings de categoría
- [x] 707 tests, 0 failures
- [x] Tags visibles como chips en tarjetas
- [x] Click "+" → input inline con autocompletado
- [x] Enter → tag creado y asignado
- [x] Click "x" → tag removido del diseño
- [x] Filtrado por tags funciona
- [x] Duplicar diseño copia tags

---

## Sesión 2026-02-07 — Fixes de impresión, binding de columnas y UX de carga

### Resumen

Se resolvieron 4 problemas clave:
1. **Impresión mostraba nombres de campo en vez de valores** — Fix en print_engine.js + integración en editor
2. **Design.to_json() no incluía label_type** — LabelPreview JS siempre defaulteaba a 'single'
3. **Parser de datos pegados no separaba columnas** — Solo dividía por tabs, no por espacios/comas/punto y coma
4. **Drop zone visible después de seleccionar archivo** — UX mejorada ocultando drop zone al seleccionar

### 1. ✅ Fix impresión de etiquetas múltiples (print_engine.js)

**Archivo:** `assets/js/hooks/print_engine.js`

- Corregido `substituteText()` para usar `columnMapping` al sustituir `{{campo}}` por valores reales
- El PrintEngine ahora recibe `upload_data` y `available_columns` del servidor
- Integrado hook `PrintEngine` en el panel de preview del editor (`editor.ex`)

### 2. ✅ Fix Design.to_json() — campo label_type faltante

**Archivo:** `lib/qr_label_system/designs/design.ex`

- Añadido `label_type: design.label_type` al mapa devuelto por `to_json/1`
- **Impacto:** Sin este campo, el hook `LabelPreview` en JS siempre defaulteaba a modo 'single', ignorando los bindings de columnas

### 3. ✅ Auto-detección de separador en paste parser

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Problema:** `parse_pasted_data/1` solo dividía por `\t` (tab). Cuando el usuario pegaba datos separados por espacios, todos los nombres de columna acababan como un solo string `"aaaa bbbb cccc"` en vez de tres columnas separadas.

**Solución:** Nueva función `detect_separator/1` que auto-detecta:
- Tabs (`\t`) — prioridad para datos copiados de Excel
- Punto y coma (`;`) — CSV europeo
- Comas (`,`) — CSV estándar
- Espacios múltiples (`\s{2,}`) o simples (`\s+`) — datos manuales

**Texto actualizado:** "Pegar datos desde Excel" → "Pegar datos" con descripción de auto-detección.

### 4. ✅ UX: Ocultar drop zone después de seleccionar archivo

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Problema:** Después de seleccionar un archivo Excel/CSV, el drop zone seguía visible, permitiendo seleccionar otro archivo antes de procesar.

**Solución:** Rendering condicional:
- `length(@uploads.data_file.entries) == 0` → Muestra drop zone completo
- Archivo seleccionado → Muestra solo: nombre del archivo, barra de progreso, botón eliminar, botón "Procesar archivo"

### 5. ✅ Panel de aviso "Sin datos vinculados" en editor

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

- Nuevo panel `bg-amber-50` visible cuando `label_type == "multiple"` y `available_columns == []`
- Mensaje: "Sin datos vinculados" con enlace a `/generate/data/{id}` para cargar datos
- Logging de debug en mount para trazar flujo de datos

### 6. ✅ Tests actualizados

**Archivo:** `test/qr_label_system_web/live/generate_live_test.exs`

- Assertion actualizada: `"Pegar datos desde Excel"` → `"Pegar datos"`
- 707 tests, 0 failures

---

## Archivos Modificados (2026-02-07 — sesión fixes)

| Archivo | Cambios |
|---------|---------|
| `assets/js/hooks/print_engine.js` | Fix sustitución de texto con columnMapping |
| `lib/qr_label_system/designs/design.ex` | Añadido `label_type` a `to_json/1` |
| `lib/qr_label_system_web/live/design_live/editor.ex` | PrintEngine hook, panel "sin datos", logging |
| `lib/qr_label_system_web/live/generate_live/data_first.ex` | Auto-detect separator, hide drop zone, logging |
| `test/qr_label_system_web/live/generate_live_test.exs` | Assertion de texto actualizada |

## Commits (2026-02-07 — sesión fixes)

| Hash | Descripción |
|------|-------------|
| `e7c0b17` | feat: Fix print data binding and add print/PDF from editor |
| `f8f6d24` | fix: Auto-detect separator in paste data parser |
| `34bb2dd` | fix: Hide drop zone after file is selected in data upload |

## Verificación (2026-02-07 — sesión fixes)

- [x] 707 tests, 0 failures
- [x] Columnas separadas correctamente al pegar datos con espacios/comas/tabs
- [x] Drop zone oculta después de seleccionar archivo
- [x] Botón "Procesar archivo" visible solo con archivo seleccionado
- [x] Panel "Sin datos vinculados" visible en editor para etiquetas múltiples sin datos
- [x] `label_type` incluido en Design.to_json()

---

## Sesión 2026-02-07 — UX de /designs: tags en header, rename, badges, clickabilidad

### Resumen

Mejoras de usabilidad en la página `/designs`:

### 1. ✅ Tags en misma fila que pestañas

Chips de tags de filtro movidos a la misma fila que "Todas | Únicas | Múltiples", alineados a la derecha con `justify-between`.

### 2. ✅ Inline rename con icono lápiz

Icono de lápiz junto al nombre del diseño (visible al hover). Al pulsar, el nombre se convierte en input editable con botones de confirmar/cancelar. Usa `stream_insert` para forzar re-render.

### 3. ✅ Tipo de etiqueta como texto plano

Reemplazados los badges coloreados "Única"/"Múltiple" por texto plano gris junto a las dimensiones para evitar confusión visual con los tags.

### 4. ✅ Eliminado contador de elementos

Quitado "X elementos" de las tarjetas — no aportaba valor al usuario.

### 5. ✅ Tarjeta completamente clickeable (stretched link)

Patrón CSS "stretched link": el link del nombre usa `after:absolute after:inset-0 after:content-['']` para cubrir toda la tarjeta. Botones y tags usan `relative z-10` para quedar por encima. Container de tags usa `pointer-events-none` con `[&>*]:pointer-events-auto` para no bloquear clicks en zonas vacías.

---

## Commits (2026-02-07 — sesión UX)

| Hash | Descripción |
|------|-------------|
| `7b8c5e4` | style: Move tag filter chips to same row as type tabs |
| `35323f0` | feat: Add inline rename with pencil icon on design cards |
| `5a45637` | style: Show label type as plain text instead of colored badges |
| `c6318e0` | fix: Make entire design card clickable with stretched link pattern |
| `106e5ec` | fix: Allow clicks through empty tag row area with pointer-events |

---

## Sesión 2026-02-07 — Fix Excel parser y upload de archivos

### Resumen

Se resolvieron 3 problemas críticos en la carga de archivos Excel/CSV:
1. **Excel no procesaba archivos** — `consume_uploaded_entries` crasheaba por pattern matching incorrecto
2. **Datos de Excel corruptos** — Xlsxir no soportaba inline strings (`t="inlineStr"`), devolviendo `nil` para columnas de texto
3. **Selector de archivos no abría** — `<.live_file_input>` desaparecía del DOM al cambiar de vista

### 1. ✅ Fix consume_uploaded_entries (crash al procesar)

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Problema:** Phoenix LiveView unwraps `{:ok, result}` del callback de `consume_uploaded_entries`. El callback devolvía `{:ok, dest}` → unwrapped a `dest` → el `case` esperaba `[{:ok, file_path}]` pero recibía `["/path/to/file"]` → `CaseClauseError` → LiveView crasheaba y remontaba (parecía "volver a la pantalla de carga").

**Solución:** Callback ahora devuelve `{:ok, {:ok, dest}}` y `{:ok, {:error, reason}}` para preservar el wrapping.

**Mismo bug que se corrigió el 2026-02-02 en 3 archivos**, pero `data_first.ex` fue omitido.

### 2. ✅ Reemplazo de Xlsxir por parser SAX propio

**Archivo:** `lib/qr_label_system/data_sources/excel_parser.ex`

**Problema:** Xlsxir v1.6.4 no leía celdas con `t="inlineStr"` (inline strings), devolviendo `nil`. Los archivos xlsx generados por herramientas JS (como ExcelJS) usan inline strings en vez de shared strings. Resultado: headers todos `Column_1..Column_N` y datos desplazados.

**Investigación:** Se inspeccionó el XML del xlsx directamente:
```xml
<c r="A1" s="1" t="inlineStr"><is><t>Producto</t></is></c>
```
Xlsxir devolvía `nil` para estas celdas. xlsx_reader tampoco funcionó porque el archivo usaba rutas absolutas en rels (`/xl/worksheets/sheet1.xml`), causando path duplicado `xl/xl/...`.

**Solución:** Parser SAX propio que:
- Usa `:zip.zip_open/2` para leer el xlsx
- Parsea `xl/sharedStrings.xml` para shared strings
- Parsea `xl/worksheets/sheet1.xml` con regex para extraer celdas
- Soporta tipos: `inlineStr`, `s` (shared string index), `n` (numérico), `b` (boolean)
- Convierte letras de columna a índices (`A`→0, `B`→1, `AA`→26)
- Unescape XML entities (`&amp;`, `&lt;`, etc.)

### 3. ✅ Fix live_file_input y selector de archivos

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Problema 1:** Dos `<.live_file_input>` en el template causaban conflictos.
**Problema 2:** Al ocultar el drop zone (rama `else`), el `<.live_file_input>` desaparecía del DOM, impidiendo que el upload completara (`progress: 0, preflighted?: false`).
**Problema 3:** Sin handler `cancel-upload`, el botón de eliminar archivo crasheaba el LiveView.

**Solución:**
- Un solo `<.live_file_input class="sr-only">` siempre en el DOM, fuera del `if/else`
- Drop zone cambiado de `<div>` a `<label for={@uploads.data_file.ref}>` para que todo el área abra el file picker
- Añadido handler `cancel-upload` con `cancel_upload(socket, :data_file, ref)`

### 4. ✅ Dependencias actualizadas

**Archivo:** `mix.exs`

- Reemplazado `{:xlsxir, "~> 1.6"}` por `{:xlsx_reader, "~> 0.8"}` (trae `saxy` para SAX parsing)
- El parser propio no usa xlsx_reader directamente, pero saxy queda disponible para futuro uso

---

## Archivos Modificados (2026-02-07 — sesión Excel)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system/data_sources/excel_parser.ex` | Parser SAX propio reemplaza Xlsxir |
| `lib/qr_label_system_web/live/generate_live/data_first.ex` | Fix upload, cancel-upload, live_file_input |
| `mix.exs` | xlsxir → xlsx_reader → eliminado (solo queda nimble_csv) |
| `mix.lock` | Eliminadas deps: xlsxir, erlsom, xlsx_reader, saxy |

## Commits (2026-02-07 — sesión Excel)

| Hash | Descripción |
|------|-------------|
| `d185da2` | fix: Replace Xlsxir with custom SAX parser for Excel and fix file upload |
| `918913d` | fix: Harden Excel parser and clean up unused dependencies |

## Verificación (2026-02-07 — sesión Excel)

- [x] 707 tests, 0 failures
- [x] Excel (.xlsx) parsea headers y datos correctamente (inline strings)
- [x] CSV (.csv) sigue funcionando sin cambios
- [x] Selector de archivos se abre al click
- [x] Drop zone oculta después de seleccionar archivo
- [x] Botón eliminar archivo funciona (cancel-upload)
- [x] Botón "Procesar archivo" procesa y muestra preview de datos

---

## Sesión 2026-02-07 (cont.) — Code review y hardening

### Resumen

Revisión de código post-implementación. Se encontraron y corrigieron 4 issues:

### 1. ✅ Fix zip handle leak

**Archivo:** `lib/qr_label_system/data_sources/excel_parser.ex`

**Problema:** Si `read_shared_strings()` o `read_first_sheet()` lanzaban excepción, `zip_handle` nunca se cerraba (leak de recursos).

**Solución:** Envuelto en `try/after` para garantizar `zip_close` en todos los caminos de ejecución.

### 2. ✅ Fix shared strings con rich text

**Archivo:** `lib/qr_label_system/data_sources/excel_parser.ex`

**Problema:** La regex de `parse_shared_strings` solo manejaba `<si><t>text</t></si>`. Excel puede guardar shared strings con formato rico: `<si><r><rPr>...</rPr><t>part1</t></r><r><t>part2</t></r></si>`.

**Solución:** Extraer cada bloque `<si>...</si>`, luego recoger todos los `<t>...</t>` dentro y unirlos.

### 3. ✅ Downgrade debug logging

**Archivo:** `lib/qr_label_system_web/live/generate_live/data_first.ex`

**Problema:** `Logger.info` con rutas de archivos y `inspect(result)` completo se ejecuta en producción. Filtra información interna y puede generar logs masivos con datos de usuarios.

**Solución:** Cambiado a `Logger.debug` y eliminado el dump completo del resultado.

### 4. ✅ Limpieza de dependencias no usadas

**Archivo:** `mix.exs`, `mix.lock`

**Problema:** `xlsx_reader` en mix.exs nunca se importaba ni usaba en el código (el parser propio usa `:zip` de Erlang). Además `xlsxir`, `erlsom` y `saxy` seguían en mix.lock como deps fantasma.

**Solución:** Eliminado `xlsx_reader` de mix.exs. Limpiados xlsxir, erlsom, xlsx_reader y saxy de mix.lock con `mix deps.clean --unlock`.

---

## Plan de Continuación

### Próximos pasos prioritarios

1. **Verificar flujo completo de impresión end-to-end**
   - Cargar datos → vincular columnas → previsualizar → imprimir/PDF
   - Confirmar que los valores reales aparecen en las etiquetas impresas

2. **Persistencia de datos entre sesiones**
   - UploadDataStore usa ETS (datos se pierden al reiniciar)
   - Opciones: guardar en DB, usar session storage, o mostrar aviso al usuario

3. **Detección de duplicados al importar** (pendiente)
   - Si ya existe un diseño con el mismo nombre, preguntar si duplicar o saltar

4. **Fix compilation warning**
   - `editor.ex:349` — agrupar cláusulas de `handle_event/3`

---

## Tareas Pendientes (TODO)

### 🟠 Mejoras Funcionales

1. **Preguntar antes de importar etiquetas duplicadas**
   - Al importar, si ya existe un diseño con el mismo nombre, preguntar al usuario si desea duplicar o saltar

### 🟡 Mejoras Técnicas

2. **Persistencia de datos vinculados entre sesiones**
   - UploadDataStore usa ETS — datos se pierden al reiniciar servidor
   - Considerar guardar datos en DB o session para que sobrevivan reinicios

---

## Sesión 2026-02-07 — Fix compilation warning y persistencia de resize en canvas

### Resumen

Se resolvieron 3 problemas: warning de compilación, pérdida de resize al hacer click, y QR/barcode que no se redimensionaban correctamente.

### 1. ✅ Fix compilation warning: handle_event/3 not grouped

**Archivo:** `lib/qr_label_system_web/live/design_live/editor.ex`

**Problema:** `@allowed_element_fields` y `defp do_save_elements/3` estaban insertados entre cláusulas de `handle_event/3`, causando warning del compilador.

**Solución:**
- `@allowed_element_fields` movido al inicio del módulo (junto a aliases)
- `do_save_elements/3` movido a la sección de Helper Functions (después de todos los `handle_event/3`)

### 2. ✅ Fix pérdida de resize al hacer click en otra parte

**Archivo:** `assets/js/hooks/canvas_designer.js`

**Problema:** Al redimensionar un elemento y hacer click en otra parte del canvas, el tamaño revertía al original. Causado por:
1. **Debounce de 100ms** en `saveElements()`: la deselección podía resetear el estado antes del save
2. **Fabric.js modifica `scaleX/scaleY`** al redimensionar, no `width/height`. Si la escala se reseteaba antes del save, se guardaban las dimensiones originales

**Solución (doble):**
- `object:modified` ahora llama `saveElementsImmediate()` directamente (sin debounce). El evento solo se dispara una vez al soltar el handle, así que no hay exceso de llamadas
- Normalización inmediata de escala en `object:modified` para elementos no-código: `width = width * scaleX`, `height = height * scaleY`, reset `scaleX/scaleY = 1`. Así `elementData` siempre refleja el tamaño visual real

### 3. ✅ Fix QR/barcode resize: detección por elementType y escalado independiente

**Archivo:** `assets/js/hooks/canvas_designer.js`

**Problema 1:** QR y barcode generados son `fabric.Image`, no `fabric.Group`. Toda la lógica de recreación (`_pendingRecreate`, `recreateGroupWithoutSave`) comparaba `obj.type === 'group'`, así que nunca se ejecutaba para códigos ya renderizados. Resultado: al ampliar un QR, el contenedor crecía pero la imagen QR quedaba del mismo tamaño. Al reducir un barcode, la imagen se recortaba.

**Solución:** Reemplazadas todas las comparaciones `obj.type === 'group'` por `obj.elementType === 'qr' || obj.elementType === 'barcode'` en:
- `object:modified` — exclusión de normalización de escala
- `saveElementsImmediate` — rama de dimensiones visuales y `_pendingRecreate`
- Recreación post-save — detección de elementos que necesitan regeneración
- `updateSelectedElement` (width/height) — panel de propiedades llama a `recreateGroupAtSize`

**Problema 2:** `createBarcode` usaba `Math.min(scaleX, scaleY)` (escala uniforme) para mantener la proporción del barcode. Cuando la proporción no coincidía con las dimensiones del usuario, el barcode quedaba más chico y ese tamaño reducido se guardaba.

**Solución:** Escalas independientes `scaleX: w / img.width, scaleY: h / img.height` para que el barcode llene exactamente las dimensiones especificadas.

**Problema 3:** `recreateGroupAtSize` usaba `saveElements()` (debounced 100ms). La generación asíncrona del barcode completaba antes del save, y `saveElementsImmediate` leía las dimensiones visuales (incorrectas por `Math.min`) en vez de las deseadas.

**Solución:** Cambiado a `saveElementsImmediate()` para que el save ocurra antes de la generación asíncrona.

---

## Archivos Modificados (2026-02-07 — sesión canvas resize)

| Archivo | Cambios |
|---------|---------|
| `lib/qr_label_system_web/live/design_live/editor.ex` | Movido `@allowed_element_fields` y `do_save_elements/3` para agrupar `handle_event/3` |
| `assets/js/hooks/canvas_designer.js` | Save sin debounce en `object:modified`, normalización de escala inmediata, detección por `elementType`, escalas independientes en barcode, save inmediato en `recreateGroupAtSize` |

## Commits (2026-02-07 — sesión canvas resize)

| Hash | Descripción |
|------|-------------|
| `e0a0827` | fix: Group handle_event/3 clauses together in editor.ex |
| `c8d5ec8` | fix: Persist element resize and regenerate QR/barcode at correct size |

## Verificación (2026-02-07 — sesión canvas resize)

- [x] 707 tests, 0 failures
- [x] Compilación sin warnings
- [x] Resize de elementos se persiste al hacer click en otra parte
- [x] QR se regenera al tamaño correcto al redimensionar
- [x] Barcode se regenera llenando las dimensiones exactas especificadas
- [x] Cambio de tamaño desde panel de propiedades funciona para QR/barcode

---

## Sesión: Placeholders "Completar" + Mejoras UX Canvas + Fix Preview (2026-02-07)

### Contexto

Mejora de la experiencia de usuario al crear nuevos elementos en el canvas. Anteriormente, los elementos se creaban con valores genéricos hardcodeados ("Escriba aqui...", "QR-1", "CODE1") que no indicaban claramente al usuario que debía completar el contenido.

### Cambios realizados

#### 1. Placeholder "Completar" con estilo visual gris (`6533d80`)
- **Backend (`editor.ex`)**: `text_content` por defecto cambiado a `""` (vacío) para texto, QR y barcode
- **Frontend (`canvas_designer.js`)**: Cuando `text_content` está vacío, el canvas muestra placeholder en gris `#999999` con estado `_isPlaceholder`
- **Propiedades**: Todos los inputs usan `placeholder="Completar"` (HTML nativo)
- **Edición en canvas**: Al hacer doble click en texto placeholder, se limpia y restaura color negro. Al salir vacío, reaparece el placeholder gris
- **Eventos**: `text:editing:entered` y `text:editing:exited` gestionan el ciclo de vida del placeholder

#### 2. Placeholders con tipo específico y forma visual (`96dce85`)
- **Texto en canvas por tipo**: "Completar texto", "Completar QR", "Completar cód. barras"
- **QR placeholder visual**: Finder patterns en 3 esquinas + módulos de datos dispersos + hueco blanco central con texto
- **Barcode placeholder visual**: Líneas verticales de ancho variable simulando código de barras + hueco blanco central con texto
- **Auto-escalado de fuente**: `fontSize = Math.min(maxFontSize, (ancho * 0.85) / numChars * 1.6)` para que el texto siempre quepa
- **Colores**: Gris (`#999999` texto, `#d1d5db` patrones, `#f3f4f6` fondo) para "Completar"; azul para "Generando..." (carga)

#### 3. Tamaño de texto por defecto aumentado (`435618a`)
- `font_size`: 12 → **25**
- `width`: 30mm → **60mm**
- `height`: 8mm → **14mm**
- Auto-fit actualizado para reconocer nuevo ancho por defecto (60mm)
- Preview: `overflow: visible` + `whiteSpace: normal` + `wordBreak: break-word`

#### 4. Fix tamaño de fuente en vista previa (`33e97eb`)
- **Problema**: Canvas usa `PX_PER_MM = 6`, preview usa `MM_TO_PX = 3.78`. Font size se aplicaba sin conversión → preview ~1.6x más grande
- **Fix**: `fontSize * scale` → `fontSize * (MM_TO_PX / 6) * scale`

### Archivos modificados

| Archivo | Cambios |
|---------|---------|
| `canvas_designer.js` | Placeholder gris, formas visuales QR/barcode, eventos text editing, auto-escalado fuente |
| `editor.ex` | Defaults vacíos, placeholders "Completar" en inputs, font_size 25, width 60mm |
| `label_preview.js` | Fix conversión px→mm en fontSize, overflow visible para texto |

### Commits

| Hash | Descripción |
|------|-------------|
| `6533d80` | feat: Show "Completar" placeholder in gray for empty text/QR/barcode elements |
| `96dce85` | feat: Show type-specific placeholders with visual QR/barcode shapes |
| `435618a` | feat: Increase default text element size and fix preview text overflow |
| `33e97eb` | fix: Match preview text font size with canvas by converting px-to-mm ratio |

### Referencia al Plan de Producto (`PLAN_PRODUCTO.md`)

Los cambios de esta sesión son **mejoras de UX del editor** (estabilización previa a Fase 1). El plan de producto define las siguientes fases pendientes:

#### Fase 1 — Fundamentos de valor profesional (pendiente)

| Sub-fase | Descripción | Estado | Semanas est. |
|----------|-------------|--------|-------------|
| **1.1** | Biblioteca de plantillas por industria (20 plantillas + catálogo) | Pendiente | 2-3 |
| **1.2** | Formatos de código de barras industriales (migrar a bwip-js, 30+ formatos) | Pendiente | 3-4 |
| **1.3** | Campos calculados y variables dinámicas (motor de expresiones `{{}}`) | Pendiente | 3-4 |
| **1.4** | Soporte impresoras ZPL (Zebra) | Pendiente | 4-6 |

#### Fase 2 — Diferenciación competitiva (futuro)
- 2.1 Cumplimiento normativo por sector
- 2.2 Sistema de aprobación y versionado
- 2.3 Multi-idioma en etiquetas
- 2.4 Integraciones (Shopify, ERPs, APIs)

#### Fase 3 — Escala y automatización (futuro)
- 3.1 Motor de reglas y automatización
- 3.2 Impresión en la nube (Cloud Print)
- 3.3 Workspaces y equipos

### Notas técnicas para próximas sesiones

- **Sistema de coordenadas dual**: Canvas (`PX_PER_MM = 6`) vs Preview/Print (`MM_TO_PX = 3.78`). Cualquier cambio visual debe verificarse en ambos sistemas.
- **3 puntos de generación**: `canvas_designer.js`, `label_preview.js`, `print_engine.js` — los tres deben mantenerse sincronizados.
- **Placeholder state**: Los elementos de texto usan `_isPlaceholder` y `_originalColor` en el objeto Fabric.js para gestionar el ciclo placeholder ↔ contenido real.

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
| 2026-02-04 | **REORGANIZACIÓN HEADER DEL EDITOR** (3 secciones) |
| 2026-02-06 | **MINIATURAS DE DISEÑOS + FIX LAYOUT @conn** |
| 2026-02-06 | **LIMPIEZA UX /designs + MEJORAS /generate/data + BOTÓN DATOS EN EDITOR** |
| 2026-02-07 | **REEMPLAZO DE CATEGORÍAS POR TAGS (many-to-many) + BUG FIXES + LAYOUT** |
| 2026-02-07 | **FIX IMPRESIÓN + AUTO-DETECT SEPARATOR + UX CARGA ARCHIVOS** |
| 2026-02-07 | **UX /designs: TAGS EN HEADER, RENAME INLINE, STRETCHED LINK** |
| 2026-02-07 | **FIX EXCEL PARSER + UPLOAD ARCHIVOS** |
| 2026-02-07 | **CODE REVIEW: zip leak, rich text, logging, deps cleanup** |
| 2026-02-07 | **FIX COMPILATION WARNING + PERSISTENCIA RESIZE + QR/BARCODE RESIZE** |
| 2026-02-07 | **PLACEHOLDERS "COMPLETAR" + MEJORAS UX CANVAS + FIX PREVIEW** |
| 2026-02-08 | **FASE 1.2: CÓDIGOS DE BARRAS INDUSTRIALES** (bwip-js, 21 formatos, QR con logo) |
| 2026-02-08 | **FIX: IMPRESIÓN PDF** — 3 iteraciones: autoPrint→iframe→window.open+print. Label-sized pages |
| 2026-02-08 | **UX: TAGS INLINE, DESCRIPCIÓN EDITABLE, LÁPICES AMPLIADOS** |

---

## Sesión 2026-02-08 — Fase 1.2: Códigos de barras industriales + QR con logo

### Resumen

Implementación completa de la Fase 1.2 del plan de producto (`PLAN_PRODUCTO.md`). Migración de JsBarcode + qrcode.js a bwip-js, con 21 formatos de código de barras y soporte para QR con logo embebido.

### 1. Módulo compartido `barcode_generator.js`

**Archivo nuevo:** `assets/js/hooks/barcode_generator.js`

Elimina la duplicación de código de generación de QR/barcode que existía en 5 archivos JS. Exporta:
- `generateQR(content, config, options)` — genera QR via bwip-js, con overlay de logo si `qr_logo_data` presente
- `generateBarcode(content, config, options)` — genera barcode via bwip-js, soporta 21 formatos
- `validateBarcodeContent(content, format)` — validación por formato (regex, longitud, caracteres)
- `is2DFormat(format)` — detecta formatos 2D (DataMatrix, PDF417, Aztec, MaxiCode)
- `getFormatGroups()` — grupos de formatos para dropdown UI

**5 archivos actualizados** para importar del módulo compartido:
- `canvas_designer.js`, `label_preview.js`, `print_engine.js`, `single_label_print.js`, `code_generator.js`

### 2. Migración a bwip-js

- `npm install bwip-js` / `npm uninstall jsbarcode qrcode`
- Diferencias de API clave: `bcid` en vez de `format`, colores sin `#`, `includetext` en vez de `displayValue`
- Bundle creció de 3.7MB a 5.0MB (esperado, bwip-js incluye 100+ encoders)

### 3. 14 nuevos formatos de barcode (total 21)

**`element.ex`**: `@barcode_formats` expandido de 7 a 21 formatos

**`editor.ex`**:
- Dropdown plano reemplazado por `<optgroup>` agrupado (5 grupos)
- `barcode_format_compatible?/2` actualizado con reglas para todos los formatos
- Hints de ejemplo por formato
- Checkbox "Mostrar texto" oculto para formatos 2D

### 4. QR con logo embebido

**`element.ex`**: Nuevos campos `qr_logo_data` (base64, max 500KB) y `qr_logo_size` (float 5-30%, default 25%)

**`editor.ex`**: UI para subir logo (QRLogoUpload hook), preview, botón quitar, slider de tamaño

**`qr_logo_upload.js`** (nuevo): Hook para validación de archivo y conversión a base64 via FileReader

**`barcode_generator.js`**: `generateQR()` fuerza error level H con logo y dibuja overlay centrado con padding blanco

### 5. Tests y plantillas

- 63 tests en `element_test.exs` (antes 47): validación de 14 nuevos formatos + QR logo
- 4 plantillas actualizadas: pharma→DATAMATRIX, logistics→GS1_128
- **739 tests, 0 failures**

### Commits

| Hash | Descripción |
|------|-------------|
| `83519fd` | feat: Industrial barcodes with bwip-js, 21 formats, and QR logo support |

---

## Sesión 2026-02-08 — Fix impresión PDF y mejoras UX /designs

### 1. Impresión y exportación PDF con tamaño de etiqueta

**Archivos:** `print_engine.js`, `single_label_print.js`

**Problema original:** `window.print()` con CSS `@page size` no era respetado por macOS.

**Evolución de la solución (3 iteraciones en esta sesión):**

1. **`pdf.autoPrint()` + `window.open(bloburl)`** — autoPrint inyecta JS en el PDF, pero los visores PDF de los navegadores no ejecutan JS embebido → el diálogo de impresión no se abría
2. **iframe oculto + `iframe.contentWindow.print()`** — el iframe carga el PDF vía plugin, pero `print()` imprime el documento HTML del iframe (vacío), no el PDF → preview en blanco
3. **`window.open(bloburl)` + `setTimeout` + `win.print()`** (solución final) — abre el PDF en nueva pestaña, espera 300ms a que el visor se inicialice, llama `print()` → funciona cross-platform

**Estado final:**
- Función helper `printPdfBlob(blob)` compartida en ambos hooks
- Tanto `printLabels()` como `exportPDF()` usan páginas tamaño-etiqueta (`format: [w, h]`)
- Imprimir: abre pestaña con PDF + dispara diálogo de impresión
- Exportar PDF: descarga archivo directamente

### 2. Tags inline y descripción editable en /designs

**Archivo:** `lib/qr_label_system_web/live/design_live/index.ex`

- Tags y botón "+ Tag" movidos a la misma línea que medidas/tipo
- Campo `description` visible entre nombre y medidas
- Descripción editable inline (mismo patrón que rename: lápiz → input → confirmar/cancelar)
- Iconos de editar nombre/descripción ampliados a `w-5 h-5`

### 3. Botones Print/PDF en editor

Botones de imprimir (🖨️) y PDF (📄) siempre visibles en el header del editor, a la derecha de "Guardar". PrintEngine hook montado siempre (fuera de condicionales).

### Commits

| Hash | Descripción |
|------|-------------|
| `4b6d3c7` | fix: Print via PDF with label-sized pages instead of HTML window.print |
| `39850f8` | fix: Use label-sized pages for print and fix print dialog not opening |
| `36fac3f` | feat: Add print/PDF buttons to editor header and use label-sized PDF pages |
| `9bcc31e` | feat: Add inline description editing and enlarge pencil icons in design list |
| `2fc41cd` | ui: Move tags inline with info row and show description in design list |
| `99e1f45` | fix: Repair syntax error in print_engine.js and update HANDOFF with Fase 1.2 |
| `9c8419b` | fix: Generate QR/barcode in print using static content fallback and improve print flow |
| `b479f43` | fix: Use label-sized pages for both print and PDF export |

---

## Archivos Clave (Fase 1.2)

| Archivo | Cambio |
|---------|--------|
| `assets/js/hooks/barcode_generator.js` | **NUEVO** — módulo compartido bwip-js |
| `assets/js/hooks/qr_logo_upload.js` | **NUEVO** — hook upload logo QR |
| `assets/package.json` | +bwip-js, -jsbarcode, -qrcode |
| `assets/js/hooks/canvas_designer.js` | Imports del módulo compartido |
| `assets/js/hooks/label_preview.js` | Imports del módulo compartido |
| `assets/js/hooks/print_engine.js` | Imports compartido + PDF label-sized |
| `assets/js/hooks/single_label_print.js` | Imports compartido + PDF label-sized |
| `assets/js/hooks/code_generator.js` | Imports del módulo compartido |
| `lib/qr_label_system/designs/element.ex` | +14 formatos, +qr_logo_data/size |
| `lib/qr_label_system/designs/design.ex` | +qr_logo_data/size en element_to_json |
| `lib/qr_label_system_web/live/design_live/editor.ex` | Dropdown agrupado, QR logo UI, print/PDF buttons |
| `test/qr_label_system/designs/element_test.exs` | 63 tests (14 nuevos formatos + QR logo) |
| `priv/repo/seeds/templates.exs` | Pharma→DATAMATRIX, logistics→GS1_128 |

---

## Bugs corregidos en esta sesión (2026-02-08)

1. **Syntax error en print_engine.js** — Llave extra `}` cerraba `printLabels()` prematuramente, rompiendo el objeto `PrintEngine` y causando que QR/barcode no se pudieran añadir al canvas ("Something went wrong")
2. **Print dialog no se abría** — `pdf.autoPrint()` no funciona en navegadores modernos (el visor PDF no ejecuta JS embebido). Resuelto con `window.open()` + `win.print()`
3. **Print preview en blanco con iframe** — `iframe.contentWindow.print()` imprime el documento HTML del iframe, no el PDF renderizado por el plugin. Revertido a `window.open()`
4. **Print preview cortaba la etiqueta** — Se probó A4 centrado pero el usuario prefiere páginas tamaño-etiqueta. Estado final: ambos hooks usan `format: [w, h]`

---

## Próximos pasos — Referencia al Plan de Producto (`PLAN_PRODUCTO.md`)

### Estado de las fases

| Fase | Descripción | Estado | Referencia |
|------|-------------|--------|------------|
| **1.1** | Biblioteca de plantillas por industria | ✅ Completado | 30 plantillas, 5 categorías, seeds, `/templates` |
| **1.2** | Formatos de código de barras industriales | ✅ Completado | bwip-js, 21 formatos, QR con logo, módulo compartido |
| **1.3** | Campos calculados y variables dinámicas | **Pendiente** | Motor `{{expresiones}}` en JS |
| **1.4** | Exportación ZPL (Zebra) | Pendiente | Generador server-side Elixir |

### Siguiente: Fase 1.3 — Campos calculados y variables dinámicas

**Objetivo**: Motor de expresiones `{{}}` que genera valores automáticos (fechas, contadores, condicionales), no solo datos del Excel.

**Valor**: "Etiquetas inteligentes que calculan datos por ti"

**Componentes principales** (ver detalle en `PLAN_PRODUCTO.md` sección 1.3):
- Nuevo módulo JS `expression_engine.js` — parsea `{{HOY()}}`, `{{CONTADOR(1,1,4)}}`, `{{SI(peso>1000, "PESADO", "LIGERO")}}`, etc.
- Nuevo campo `expression` en `element.ex` — prioridad: expression > binding > text_content
- 4 grupos de funciones: Texto (MAYUS, MINUS, RECORTAR), Fechas (HOY, SUMAR_DIAS), Números (CONTADOR, LOTE), Condicionales (SI, VACIO)
- UI: pestaña "Expresión" en propiedades del elemento con syntax highlighting, panel de funciones, preview en tiempo real
- Integración en los 3 puntos de renderizado: canvas, preview, print

### Bugs/mejoras pendientes

1. **Subir font_size +3pt en plantillas** — `priv/repo/seeds/templates.exs`, re-ejecutar seeds
2. **Placeholders grises en plantillas duplicadas** — campos con binding muestran gris hasta que CSV se carga
3. **Bug foco salta al campo nombre** — al editar text_content, el foco salta tras pausa (probable re-render LiveView)

## Arquitectura de impresión (estado final)

```
printLabels()                          exportPDF()
     │                                      │
     ▼                                      ▼
jsPDF format: [w, h]                 jsPDF format: [w, h]
(páginas tamaño etiqueta)            (páginas tamaño etiqueta)
     │                                      │
     ▼                                      ▼
printPdfBlob(blob)                   pdf.save(filename)
  → window.open(blobUrl)               → descarga archivo
  → win.load → 300ms delay
  → win.print()
  → diálogo impresión nativo
```

**Nota**: El usuario configura el tamaño de papel en el diálogo de impresión para que coincida con su impresora (térmica, etiquetas, A4, etc.).
