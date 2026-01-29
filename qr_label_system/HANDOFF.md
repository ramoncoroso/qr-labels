# QR Label System - Documento de Handoff

**Fecha**: Enero 2026
**Version**: 1.0.0
**Estado**: En desarrollo activo con hardening de seguridad completado

---

## 1. Resumen Ejecutivo

QR Label System es una aplicacion web desarrollada en Elixir/Phoenix LiveView para el diseno y generacion de etiquetas personalizadas con codigos QR y de barras. Permite importar datos desde Excel/CSV o bases de datos externas, mapearlos a disenos de etiquetas, y generar/imprimir lotes de etiquetas unicas.

### Stack Tecnologico

| Componente | Tecnologia | Version |
|------------|------------|---------|
| Backend | Elixir | ~> 1.14 |
| Framework | Phoenix | ~> 1.7.10 |
| UI en tiempo real | Phoenix LiveView | ~> 0.20.1 |
| Base de datos | PostgreSQL | 14+ |
| ORM | Ecto | ~> 3.10 |
| Frontend | Tailwind CSS, Fabric.js | - |
| Autenticacion | bcrypt_elixir | ~> 3.0 |
| Encriptacion | Cloak Ecto | ~> 1.2 |
| Rate Limiting | Hammer | ~> 6.1 |
| Background Jobs | Oban | ~> 2.17 |

---

## 2. Arquitectura del Sistema

```
qr_label_system/
├── lib/
│   ├── qr_label_system/              # Logica de negocio (Context modules)
│   │   ├── accounts/                 # Usuarios, autenticacion, roles
│   │   │   ├── user.ex               # Schema de usuario con roles
│   │   │   └── user_token.ex         # Tokens de sesion/API
│   │   ├── designs/                  # Disenos de etiquetas
│   │   │   └── label_design.ex       # Schema con elementos JSON
│   │   ├── data_sources/             # Fuentes de datos
│   │   │   └── data_source.ex        # Excel, CSV, conexiones BD
│   │   ├── batches/                  # Lotes de etiquetas
│   │   │   └── label_batch.ex        # Lotes generados
│   │   ├── audit/                    # Sistema de auditoria
│   │   │   └── audit_log.ex          # Logs de acciones
│   │   └── security/                 # Modulos de seguridad
│   │       └── file_sanitizer.ex     # Sanitizacion de archivos
│   │
│   └── qr_label_system_web/          # Capa web
│       ├── plugs/                    # Plugs de seguridad
│       │   ├── api_auth.ex           # Autenticacion API Bearer
│       │   ├── rate_limiter.ex       # Rate limiting con IP
│       │   └── rbac.ex               # Control de acceso por rol
│       ├── controllers/
│       │   ├── api/                  # Controladores API
│       │   └── health_controller.ex  # Health check
│       ├── live/                     # LiveViews
│       │   ├── design_live/          # Editor de disenos
│       │   ├── data_source_live/     # Gestion de fuentes
│       │   ├── batch_live/           # Gestion de lotes
│       │   └── generate_live/        # Flujo de generacion
│       ├── components/               # Componentes reutilizables
│       │   ├── core_components.ex
│       │   ├── pagination.ex         # Componente de paginacion
│       │   └── batch_helpers.ex      # Helpers de lotes
│       ├── router.ex                 # Rutas con pipelines de seguridad
│       └── endpoint.ex               # Endpoint con headers de seguridad
│
├── config/
│   ├── config.exs                    # Configuracion base
│   ├── dev.exs                       # Configuracion desarrollo
│   ├── test.exs                      # Configuracion tests
│   ├── prod.exs                      # Configuracion produccion
│   └── runtime.exs                   # Configuracion en runtime (secretos)
│
├── priv/
│   └── repo/
│       ├── migrations/               # Migraciones de BD
│       └── seeds.exs                 # Datos iniciales
│
├── assets/
│   ├── js/
│   │   ├── app.js                    # Punto de entrada JS
│   │   └── hooks/                    # LiveView Hooks
│   │       ├── canvas_designer.js    # Editor visual Fabric.js
│   │       ├── code_generator.js     # QR/barcode generation
│   │       ├── print_engine.js       # Impresion y PDF
│   │       └── excel_reader.js       # Lectura Excel client-side
│   └── css/
│       └── app.css                   # Tailwind CSS
│
└── test/                             # Tests
    ├── qr_label_system/
    │   └── security/
    │       └── file_sanitizer_test.exs
    └── qr_label_system_web/
        └── plugs/
            ├── api_auth_test.exs
            └── rate_limiter_test.exs
```

---

## 3. Sistema de Roles y Permisos (RBAC)

### Roles Definidos

| Rol | Descripcion | Permisos |
|-----|-------------|----------|
| `admin` | Administrador completo | Todo: usuarios, configuracion, datos, auditoria |
| `operator` | Operador de etiquetas | Crear/editar disenos, importar datos, generar lotes |
| `viewer` | Solo lectura | Ver disenos y lotes existentes |

### Implementacion

```elixir
# lib/qr_label_system_web/plugs/rbac.ex

# Pipelines disponibles:
# :admin_only    - Solo administradores
# :operator_only - Operadores y administradores
# :viewer_only   - Cualquier usuario autenticado
```

### Rutas Protegidas

```elixir
# router.ex

# Rutas web protegidas por rol
scope "/", QrLabelSystemWeb do
  pipe_through [:browser, :require_authenticated_user]
  # Rutas para usuarios autenticados
end

scope "/admin", QrLabelSystemWeb do
  pipe_through [:browser, :require_authenticated_user, :admin_only]
  # Solo administradores
end

# API protegida
scope "/api", QrLabelSystemWeb.API do
  pipe_through [:api_auth, :operator_only]
  # Requiere Bearer token + rol operator o admin
end
```

---

## 4. Seguridad Implementada

### 4.1 Autenticacion API (Bearer Token)

**Archivo**: `lib/qr_label_system_web/plugs/api_auth.ex`

```elixir
# Uso en rutas:
pipe_through [:api_auth]

# Header requerido:
Authorization: Bearer <base64_url_encoded_token>
```

**Caracteristicas**:
- Solo acepta tokens codificados en Base64 URL (sin fallback a raw tokens)
- Validacion de formato de header
- Tokens expiran con la sesion del usuario
- Logging de intentos fallidos

### 4.2 Rate Limiting

**Archivo**: `lib/qr_label_system_web/plugs/rate_limiter.ex`

**Configuracion**:
```elixir
# Variables de entorno
TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

**Caracteristicas**:
- Usa Hammer con backend ETS
- Extraccion segura de IP cliente (solo de proxies confiables)
- Soporte para rangos CIDR
- Limites configurables por accion

### 4.3 Sanitizacion de Archivos

**Archivo**: `lib/qr_label_system/security/file_sanitizer.ex`

**Protecciones**:
- Prevencion de path traversal (`../`, `..\\`)
- Decodificacion iterativa de URL encoding (hasta 5 niveles)
- Validacion de extensiones permitidas
- Validacion de MIME types
- Truncado de nombres largos (255 caracteres)

### 4.4 Headers de Seguridad

**Archivo**: `lib/qr_label_system_web/endpoint.ex`

Headers configurados:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- `Strict-Transport-Security` (solo en produccion)

### 4.5 Configuracion de Sesiones

**Archivo**: `config/runtime.exs`

```elixir
# Variables de entorno requeridas en produccion:
SESSION_SIGNING_SALT=<string_aleatorio_32+_caracteres>
SESSION_ENCRYPTION_SALT=<string_aleatorio_32+_caracteres>
SECRET_KEY_BASE=<string_aleatorio_64+_caracteres>
```

---

## 5. Variables de Entorno

### Produccion (Requeridas)

| Variable | Descripcion | Ejemplo |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Clave secreta Phoenix (64+ chars) | `mix phx.gen.secret` |
| `DATABASE_URL` | URL de PostgreSQL | `postgres://user:pass@host/db` |
| `SESSION_SIGNING_SALT` | Salt para firmar sesiones (32+ chars) | String aleatorio |
| `SESSION_ENCRYPTION_SALT` | Salt para encriptar sesiones (32+ chars) | String aleatorio |
| `PHX_HOST` | Host de la aplicacion | `app.example.com` |
| `PORT` | Puerto del servidor | `4000` |
| `CLOAK_KEY` | Clave de encriptacion Cloak (Base64) | Ver documentacion Cloak |

### Produccion (Opcionales)

| Variable | Descripcion | Default |
|----------|-------------|---------|
| `TRUSTED_PROXIES` | IPs/CIDRs de proxies confiables | `""` (ninguno) |
| `POOL_SIZE` | Tamano del pool de conexiones BD | `10` |

### Desarrollo

No requiere variables de entorno. Los valores estan en `config/dev.exs`.

---

## 6. Base de Datos

### Migraciones

```
20240101000001_create_users.exs           # Usuarios con roles
20240101000002_create_users_tokens.exs    # Tokens de sesion/API
20240101000003_create_label_designs.exs   # Disenos de etiquetas
20240101000004_create_data_sources.exs    # Fuentes de datos
20240101000005_create_label_batches.exs   # Lotes generados
20240101000006_create_audit_logs.exs      # Logs de auditoria
20240101000007_add_audit_logs_indexes.exs # Indices para auditoria
```

### Esquemas Principales

```elixir
# User
%User{
  email: string,
  hashed_password: string,
  role: :admin | :operator | :viewer,
  confirmed_at: datetime
}

# LabelDesign
%LabelDesign{
  name: string,
  width_mm: decimal,
  height_mm: decimal,
  elements: json,  # [{type, position, properties}]
  user_id: references(:users)
}

# DataSource
%DataSource{
  name: string,
  type: :excel | :csv | :postgres | :mysql | :sqlserver,
  config: encrypted_map,  # Cloak encrypted
  user_id: references(:users)
}

# LabelBatch
%LabelBatch{
  name: string,
  status: :pending | :processing | :completed | :failed,
  label_count: integer,
  design_id: references(:label_designs),
  data_source_id: references(:data_sources),
  user_id: references(:users)
}
```

---

## 7. API REST

### Endpoints

```
GET    /api/health              # Health check (sin auth)
GET    /api/designs             # Listar disenos
GET    /api/designs/:id         # Obtener diseno
POST   /api/designs             # Crear diseno
PUT    /api/designs/:id         # Actualizar diseno
DELETE /api/designs/:id         # Eliminar diseno

GET    /api/batches             # Listar lotes
GET    /api/batches/:id         # Obtener lote
POST   /api/batches             # Crear lote
GET    /api/batches/:id/labels  # Obtener etiquetas del lote
```

### Autenticacion

```bash
# Obtener token (usar token de sesion existente o crear via UI)
curl -X GET https://app.example.com/api/designs \
  -H "Authorization: Bearer $(echo -n 'session_token' | base64)"
```

---

## 8. Testing

### Ejecutar Tests

```bash
# Todos los tests
mix test

# Con coverage
mix coveralls.html

# Tests especificos
mix test test/qr_label_system_web/plugs/api_auth_test.exs
mix test test/qr_label_system/security/file_sanitizer_test.exs
```

### Tests de Seguridad Existentes

- `api_auth_test.exs` - Autenticacion Bearer token (9 tests)
- `rate_limiter_test.exs` - Rate limiting y extraccion IP (11 tests)
- `file_sanitizer_test.exs` - Sanitizacion de nombres de archivo

---

## 9. Despliegue

### Desarrollo

```bash
# Instalar dependencias
mix deps.get
cd assets && npm install && cd ..

# Configurar base de datos
mix ecto.setup

# Iniciar servidor
mix phx.server
# o
iex -S mix phx.server
```

### Produccion

```bash
# 1. Configurar variables de entorno
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export DATABASE_URL="postgres://user:pass@localhost/qr_label_prod"
export SESSION_SIGNING_SALT=$(openssl rand -base64 32)
export SESSION_ENCRYPTION_SALT=$(openssl rand -base64 32)
export PHX_HOST="app.example.com"

# 2. Compilar assets
cd assets && npm run deploy && cd ..
mix phx.digest

# 3. Crear release
MIX_ENV=prod mix release

# 4. Ejecutar migraciones
_build/prod/rel/qr_label_system/bin/qr_label_system eval "QrLabelSystem.Release.migrate"

# 5. Iniciar aplicacion
_build/prod/rel/qr_label_system/bin/qr_label_system start
```

### Docker (Recomendado)

```dockerfile
# Dockerfile ejemplo incluido en el proyecto
docker build -t qr_label_system .
docker run -p 4000:4000 \
  -e SECRET_KEY_BASE=... \
  -e DATABASE_URL=... \
  -e SESSION_SIGNING_SALT=... \
  -e SESSION_ENCRYPTION_SALT=... \
  qr_label_system
```

---

## 10. Historial de Cambios de Seguridad

### Commit 68850fb - Hardening de Seguridad (Actual)

**CRITICOS RESUELTOS**:
1. ~~Token encoding bypass~~ - Eliminado fallback a tokens raw en `api_auth.ex`
2. ~~IP spoofing via X-Forwarded-For~~ - Verificacion de proxies confiables
3. ~~Session salts hardcodeados~~ - Movidos a variables de entorno

**ALTA PRIORIDAD RESUELTOS**:
4. ~~RBAC faltante en API~~ - Agregado `:operator_only` pipeline
5. ~~Headers de seguridad faltantes~~ - Agregados en `endpoint.ex`

**MEDIA PRIORIDAD RESUELTOS**:
6. ~~Double encoding bypass~~ - Decodificacion iterativa en `file_sanitizer.ex`
7. ~~Hammer backend no configurado~~ - Configurado ETS en `runtime.exs`
8. ~~Limite de archivos faltante~~ - 10MB en `Plug.Parsers`

### Commit 60443bc - Implementacion Inicial de Seguridad

- Creacion de plugs de seguridad (api_auth, rbac, rate_limiter)
- Modulo file_sanitizer
- Optimizacion de queries N+1
- Componentes de paginacion

---

## 11. Tareas Pendientes

### Alta Prioridad

- [ ] Implementar rotacion automatica de tokens
- [ ] Agregar Content Security Policy (CSP) headers
- [ ] Implementar CSRF para API (double-submit cookie)
- [ ] Agregar tests de integracion E2E

### Media Prioridad

- [ ] Implementar rate limiting por usuario ademas de por IP
- [ ] Agregar metricas de Prometheus/Telemetry
- [ ] Implementar cache de disenos frecuentes
- [ ] Agregar soft-delete a entidades principales

### Baja Prioridad

- [ ] Internacionalizacion completa (i18n)
- [ ] Documentacion de API con OpenAPI/Swagger
- [ ] Dashboard de administracion mejorado
- [ ] Exportacion de logs de auditoria

---

## 12. Contactos y Recursos

### Documentacion

- [Phoenix Framework](https://hexdocs.pm/phoenix)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)
- [Ecto](https://hexdocs.pm/ecto)
- [Hammer Rate Limiter](https://hexdocs.pm/hammer)
- [Cloak Encryption](https://hexdocs.pm/cloak_ecto)

### Comandos Utiles

```bash
# Generar secreto
mix phx.gen.secret

# Consola interactiva con app cargada
iex -S mix

# Ver rutas
mix phx.routes

# Analisis estatico
mix credo --strict
mix dialyzer

# Formatear codigo
mix format
```

---

*Documento generado: Enero 2026*
