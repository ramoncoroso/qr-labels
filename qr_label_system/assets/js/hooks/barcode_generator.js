/**
 * Barcode Generator Module
 * Shared module for generating QR codes and barcodes using bwip-js.
 *
 * Used by: canvas_designer, label_preview, print_engine, single_label_print, code_generator
 */

import bwipjs from 'bwip-js'

const MM_TO_PX = 3.78

// Map our format names to bwip-js bcid values
const FORMAT_MAP = {
  // 1D General
  'CODE128': 'code128',
  'CODE39': 'code39',
  'CODE93': 'code93',
  'CODABAR': 'rationalizedCodabar',
  'MSI': 'msi',
  'pharmacode': 'pharmacode',
  // 1D Retail
  'EAN13': 'ean13',
  'EAN8': 'ean8',
  'UPC': 'upca',
  'ITF14': 'itf14',
  'GS1_DATABAR': 'databaromni',
  'GS1_DATABAR_STACKED': 'databarstacked',
  'GS1_DATABAR_EXPANDED': 'databarexpanded',
  // 1D Supply Chain
  'GS1_128': 'gs1-128',
  // 2D
  'DATAMATRIX': 'datamatrix',
  'PDF417': 'pdf417',
  'AZTEC': 'azteccode',
  'MAXICODE': 'maxicode',
  // Postal
  'POSTNET': 'postnet',
  'PLANET': 'planet',
  'ROYALMAIL': 'royalmail4state',
}

// 2D formats don't have text below and use square-ish placeholders
const FORMATS_2D = new Set(['DATAMATRIX', 'PDF417', 'AZTEC', 'MAXICODE'])

/**
 * Check if a format is 2D (matrix-type)
 */
export function is2DFormat(format) {
  return FORMATS_2D.has(format)
}

/**
 * Get grouped format definitions for UI dropdowns
 */
export function getFormatGroups() {
  return [
    {
      label: '1D General',
      formats: [
        { value: 'CODE128', label: 'CODE128' },
        { value: 'CODE39', label: 'CODE39' },
        { value: 'CODE93', label: 'CODE93' },
        { value: 'CODABAR', label: 'Codabar' },
        { value: 'MSI', label: 'MSI' },
        { value: 'pharmacode', label: 'Pharmacode' },
      ]
    },
    {
      label: '1D Retail',
      formats: [
        { value: 'EAN13', label: 'EAN-13' },
        { value: 'EAN8', label: 'EAN-8' },
        { value: 'UPC', label: 'UPC-A' },
        { value: 'ITF14', label: 'ITF-14' },
        { value: 'GS1_DATABAR', label: 'GS1 DataBar' },
        { value: 'GS1_DATABAR_STACKED', label: 'GS1 DataBar Stacked' },
        { value: 'GS1_DATABAR_EXPANDED', label: 'GS1 DataBar Expanded' },
      ]
    },
    {
      label: '1D Supply Chain',
      formats: [
        { value: 'GS1_128', label: 'GS1-128' },
      ]
    },
    {
      label: '2D',
      formats: [
        { value: 'DATAMATRIX', label: 'DataMatrix' },
        { value: 'PDF417', label: 'PDF417' },
        { value: 'AZTEC', label: 'Aztec' },
        { value: 'MAXICODE', label: 'MaxiCode' },
      ]
    },
    {
      label: 'Postal',
      formats: [
        { value: 'POSTNET', label: 'POSTNET' },
        { value: 'PLANET', label: 'PLANET' },
        { value: 'ROYALMAIL', label: 'Royal Mail' },
      ]
    }
  ]
}

/**
 * Get detailed format info for a barcode format (for badges and info cards)
 * @param {string} format - Format key (e.g. 'CODE128', 'EAN13')
 * @returns {Object|null} Format metadata or null if unknown
 */
export function getFormatInfo(format) {
  const FORMATS = {
    // 1D General — blue
    'CODE128': {
      name: 'CODE128', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (uso general)',
      capacity: 'ASCII completo, longitud variable',
      usage: 'Logística, inventario, etiquetas internas',
      extra: 'El más versátil de los códigos 1D'
    },
    'CODE39': {
      name: 'CODE39', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (uso general)',
      capacity: 'A-Z, 0-9, -.$/+%, longitud variable',
      usage: 'Industria automotriz, defensa, salud',
      extra: 'Auto-delimitable, no requiere checksum'
    },
    'CODE93': {
      name: 'CODE93', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (uso general)',
      capacity: 'A-Z, 0-9, -.$/+%, longitud variable',
      usage: 'Correo canadiense, logística',
      extra: 'Más compacto que CODE39'
    },
    'CODABAR': {
      name: 'Codabar', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (uso general)',
      capacity: '0-9, -$:/.+, inicio/fin A-D',
      usage: 'Bibliotecas, bancos de sangre, paquetería',
      extra: 'Requiere caracteres de inicio/fin (A-D)'
    },
    'MSI': {
      name: 'MSI', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (uso general)',
      capacity: 'Solo dígitos, longitud variable',
      usage: 'Estantes de supermercado, inventario',
      extra: 'Variante de Plessey, requiere checksum'
    },
    'pharmacode': {
      name: 'Pharmacode', category: '1D General',
      badge: { bg: '#eff6ff', text: '#3b82f6', border: '#93c5fd' },
      type: 'Código 1D lineal (farmacéutico)',
      capacity: 'Número entre 3-131070',
      usage: 'Industria farmacéutica (empaque)',
      extra: 'Diseñado para ser leído incluso mal impreso'
    },
    // 1D Retail — green
    'EAN13': {
      name: 'EAN-13', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal (retail)',
      capacity: '12-13 dígitos (incluye checksum)',
      usage: 'Productos de consumo a nivel mundial',
      extra: 'Estándar global de punto de venta'
    },
    'EAN8': {
      name: 'EAN-8', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal (retail)',
      capacity: '7-8 dígitos (incluye checksum)',
      usage: 'Productos pequeños con espacio limitado',
      extra: 'Versión compacta de EAN-13'
    },
    'UPC': {
      name: 'UPC-A', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal (retail)',
      capacity: '11-12 dígitos (incluye checksum)',
      usage: 'Productos de consumo en Norteamérica',
      extra: 'Estándar de EE.UU. y Canadá'
    },
    'ITF14': {
      name: 'ITF-14', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal (retail/logística)',
      capacity: '13-14 dígitos',
      usage: 'Cajas y embalaje exterior (GTIN)',
      extra: 'Imprimible directo en cartón corrugado'
    },
    'GS1_DATABAR': {
      name: 'GS1 DataBar', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal (retail)',
      capacity: '13-14 dígitos (GTIN)',
      usage: 'Productos frescos, cupones',
      extra: 'Más compacto que EAN/UPC'
    },
    'GS1_DATABAR_STACKED': {
      name: 'GS1 DB Stacked', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D apilado (retail)',
      capacity: '13-14 dígitos (GTIN)',
      usage: 'Productos muy pequeños (frutas, verduras)',
      extra: 'Versión apilada, ocupa menos ancho'
    },
    'GS1_DATABAR_EXPANDED': {
      name: 'GS1 DB Exp.', category: '1D Retail',
      badge: { bg: '#ecfdf5', text: '#10b981', border: '#6ee7b7' },
      type: 'Código 1D lineal expandido (retail)',
      capacity: 'AI + datos variables',
      usage: 'Productos con peso, fecha de vencimiento',
      extra: 'Soporta datos adicionales GS1 (lote, peso, fecha)'
    },
    // 1D Supply Chain — cyan
    'GS1_128': {
      name: 'GS1-128', category: '1D Supply Chain',
      badge: { bg: '#ecfeff', text: '#06b6d4', border: '#67e8f9' },
      type: 'Código 1D lineal (cadena de suministro)',
      capacity: 'AI + datos, hasta ~48 caracteres',
      usage: 'Pallets, cajas, trazabilidad logística',
      extra: 'Estándar GS1 para cadena de suministro'
    },
    // 2D — amber
    'DATAMATRIX': {
      name: 'DataMatrix', category: '2D',
      badge: { bg: '#fffbeb', text: '#f59e0b', border: '#fcd34d' },
      type: 'Código 2D matricial',
      capacity: 'Hasta 2335 alfanuméricos',
      usage: 'Electrónica, componentes pequeños, salud',
      extra: 'Legible incluso con daño parcial'
    },
    'PDF417': {
      name: 'PDF417', category: '2D',
      badge: { bg: '#fffbeb', text: '#f59e0b', border: '#fcd34d' },
      type: 'Código 2D apilado',
      capacity: 'Hasta 1850 alfanuméricos',
      usage: 'Documentos de identidad, boarding passes',
      extra: 'Puede enlazar múltiples símbolos'
    },
    'AZTEC': {
      name: 'Aztec', category: '2D',
      badge: { bg: '#fffbeb', text: '#f59e0b', border: '#fcd34d' },
      type: 'Código 2D matricial',
      capacity: 'Hasta 3832 alfanuméricos',
      usage: 'Billetes de transporte, boletos',
      extra: 'No requiere zona blanca alrededor'
    },
    'MAXICODE': {
      name: 'MaxiCode', category: '2D',
      badge: { bg: '#fffbeb', text: '#f59e0b', border: '#fcd34d' },
      type: 'Código 2D hexagonal',
      capacity: 'Hasta 93 alfanuméricos',
      usage: 'Paquetería (UPS), clasificación automática',
      extra: 'Tamaño fijo, lectura a alta velocidad'
    },
    // Postal — pink
    'POSTNET': {
      name: 'POSTNET', category: 'Postal',
      badge: { bg: '#fdf2f8', text: '#ec4899', border: '#f9a8d4' },
      type: 'Código postal de barras',
      capacity: '5, 9 u 11 dígitos',
      usage: 'Correo de EE.UU. (USPS)',
      extra: 'Codifica ZIP, ZIP+4 o DPBC'
    },
    'PLANET': {
      name: 'PLANET', category: 'Postal',
      badge: { bg: '#fdf2f8', text: '#ec4899', border: '#f9a8d4' },
      type: 'Código postal de barras',
      capacity: '11 o 13 dígitos',
      usage: 'Rastreo de correo USPS',
      extra: 'Complemento de POSTNET para tracking'
    },
    'ROYALMAIL': {
      name: 'Royal Mail', category: 'Postal',
      badge: { bg: '#fdf2f8', text: '#ec4899', border: '#f9a8d4' },
      type: 'Código postal 4-state',
      capacity: 'Alfanumérico, longitud variable',
      usage: 'Correo de Reino Unido (Royal Mail)',
      extra: 'Barras de 4 alturas diferentes'
    }
  }

  return FORMATS[format] || null
}

/**
 * Strip '#' from hex color for bwip-js (expects "000000" not "#000000")
 */
function toBwipColor(hex) {
  if (!hex) return undefined
  return hex.replace(/^#/, '')
}

/**
 * Generate a QR code as a data URL using bwip-js
 * @param {string} content - The text to encode
 * @param {Object} config - Element config with width, qr_error_level, color, background_color, qr_logo_data, qr_logo_size
 * @param {Object} [options] - Additional options
 * @param {number} [options.scale] - Scale multiplier for output size
 * @param {number} [options.sizePx] - Explicit size in pixels (overrides config.width * MM_TO_PX * scale)
 * @returns {Promise<string|null>} Data URL or null on error
 */
export async function generateQR(content, config, options = {}) {
  try {
    const scale = options.scale || 1
    const targetSize = options.sizePx || Math.round((config.width || 20) * MM_TO_PX * scale)

    // Force error level H when logo is present (need max redundancy)
    const hasLogo = config.qr_logo_data
    const eclevel = hasLogo ? 'H' : (config.qr_error_level || 'M')

    const canvas = document.createElement('canvas')

    bwipjs.toCanvas(canvas, {
      bcid: 'qrcode',
      text: String(content),
      scale: Math.max(1, Math.round(targetSize / 40)),
      eclevel: eclevel,
      barcolor: toBwipColor(config.color || '#000000'),
      backgroundcolor: toBwipColor(config.background_color || '#ffffff'),
      padding: 0,
    })

    // Scale the canvas to the exact target size
    const outputCanvas = document.createElement('canvas')
    outputCanvas.width = targetSize
    outputCanvas.height = targetSize
    const ctx = outputCanvas.getContext('2d')

    // Fill background
    ctx.fillStyle = config.background_color || '#ffffff'
    ctx.fillRect(0, 0, targetSize, targetSize)

    // Draw QR centered/scaled
    ctx.drawImage(canvas, 0, 0, targetSize, targetSize)

    // Overlay logo if present
    if (hasLogo) {
      await overlayLogo(ctx, config.qr_logo_data, targetSize, config.qr_logo_size || 25)
    }

    return outputCanvas.toDataURL('image/png')
  } catch (err) {
    console.error('Error generating QR:', err)
    return null
  }
}

/**
 * Overlay a logo image centered on the QR code
 */
async function overlayLogo(ctx, logoData, qrSize, logoSizePercent) {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => {
      const logoSize = Math.round(qrSize * (logoSizePercent / 100))
      const x = Math.round((qrSize - logoSize) / 2)
      const y = Math.round((qrSize - logoSize) / 2)
      const padding = Math.round(logoSize * 0.1)

      // White background behind logo
      ctx.fillStyle = '#ffffff'
      ctx.fillRect(x - padding, y - padding, logoSize + padding * 2, logoSize + padding * 2)

      // Draw logo
      ctx.drawImage(img, x, y, logoSize, logoSize)
      resolve()
    }
    img.onerror = () => {
      console.warn('Failed to load QR logo image')
      resolve()
    }
    img.src = logoData
  })
}

/**
 * Generate a barcode as a data URL using bwip-js
 * @param {string} content - The text to encode
 * @param {Object} config - Element config with barcode_format, height, barcode_show_text, color, background_color
 * @param {Object} [options] - Additional options
 * @param {number} [options.scale] - Scale multiplier for output size
 * @param {number} [options.barWidth] - Not used with bwip-js (kept for API compat)
 * @param {number} [options.heightPx] - Explicit height in pixels (overrides config.height * MM_TO_PX * scale)
 * @param {number} [options.fontSize] - Font size for text display
 * @param {number} [options.margin] - Padding around barcode in px
 * @returns {string|null} Data URL or null on error
 */
export function generateBarcode(content, config, options = {}) {
  try {
    const scale = options.scale || 1
    const format = config.barcode_format || 'CODE128'
    const bcid = FORMAT_MAP[format]
    if (!bcid) {
      console.error(`Unknown barcode format: ${format}`)
      return null
    }

    const heightPx = options.heightPx || Math.round((config.height || 15) * MM_TO_PX * scale)
    // bwip-js height is in mm, convert from pixels
    const heightMM = heightPx / MM_TO_PX
    const showText = config.barcode_show_text !== false && !is2DFormat(format)
    const padding = options.margin != null ? options.margin : 0

    const canvas = document.createElement('canvas')

    const bwipOpts = {
      bcid: bcid,
      text: String(content),
      height: heightMM,
      includetext: showText,
      textsize: options.fontSize || 10,
      barcolor: toBwipColor(config.color || '#000000'),
      backgroundcolor: toBwipColor(config.background_color || '#ffffff'),
      padding: Math.round(padding / MM_TO_PX),
    }

    // Some formats need specific options
    if (format === 'GS1_128') {
      bwipOpts.parse = true
    }

    bwipjs.toCanvas(canvas, bwipOpts)

    return canvas.toDataURL('image/png')
  } catch (err) {
    console.error('Error generating barcode:', err)
    return null
  }
}

/**
 * Validate barcode content for a specific format
 * @param {string} content - The barcode content
 * @param {string} format - The barcode format (e.g., 'CODE128', 'EAN13')
 * @returns {{ valid: boolean, error?: string }}
 */
export function validateBarcodeContent(content, format) {
  const digitsOnly = /^\d+$/
  const alphanumeric = /^[A-Z0-9\s\-\.$/+%]+$/i

  switch (format) {
    case 'EAN13':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'EAN-13: solo dígitos' }
      }
      if (content.length !== 12 && content.length !== 13) {
        return { valid: false, error: 'EAN-13: 12-13 dígitos' }
      }
      return { valid: true }

    case 'EAN8':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'EAN-8: solo dígitos' }
      }
      if (content.length !== 7 && content.length !== 8) {
        return { valid: false, error: 'EAN-8: 7-8 dígitos' }
      }
      return { valid: true }

    case 'UPC':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'UPC: solo dígitos' }
      }
      if (content.length !== 11 && content.length !== 12) {
        return { valid: false, error: 'UPC: 11-12 dígitos' }
      }
      return { valid: true }

    case 'ITF14':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'ITF-14: solo dígitos' }
      }
      if (content.length !== 13 && content.length !== 14) {
        return { valid: false, error: 'ITF-14: 13-14 dígitos' }
      }
      return { valid: true }

    case 'CODE39':
      if (!alphanumeric.test(content)) {
        return { valid: false, error: 'CODE39: A-Z, 0-9, -.$/' }
      }
      return { valid: true }

    case 'CODE93':
      if (!alphanumeric.test(content)) {
        return { valid: false, error: 'CODE93: A-Z, 0-9, -.$/' }
      }
      return { valid: true }

    case 'MSI':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'MSI: solo dígitos' }
      }
      return { valid: true }

    case 'CODABAR':
      if (!/^[A-Da-d][0-9\-$:/.+]+[A-Da-d]$/i.test(content)) {
        return { valid: false, error: 'Codabar: dígitos con inicio/fin A-D' }
      }
      return { valid: true }

    case 'GS1_128':
      if (!content || content.length < 2) {
        return { valid: false, error: 'GS1-128: requiere AI + datos' }
      }
      return { valid: true }

    case 'GS1_DATABAR':
    case 'GS1_DATABAR_STACKED':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'GS1 DataBar: solo dígitos' }
      }
      if (content.length !== 13 && content.length !== 14) {
        return { valid: false, error: 'GS1 DataBar: 13-14 dígitos (GTIN)' }
      }
      return { valid: true }

    case 'GS1_DATABAR_EXPANDED':
      if (!content || content.length < 2) {
        return { valid: false, error: 'GS1 DataBar Expanded: requiere AI + datos' }
      }
      return { valid: true }

    case 'POSTNET':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'POSTNET: solo dígitos' }
      }
      if (![5, 9, 11].includes(content.length)) {
        return { valid: false, error: 'POSTNET: 5, 9 u 11 dígitos' }
      }
      return { valid: true }

    case 'PLANET':
      if (!digitsOnly.test(content)) {
        return { valid: false, error: 'PLANET: solo dígitos' }
      }
      if (![11, 13].includes(content.length)) {
        return { valid: false, error: 'PLANET: 11 o 13 dígitos' }
      }
      return { valid: true }

    case 'ROYALMAIL':
      if (!/^[A-Z0-9]+$/i.test(content)) {
        return { valid: false, error: 'Royal Mail: alfanumérico' }
      }
      return { valid: true }

    case 'DATAMATRIX':
    case 'PDF417':
    case 'AZTEC':
    case 'MAXICODE':
      // 2D formats accept almost any text
      return { valid: true }

    case 'CODE128':
    case 'pharmacode':
    default:
      return { valid: true }
  }
}
