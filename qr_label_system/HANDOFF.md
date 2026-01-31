# Handoff: Sistema de Generación de Etiquetas QR

## Resumen del Proyecto

Sistema web para crear y generar etiquetas con códigos QR, códigos de barras y texto dinámico. Construido con **Elixir/Phoenix LiveView**.

## Lo Que Se Implementó

### Rediseño del Flujo de Generación de Etiquetas

Se implementó un nuevo flujo con dos modos de operación:

#### 1. Modo Etiqueta Única (`/generate/single`)
- Seleccionar o crear un diseño
- Configurar cantidad (1-100 copias)
- Imprimir directamente o descargar PDF
- Contenido estático definido en el diseño

#### 2. Modo Múltiples Etiquetas (`/generate/data`) - **DATOS PRIMERO**
- Cargar datos antes de elegir diseño
- 3 métodos de carga:
  - **Excel** (.xlsx)
  - **CSV** (.csv)
  - **Pegar desde Excel** (copiar/pegar datos tabulares)
- Vista previa de columnas y datos
- Seleccionar diseño existente o crear nuevo
- Vinculación automática de columnas a elementos

### Archivos Creados

```
lib/qr_label_system_web/live/generate_live/
├── index.ex          # Selector de modo (único vs múltiples)
├── data_first.ex     # Carga de datos (Excel/CSV/pegar)
├── design_select.ex  # Selección de diseño tras cargar datos
├── single_select.ex  # Selección de diseño para etiqueta única
└── single_label.ex   # Configuración e impresión de etiqueta única

assets/js/hooks/
└── single_label_print.js  # Hook para impresión/PDF de etiquetas únicas

test/
├── qr_label_system_web/live/generate_live_test.exs  # 10 tests nuevos
└── support/fixtures/designs_fixtures.ex             # Fixtures para tests
```

### Archivos Modificados

- `router.ex` - 4 nuevas rutas
- `design_live/editor.ex` - Dropdown de columnas + panel de columnas disponibles
- `hooks/index.js` - Registro del nuevo hook
- Tests de autenticación - Actualizado redirect a `/generate`

### Rutas Disponibles

| Ruta | Descripción |
|------|-------------|
| `/generate` | Selector de modo |
| `/generate/single` | Selección de diseño (modo único) |
| `/generate/single/:id` | Impresión de etiqueta única |
| `/generate/data` | Carga de datos (modo múltiples) |
| `/generate/design` | Selección de diseño tras cargar datos |
| `/generate/design/:id` | (existente) Fuente de datos |
| `/generate/map/:design_id/:source_id` | (existente) Mapeo de columnas |
| `/generate/preview/:batch_id` | (existente) Vista previa del lote |

## Estado Actual

### Funcionando ✅
- Selector de modo en `/generate`
- Flujo de etiqueta única completo
- Carga de datos (Excel, CSV, pegar)
- Vista previa de datos cargados
- Dropdown de columnas en el editor
- Panel de columnas disponibles en sidebar
- Todos los tests pasan (175 tests)

### Pendiente / Para Continuar 🔄

#### 1. Integración del Editor con Datos
El editor actualmente carga columnas del flash, pero el flujo completo necesita:
- Permitir crear nuevo diseño desde `/generate/design` y mantener los datos
- Al guardar diseño, redirigir de vuelta al flujo de generación

#### 2. Mejorar el Mapeo Automático
En `design_select.ex`, la función `build_auto_mapping/2` hace mapeo case-insensitive. Considerar:
- Mostrar al usuario qué columnas se mapearon automáticamente
- Permitir corrección manual antes de crear el lote

#### 3. Vista Previa en Tiempo Real
En el editor, cuando hay columnas disponibles:
- Mostrar preview con datos reales del primer registro
- Permitir navegar entre registros para previsualizar

#### 4. Configuración de Impresión
El `SingleLabel` tiene configuración básica. Agregar:
- Selección de tamaño de papel
- Configuración de márgenes
- Opciones para impresora de rollo vs normal

#### 5. Eliminar Soporte de Base de Datos
El plan original indicaba eliminar PostgreSQL/MySQL/SQL Server como fuentes de datos. Actualmente aún existen en:
- `lib/qr_label_system/data_sources/db_connector.ex`
- `lib/qr_label_system/data_sources.ex`

## Cómo Ejecutar

```bash
# Instalar dependencias
mix deps.get
cd assets && npm install && cd ..

# Configurar base de datos
mix ecto.setup

# Ejecutar servidor
mix phx.server

# Abrir en navegador
open http://localhost:4000
```

## Cómo Testear

```bash
# Todos los tests
mix test

# Solo tests del flujo de generación
mix test test/qr_label_system_web/live/generate_live_test.exs

# Con cobertura
mix coveralls.html
```

## Datos de Prueba

Se incluyen archivos de prueba en `/priv/`:
- `test_data.xlsx` - Excel con 10 productos
- `test_data.csv` - CSV con los mismos datos

Columnas: Producto, SKU, Precio, Descripcion, Cantidad

## Arquitectura

```
Usuario llega a /generate
         │
         ├─── "Etiqueta Única" ───► /generate/single
         │                              │
         │                              ▼
         │                    Seleccionar diseño
         │                              │
         │                              ▼
         │                    /generate/single/:id
         │                    (configurar e imprimir)
         │
         └─── "Múltiples" ───► /generate/data
                                   │
                                   ▼
                          Cargar datos (Excel/CSV/Pegar)
                                   │
                                   ▼
                          /generate/design
                          (seleccionar diseño)
                                   │
                                   ▼
                          Crear Batch con data_snapshot
                                   │
                                   ▼
                          /generate/preview/:batch_id
                          (vista previa e impresión)
```

## Notas Técnicas

### Flash para Pasar Datos Entre Páginas
Los datos cargados se pasan via `put_flash`:
```elixir
socket
|> put_flash(:upload_data, rows)
|> put_flash(:upload_columns, columns)
|> push_navigate(to: ~p"/generate/design")
```

Y se recuperan con:
```elixir
Phoenix.Flash.get(socket.assigns.flash, :upload_data)
```

### Parser de Datos Pegados
En `data_first.ex`, la función `parse_pasted_data/1`:
- Divide por líneas (`\r?\n`)
- Primera línea = headers
- Divide cada línea por tabs (`\t`)
- Construye lista de mapas

### Batch con Data Snapshot
Al crear un batch, se guarda una copia de los datos:
```elixir
%{
  name: "Lote - #{design.name} - #{timestamp}",
  design_id: design.id,
  column_mapping: auto_mapping,
  data_snapshot: upload_data,  # Copia de los datos
  total_labels: length(upload_data)
}
```

## Contacto

Este handoff fue creado el 31 de enero de 2026.
Para dudas sobre la implementación, revisar los commits recientes o los tests.
