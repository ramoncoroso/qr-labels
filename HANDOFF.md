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

**Fecha de última actualización:** 2025-01-29

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
