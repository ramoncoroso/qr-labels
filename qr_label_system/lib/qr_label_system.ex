defmodule QrLabelSystem do
  @moduledoc """
  QrLabelSystem - Sistema de Generación de Etiquetas QR

  Aplicación web para diseñar y generar etiquetas personalizadas
  con códigos QR y de barras. Permite importar datos desde Excel
  o bases de datos externas y generar etiquetas únicas para cada registro.

  ## Características principales

  - Editor visual de etiquetas con drag & drop
  - Soporte para códigos QR y múltiples formatos de código de barras
  - Importación de datos desde Excel/CSV
  - Conexión a bases de datos externas (PostgreSQL, MySQL, SQL Server)
  - Generación de códigos en el navegador (client-side)
  - Exportación a PDF e impresión directa
  - Sistema de autenticación con roles
  - Logs de auditoría

  ## Arquitectura

  La aplicación sigue la arquitectura de Phoenix con contextos separados:

  - `Accounts` - Gestión de usuarios y autenticación
  - `Designs` - Diseños de etiquetas
  - `DataSources` - Fuentes de datos (Excel, BD externas)
  - `Batches` - Configuraciones de impresión
  - `Audit` - Registro de actividad
  """
end
