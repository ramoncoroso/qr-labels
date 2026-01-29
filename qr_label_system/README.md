# QR Label System

Sistema web para diseñar y generar etiquetas personalizadas con códigos QR y de barras.

## Características

- Editor visual de etiquetas con drag & drop (Fabric.js)
- Dimensiones personalizables (cualquier tamaño en mm)
- Soporte para códigos QR y múltiples formatos de código de barras
- Importación de datos desde Excel/CSV
- Conexión a bases de datos externas (PostgreSQL, MySQL, SQL Server)
- Generación de códigos QR/barras en el navegador (client-side)
- Cada fila de datos = una etiqueta única con códigos únicos
- Exportación a PDF
- Impresión directa compatible con cualquier impresora
- Sistema de autenticación con roles
- Logs de auditoría

## Requisitos

- Elixir 1.14+
- Erlang/OTP 25+
- PostgreSQL 14+
- Node.js 18+

## Instalación

1. Instalar dependencias de Elixir:
```bash
mix deps.get
```

2. Instalar dependencias de JavaScript:
```bash
cd assets && npm install && cd ..
```

3. Configurar la base de datos en `config/dev.exs`

4. Crear y migrar la base de datos:
```bash
mix ecto.setup
```

5. Iniciar el servidor:
```bash
mix phx.server
```

Acceder a [`localhost:4000`](http://localhost:4000) en el navegador.

## Credenciales por defecto (desarrollo)

- Email: admin@example.com
- Password: admin123456

## Estructura del proyecto

```
lib/
├── qr_label_system/           # Lógica de negocio
│   ├── accounts/              # Usuarios y autenticación
│   ├── designs/               # Diseños de etiquetas
│   ├── data_sources/          # Fuentes de datos (Excel, BD)
│   ├── batches/               # Lotes de etiquetas
│   └── audit/                 # Logs de auditoría
│
└── qr_label_system_web/       # Capa web
    ├── components/            # Componentes reutilizables
    ├── controllers/           # Controladores
    └── live/                  # LiveViews
        ├── design_live/       # Editor de diseños
        ├── data_source_live/  # Gestión de fuentes
        ├── batch_live/        # Gestión de lotes
        └── generate_live/     # Flujo de generación

assets/
├── js/
│   └── hooks/                 # LiveView Hooks
│       ├── canvas_designer.js # Editor visual
│       ├── code_generator.js  # Generación QR/barras
│       ├── print_engine.js    # Impresión y PDF
│       └── excel_reader.js    # Lectura de Excel
└── css/
    └── app.css               # Estilos (Tailwind)
```

## Flujo de trabajo

1. **Crear diseño**: Define dimensiones y agrega elementos (QR, barras, texto, etc.)
2. **Importar datos**: Sube Excel/CSV o conecta a base de datos externa
3. **Mapear columnas**: Vincula elementos del diseño a columnas de datos
4. **Generar lote**: Crea un lote con N etiquetas (una por fila de datos)
5. **Imprimir/Exportar**: Imprime directamente o exporta a PDF

## Tecnologías

- **Backend**: Elixir, Phoenix Framework, Phoenix LiveView
- **Base de datos**: PostgreSQL con Ecto
- **Frontend**: Tailwind CSS, Fabric.js
- **Generación de códigos**: qrcode.js, JsBarcode (client-side)
- **PDF**: jsPDF
- **Excel**: Xlsxir (server), xlsx (client)

## Producción

Para desplegar en producción:

```bash
# Compilar assets
cd assets && npm run deploy && cd ..
mix phx.digest

# Compilar release
MIX_ENV=prod mix release
```

## Licencia

Propietario - Uso interno
