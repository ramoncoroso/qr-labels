# QR Label System

Sistema web de produccion para disenar y generar etiquetas personalizadas con codigos QR y de barras. Cada fila de datos produce una etiqueta unica con codigos unicos.

## Caracteristicas Principales

### Editor Visual
- Editor drag & drop basado en Fabric.js
- Dimensiones personalizables (0-500mm)
- Elementos: texto, QR, codigo de barras, lineas, rectangulos, circulos/elipses, imagenes
- Propiedades editables: posicion, tamano, rotacion, colores, fuentes
- **Preview real de QR y codigos de barras** mientras editas
- Validacion de formatos de codigo de barras con mensajes de error
- Sistema de capas con z-index
- Snap a grid y alineacion inteligente
- Zoom con rueda del mouse (Ctrl + scroll)
- Undo/Redo

### Tipos de Elementos
| Elemento | Descripcion |
|----------|-------------|
| Texto | Fuente, tamano, peso, color, alineacion |
| QR | Preview real, correccion de errores L/M/Q/H, colores personalizables |
| Barcode | Preview real con validacion de formato (CODE128, CODE39, EAN-13, EAN-8, UPC, ITF-14) |
| Linea | Grosor y color configurables |
| Rectangulo | Relleno, borde, radio de esquinas |
| Circulo/Elipse | Redondez ajustable (0-100%), relleno y borde |
| Imagen | Soporte para imagenes base64 (max 2MB) |

### Fuentes de Datos
- Importacion de Excel (.xlsx, .xls) y CSV
- Conexion a bases de datos externas (PostgreSQL, MySQL, SQL Server)
- Consultas SQL personalizadas
- Almacenamiento seguro de credenciales (encriptacion con Cloak)

### Generacion de Etiquetas
- **Modo simple**: Etiqueta unica estatica
- **Modo multiple**: Una etiqueta por fila de datos
- Binding de columnas a elementos del diseno
- Generacion de QR/barcode en el navegador (client-side)
- Exportacion a PDF
- Impresion directa

### Seguridad
- Autenticacion con email/password o magic link
- Roles: admin, operator, viewer
- RBAC (Role-Based Access Control)
- Rate limiting (login, API, uploads)
- Logs de auditoria completos
- Encriptacion de credenciales de BD

## Stack Tecnologico

| Capa | Tecnologia |
|------|------------|
| Backend | Elixir 1.14+, Phoenix 1.7, LiveView 0.20 |
| Base de datos | PostgreSQL 14+ con Ecto ORM |
| Frontend | TailwindCSS 3.3, Fabric.js 5.3 |
| Codigos | qrcode.js 1.5, JsBarcode 3.11 |
| PDF | jsPDF 2.5 |
| Excel | Xlsxir (server), xlsx (client) |
| Infraestructura | Docker, Nginx |

## Requisitos

- Elixir 1.14+
- Erlang/OTP 25+
- PostgreSQL 14+
- Node.js 18+

## Instalacion

### 1. Clonar el repositorio

```bash
git clone <repository-url>
cd qr_label_system
```

### 2. Instalar dependencias

```bash
# Dependencias de Elixir
mix deps.get

# Dependencias de JavaScript
cd assets && npm install && cd ..
```

### 3. Configurar base de datos

Editar `config/dev.exs` con las credenciales de PostgreSQL:

```elixir
config :qr_label_system, QrLabelSystem.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "qr_label_system_dev"
```

### 4. Crear y migrar base de datos

```bash
mix ecto.setup
```

### 5. Iniciar servidor

```bash
mix phx.server
```

Acceder a [localhost:4000](http://localhost:4000)

## Credenciales por Defecto (Desarrollo)

| Campo | Valor |
|-------|-------|
| Email | admin@example.com |
| Password | admin123456 |

## Estructura del Proyecto

```
qr_label_system/
├── lib/
│   ├── qr_label_system/              # Logica de negocio
│   │   ├── accounts/                 # Usuarios y autenticacion
│   │   │   ├── user.ex               # Schema de usuario
│   │   │   └── user_token.ex         # Tokens de sesion
│   │   ├── designs/                  # Disenos de etiquetas
│   │   │   ├── design.ex             # Schema de diseno
│   │   │   └── element.ex            # Schema embebido de elementos
│   │   ├── data_sources/             # Fuentes de datos
│   │   │   ├── data_source.ex        # Schema
│   │   │   ├── excel_parser.ex       # Parser de Excel/CSV
│   │   │   └── db_connector.ex       # Conexion a BD externas
│   │   ├── audit/                    # Logs de auditoria
│   │   ├── cache.ex                  # Cache ETS
│   │   ├── vault.ex                  # Encriptacion Cloak
│   │   └── upload_data_store.ex      # Almacen temporal de datos
│   │
│   └── qr_label_system_web/          # Capa web
│       ├── router.ex                 # Rutas
│       ├── plugs/                    # Middleware
│       │   ├── rbac.ex               # Control de acceso
│       │   ├── rate_limiter.ex       # Rate limiting
│       │   └── api_auth.ex           # Auth API
│       ├── components/               # Componentes UI
│       └── live/                     # LiveViews
│           ├── design_live/          # Editor de disenos
│           │   ├── index.ex          # Lista
│           │   ├── editor.ex         # Editor visual
│           │   └── show.ex           # Detalle
│           ├── data_source_live/     # Fuentes de datos
│           ├── generate_live/        # Flujo de generacion
│           └── admin/                # Panel admin
│
├── assets/
│   ├── js/
│   │   ├── app.js                    # Entry point
│   │   └── hooks/                    # LiveView Hooks
│   │       ├── canvas_designer.js    # Editor Fabric.js con QR/barcode real
│   │       ├── property_fields.js    # Preservacion de foco en inputs
│   │       ├── draggable_elements.js # Drag & drop al canvas
│   │       ├── code_generator.js     # Generacion QR/barcode para impresion
│   │       ├── print_engine.js       # PDF e impresion
│   │       ├── excel_reader.js       # Lectura Excel client-side
│   │       ├── label_preview.js      # Preview de etiquetas
│   │       ├── keyboard_shortcuts.js # Atajos de teclado
│   │       ├── sortable_layers.js    # Ordenamiento de capas
│   │       ├── border_radius_slider.js # Slider para redondez
│   │       ├── auto_hide_flash.js    # Auto-hide mensajes
│   │       ├── auto_upload_submit.js # Auto-submit uploads
│   │       └── single_label_print.js # Impresion individual
│   └── css/
│       └── app.css                   # Tailwind CSS
│
├── priv/
│   ├── repo/migrations/              # Migraciones de BD
│   └── static/                       # Assets estaticos
│
├── config/                           # Configuracion
│   ├── config.exs                    # Base
│   ├── dev.exs                       # Desarrollo
│   ├── prod.exs                      # Produccion
│   └── runtime.exs                   # Runtime (env vars)
│
├── test/                             # Tests
├── docker/                           # Docker config
└── mix.exs                           # Proyecto Mix
```

## Flujo de Trabajo

### Etiqueta Simple (Estatica)

1. Ir a **Generar** > **Etiqueta simple**
2. Seleccionar o crear diseno
3. Modificar contenido si es necesario
4. Imprimir o exportar PDF

### Etiquetas Multiples (Desde Datos)

1. Ir a **Generar** > **Multiples etiquetas**
2. Subir archivo Excel/CSV o seleccionar fuente de datos
3. Seleccionar o crear diseno
4. Mapear columnas a elementos del diseno
5. Generar lote (una etiqueta por fila)
6. Imprimir o exportar PDF

## API

El sistema expone endpoints de health check:

```bash
# Health check
GET /api/health

# Health check detallado (requiere auth)
GET /api/health/detailed
```

## Produccion

### Compilar Release

```bash
# Compilar assets
cd assets && npm run deploy && cd ..
mix phx.digest

# Crear release
MIX_ENV=prod mix release
```

### Variables de Entorno

```bash
DATABASE_URL=ecto://user:pass@host/db
SECRET_KEY_BASE=<64+ chars>
PHX_HOST=example.com
PORT=4000
```

### Docker

```bash
cd docker
docker-compose up -d
```

## Tests

```bash
# Todos los tests
mix test

# Tests con coverage
mix test --cover

# Tests especificos
mix test test/qr_label_system/accounts_test.exs
```

## Comandos Utiles

```bash
# Servidor de desarrollo
mix phx.server

# Consola interactiva
iex -S mix

# Crear migracion
mix ecto.gen.migration nombre_migracion

# Ejecutar migraciones
mix ecto.migrate

# Rollback migracion
mix ecto.rollback

# Reset base de datos
mix ecto.reset

# Formatear codigo
mix format
```

## Documentacion Adicional

- **HANDOFF.md**: Historial de cambios y estado actual del proyecto
- **priv/static/openapi.yaml**: Especificacion OpenAPI

## Contribuir

1. Fork del repositorio
2. Crear branch (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'feat: descripcion'`)
4. Push al branch (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

## Licencia

Propietario - Uso interno
