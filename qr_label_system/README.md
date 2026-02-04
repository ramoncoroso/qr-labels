# QR Label System

[![Elixir](https://img.shields.io/badge/Elixir-1.14+-4B275F?logo=elixir)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.7-FD4F00?logo=phoenixframework)](https://phoenixframework.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-336791?logo=postgresql)](https://postgresql.org/)
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

Sistema web de produccion para disenar y generar etiquetas personalizadas con codigos QR y de barras. Cada fila de datos produce una etiqueta unica con codigos unicos.

![Editor Preview](docs/images/editor-preview.png)

---

## Tabla de Contenidos

- [Caracteristicas](#caracteristicas)
- [Demo](#demo)
- [Stack Tecnologico](#stack-tecnologico)
- [Instalacion](#instalacion)
- [Uso](#uso)
- [Arquitectura](#arquitectura)
- [API](#api)
- [Tests](#tests)
- [Despliegue](#despliegue)
- [Contribuir](#contribuir)

---

## Caracteristicas

### Editor Visual de Etiquetas

Editor drag & drop basado en **Fabric.js** con preview en tiempo real.

| Funcionalidad | Descripcion |
|---------------|-------------|
| **Dimensiones** | 0-500mm, precision decimal |
| **Drag & Drop** | Arrastrar elementos desde paleta al canvas |
| **Preview Real** | QR y codigos de barras se generan mientras editas |
| **Validacion** | Formatos incompatibles se muestran deshabilitados |
| **Capas** | Sistema de z-index con panel de capas ordenable |
| **Zoom** | Ctrl + scroll para zoom, centrado inteligente |
| **Undo/Redo** | Historial de cambios completo |
| **Grid** | Snap to grid opcional |
| **Guardado** | Automatico, sin boton de guardar |

### Tipos de Elementos

```
+------------------+----------------------------------------+
|     ELEMENTO     |             PROPIEDADES                |
+------------------+----------------------------------------+
| Texto            | Fuente, tamano, peso, color,           |
|                  | alineacion, binding a datos            |
+------------------+----------------------------------------+
| Codigo QR        | Contenido, nivel de correccion (L/M/Q/H)|
|                  | Color de codigo, color de fondo        |
+------------------+----------------------------------------+
| Codigo de Barras | Formato (CODE128, CODE39, EAN-13,      |
|                  | EAN-8, UPC, ITF-14), mostrar texto,    |
|                  | color de codigo, color de fondo        |
+------------------+----------------------------------------+
| Linea            | Grosor, color                          |
+------------------+----------------------------------------+
| Rectangulo       | Relleno, borde, ancho de borde,        |
|                  | radio de esquinas (0-100%)             |
+------------------+----------------------------------------+
| Circulo/Elipse   | Redondez (0%=rect, 100%=elipse),       |
|                  | relleno, borde                         |
+------------------+----------------------------------------+
| Imagen           | Upload hasta 2MB, formatos comunes     |
+------------------+----------------------------------------+
```

### Validacion de Codigos de Barras

El sistema valida automaticamente el contenido segun el formato seleccionado:

| Formato | Requisitos | Ejemplo |
|---------|------------|---------|
| CODE128 | Cualquier caracter ASCII | `ABC-123` |
| CODE39 | A-Z, 0-9, espacio, -.$/ | `PROD-001` |
| EAN-13 | 12-13 digitos | `5901234123457` |
| EAN-8 | 7-8 digitos | `12345678` |
| UPC | 11-12 digitos | `012345678905` |
| ITF-14 | 13-14 digitos | `10012345678902` |

### Fuentes de Datos

- **Archivos**: Excel (.xlsx, .xls) y CSV
- **Bases de datos**: PostgreSQL, MySQL, SQL Server
- **Consultas SQL**: Editor con syntax highlighting
- **Seguridad**: Credenciales encriptadas con Cloak/AES-256

### Generacion de Etiquetas

```
+------------------+     +------------------+     +------------------+
|                  |     |                  |     |                  |
|  ETIQUETA SIMPLE |     |  MULTI-ETIQUETA  |     |    EXPORTAR      |
|                  |     |                  |     |                  |
|  - Estatica      |     |  - 1 por fila    |     |  - PDF           |
|  - Preview       |     |  - Binding datos |     |  - Impresion     |
|  - Edicion       |     |  - Excel/CSV/DB  |     |                  |
|                  |     |                  |     |                  |
+------------------+     +------------------+     +------------------+
```

### Seguridad

- **Autenticacion**: Email/password o Magic Link (sin password)
- **Roles**: Admin, Operator, Viewer con permisos granulares
- **RBAC**: Control de acceso basado en roles
- **Rate Limiting**: Proteccion contra ataques de fuerza bruta
- **Auditoria**: Logs completos de todas las acciones
- **Encriptacion**: Credenciales de BD encriptadas en reposo

---

## Demo

### Crear una Etiqueta con QR

1. Ir a **Disenos** > **Nuevo**
2. Configurar dimensiones (ej: 50x30mm)
3. Arrastrar elemento **QR** al canvas
4. Escribir contenido en el panel de propiedades
5. Ver el QR generarse en tiempo real

### Generar Etiquetas desde Excel

1. Ir a **Generar** > **Multiples etiquetas**
2. Subir archivo Excel
3. Seleccionar diseno existente
4. Mapear columnas a elementos (ej: columna "SKU" al elemento QR)
5. Click en **Generar** - cada fila crea una etiqueta unica

---

## Stack Tecnologico

### Backend

| Tecnologia | Version | Uso |
|------------|---------|-----|
| Elixir | 1.14+ | Lenguaje principal |
| Phoenix | 1.7 | Framework web |
| LiveView | 0.20 | UI reactiva sin JS |
| Ecto | 3.10 | ORM y migraciones |
| PostgreSQL | 14+ | Base de datos |
| Cloak | 1.1 | Encriptacion |
| Oban | 2.15 | Jobs en background |

### Frontend

| Tecnologia | Version | Uso |
|------------|---------|-----|
| Fabric.js | 5.3 | Canvas/editor |
| TailwindCSS | 3.3 | Estilos |
| qrcode.js | 1.5 | Generacion QR |
| JsBarcode | 3.11 | Generacion barcodes |
| jsPDF | 2.5 | Exportacion PDF |
| xlsx | 0.18 | Lectura Excel |

---

## Instalacion

### Requisitos Previos

- Elixir 1.14+ y Erlang/OTP 25+
- PostgreSQL 14+
- Node.js 18+

### Paso a Paso

```bash
# 1. Clonar repositorio
git clone https://github.com/ramoncoroso/qr-labels.git
cd qr_label_system

# 2. Instalar dependencias
mix deps.get
cd assets && npm install && cd ..

# 3. Configurar base de datos (editar si es necesario)
# config/dev.exs

# 4. Crear y migrar base de datos
mix ecto.setup

# 5. Iniciar servidor
mix phx.server
```

Abrir [http://localhost:4000](http://localhost:4000)

### Usuario Admin de Desarrollo

Para crear un usuario administrador en desarrollo, ejecuta los seeds:

```bash
mix run priv/repo/seeds.exs
```

Los seeds crean un usuario admin con credenciales configurables. Ver `priv/repo/seeds.exs` para detalles.

---

## Uso

### Estructura de Navegacion

```
/                     - Landing page
/users/log_in         - Login
/users/register       - Registro

/designs              - Lista de disenos
/designs/new          - Crear diseno
/designs/:id          - Ver diseno
/designs/:id/edit     - Editor visual

/data-sources         - Fuentes de datos
/data-sources/new     - Nueva fuente

/generate             - Generador de etiquetas

/admin/users          - Gestion de usuarios (admin)
/admin/audit          - Logs de auditoria (admin)
```

### Atajos de Teclado

| Atajo | Accion |
|-------|--------|
| `Ctrl+Z` | Deshacer |
| `Ctrl+Y` | Rehacer |
| `Delete` | Eliminar elemento |
| `Ctrl+D` | Duplicar elemento |
| `Ctrl+S` | Guardar (automatico) |
| `Ctrl+Scroll` | Zoom |

---

## Arquitectura

### Estructura de Directorios

```
qr_label_system/
├── lib/
│   ├── qr_label_system/           # Logica de negocio
│   │   ├── accounts/              # Usuarios, auth, tokens
│   │   ├── designs/               # Disenos y elementos
│   │   ├── data_sources/          # Excel, CSV, DB connections
│   │   ├── audit/                 # Logs de auditoria
│   │   └── vault.ex               # Encriptacion
│   │
│   └── qr_label_system_web/       # Capa web
│       ├── live/                  # LiveViews
│       │   ├── design_live/       # Editor de disenos
│       │   ├── data_source_live/  # Fuentes de datos
│       │   ├── generate_live/     # Generador
│       │   └── admin/             # Panel admin
│       └── plugs/                 # Middleware (RBAC, rate limit)
│
├── assets/js/hooks/               # LiveView Hooks
│   ├── canvas_designer.js         # Editor Fabric.js principal
│   ├── property_fields.js         # Preservacion de foco
│   ├── code_generator.js          # Generacion QR/barcode
│   ├── print_engine.js            # PDF e impresion
│   └── ...
│
└── test/                          # Tests
```

### Flujo de Datos del Editor

```
[Usuario modifica propiedad]
         |
         v
[phx-change/phx-blur event]
         |
         v
[LiveView: handle_event("update_element")]
         |
         +---> [Guardar en BD]
         |
         v
[push_event("update_element_property")]
         |
         v
[CanvasDesigner.updateSelectedElement()]
         |
         +---> [Aplicar cambio en Fabric.js]
         |
         +---> [Si es QR/barcode: recreateCodeElement()]
         |
         v
[canvas.renderAll()]
```

### LiveView Hooks

| Hook | Responsabilidad |
|------|-----------------|
| `CanvasDesigner` | Editor principal, QR/barcode real |
| `PropertyFields` | Preservar foco durante re-renders |
| `BorderRadiusSlider` | Slider suave para redondez |
| `DraggableElements` | Drag & drop al canvas |
| `CodeGenerator` | Generacion para impresion |
| `PrintEngine` | Exportacion PDF |
| `ExcelReader` | Lectura de archivos Excel |
| `SortableLayers` | Ordenamiento de capas |
| `KeyboardShortcuts` | Atajos de teclado |

---

## API

### Health Check

```bash
# Basico
curl http://localhost:4000/api/health
# {"status": "ok"}

# Detallado (requiere auth)
curl -H "Authorization: Bearer TOKEN" \
     http://localhost:4000/api/health/detailed
```

---

## Tests

```bash
# Ejecutar todos los tests
mix test

# Con coverage
mix test --cover

# Tests especificos
mix test test/qr_label_system/designs_test.exs

# Solo tests de integracion
mix test test/qr_label_system_web/integration/
```

**Estado actual**: 667 tests, 0 failures

---

## Despliegue

### Variables de Entorno

```bash
# Requeridas
DATABASE_URL=ecto://user:pass@host:5432/qr_label_system
SECRET_KEY_BASE=$(mix phx.gen.secret)
PHX_HOST=labels.example.com

# Opcionales
PORT=4000
POOL_SIZE=10
```

### Compilar Release

```bash
# Compilar assets
cd assets && npm run deploy && cd ..
mix phx.digest

# Crear release
MIX_ENV=prod mix release
```

### Docker

```bash
cd docker
docker-compose up -d
```

### Docker Compose

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "4000:4000"
    environment:
      DATABASE_URL: ecto://postgres:postgres@db/qr_label_system
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
    depends_on:
      - db

  db:
    image: postgres:14-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: postgres

volumes:
  pgdata:
```

---

## Contribuir

1. Fork del repositorio
2. Crear branch: `git checkout -b feature/mi-feature`
3. Commit: `git commit -m 'feat: descripcion'`
4. Push: `git push origin feature/mi-feature`
5. Crear Pull Request

### Convenciones de Commits

```
feat:     Nueva funcionalidad
fix:      Correccion de bug
docs:     Documentacion
refactor: Refactorizacion
test:     Tests
chore:    Mantenimiento
```

---

## Documentacion Adicional

- **[HANDOFF.md](HANDOFF.md)** - Historial detallado de cambios y estado actual
- **[docs/](docs/)** - Documentacion adicional

---

## Licencia

Propietario - Uso interno

---

## Changelog Reciente

### v0.8.0 (1 Feb 2026)

**Fix sincronizacion de propiedades canvas**

- QR: `qr_error_level` ahora se aplica al regenerar
- QR/Barcode: Cambiar colores regenera el codigo
- Barcode: `barcode_show_text` funciona correctamente
- Rectangle: Nuevo slider para `border_radius`
- Line: Nuevo control de grosor

**Nuevos controles UI**

- Color pickers para QR y Barcode
- Slider de radio de borde para rectangulos
- Input de grosor para lineas

### v0.7.0 (1 Feb 2026)

- Preview real de QR en canvas
- Preview real de codigos de barras
- Validacion de formatos de barcode
- PropertyFields hook para preservar foco

---

*Desarrollado con Elixir y Phoenix LiveView*
