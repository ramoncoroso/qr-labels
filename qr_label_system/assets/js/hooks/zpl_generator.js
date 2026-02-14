/**
 * ZPL Generator — Client-side port of ZplGenerator (Elixir)
 *
 * Generates ZPL (Zebra Programming Language) code from label designs.
 * Uses expression_engine.js for resolving bindings and expressions.
 */

import { resolveText, resolveCodeValue } from './expression_engine'

// Dots per mm for each DPI setting
const DPI_MAP = { 203: 8, 300: 12, 600: 24 }

// Average character width as ratio of font height (monospace ~0.6)
const AVG_CHAR_WIDTH_RATIO = 0.6

/**
 * Generate ZPL for a single label.
 * @param {object} design - Design object with elements, width_mm, height_mm
 * @param {object} row - Data row (column name → value)
 * @param {object} opts - Options: { dpi, rowIndex, batchSize, mapping }
 * @returns {string} ZPL code for one label
 */
export function generateZpl(design, row = {}, opts = {}) {
  const dpi = opts.dpi || 203
  const dpmm = DPI_MAP[dpi] || 8
  const rowIndex = opts.rowIndex || 0
  const batchSize = opts.batchSize || 1
  const mapping = opts.mapping || {}
  const language = opts.language || null
  const defaultLanguage = opts.defaultLanguage || 'es'
  const context = { rowIndex, batchSize, now: new Date(), language, defaultLanguage }

  const wDots = mmToDots(design.width_mm, dpmm)
  const hDots = mmToDots(design.height_mm, dpmm)

  const elements = (design.elements || [])
    .slice()
    .sort((a, b) => (a.z_index || 0) - (b.z_index || 0))

  const elementsZpl = elements
    .map(el => elementToZpl(el, row, context, dpmm, mapping))
    .filter(Boolean)
    .join('\n')

  return `^XA\n^PW${wDots}\n^LL${hDots}\n${elementsZpl}\n^XZ`
}

/**
 * Generate ZPL for a batch of labels (concatenated).
 * @param {object} design - Design object
 * @param {Array} rows - Array of data rows
 * @param {object} opts - Options: { dpi, mapping }
 * @returns {string} Concatenated ZPL
 */
export function generateBatchZpl(design, rows, opts = {}) {
  const batchSize = rows.length
  return rows
    .map((row, idx) => generateZpl(design, row, { ...opts, rowIndex: idx, batchSize }))
    .join('\n')
}

// ── Element → ZPL ───────────────────────────────────────────

function elementToZpl(element, row, context, dpmm, mapping) {
  const x = mmToDots(element.x || 0, dpmm)
  const y = mmToDots(element.y || 0, dpmm)

  switch (element.type) {
    case 'text': return textToZpl(element, row, context, x, y, dpmm, mapping)
    case 'barcode': return barcodeToZpl(element, row, context, x, y, dpmm, mapping)
    case 'qr': return qrToZpl(element, row, context, x, y, dpmm, mapping)
    case 'rectangle': return rectangleToZpl(element, x, y, dpmm)
    case 'line': return lineToZpl(element, x, y, dpmm)
    case 'circle': return circleToZpl(element, x, y, dpmm)
    case 'image': return imagePlaceholderToZpl(element, x, y, dpmm)
    default: return null
  }
}

// ── Text ─────────────────────────────────────────────────────

function textToZpl(element, row, context, x, y, dpmm, mapping) {
  let text = resolveText(element, row, mapping, context)
  text = escapeZpl(text)

  // Font height in dots (canvas font_size is in px at 6px/mm)
  let fontH = mmToDots((element.font_size || 10) / 6, dpmm)

  // Auto-fit: reduce font size if text overflows bounding box
  if (element.text_auto_fit && text) {
    const boxW = mmToDots(element.width || 60, dpmm)
    const boxH = mmToDots(element.height || 14, dpmm)
    const minFontH = mmToDots((element.text_min_font_size || 6) / 6, dpmm)
    fontH = calcAutoFitFontDots(text, boxW, boxH, fontH, Math.max(minFontH, 1))
  }

  const fontW = fontH
  const rot = rotationToZpl(element.rotation)

  return `^FO${x},${y}^A0${rot},${fontH},${fontW}^FD${text}^FS`
}

function calcAutoFitFontDots(text, boxW, boxH, fontH, minFontH) {
  if (fontH < minFontH) return minFontH

  const charW = Math.max(Math.round(fontH * AVG_CHAR_WIDTH_RATIO), 1)
  const charsPerLine = Math.max(Math.floor(boxW / charW), 1)
  const numLines = Math.ceil(text.length / charsPerLine)
  const lineHeight = Math.round(fontH * 1.2)
  const totalHeight = numLines * lineHeight

  if (totalHeight <= boxH) {
    return fontH
  }
  return calcAutoFitFontDots(text, boxW, boxH, fontH - 1, minFontH)
}

// ── Barcodes ─────────────────────────────────────────────────

function barcodeToZpl(element, row, context, x, y, dpmm, mapping) {
  let data = resolveCodeValue(element, row, mapping, context)
  data = escapeZpl(data)
  const h = mmToDots(element.height || 10, dpmm)
  const rot = rotationToZpl(element.rotation)
  const showText = element.barcode_show_text ? 'Y' : 'N'

  switch (element.barcode_format) {
    case 'CODE128':
      return `^FO${x},${y}^BC${rot},${h},${showText},N,N^FD${data}^FS`
    case 'CODE39':
      return `^FO${x},${y}^B3${rot},N,${h},${showText},N^FD${data}^FS`
    case 'CODE93':
      return `^FO${x},${y}^BA${rot},${h},${showText},N,N^FD${data}^FS`
    case 'EAN13':
      return `^FO${x},${y}^BE${rot},${h},${showText},N^FD${data}^FS`
    case 'EAN8':
      return `^FO${x},${y}^B8${rot},${h},${showText},N^FD${data}^FS`
    case 'UPC':
      return `^FO${x},${y}^BU${rot},${h},${showText},N,Y^FD${data}^FS`
    case 'ITF14':
      return `^FO${x},${y}^BI${rot},${h},${showText},N^FD${data}^FS`
    case 'CODABAR':
      return `^FO${x},${y}^BK${rot},N,${h},${showText},N,A,A^FD${data}^FS`
    case 'MSI':
      // MSI Plessey - use Code128 as fallback since ZPL has no native MSI
      return `^FO${x},${y}^BC${rot},${h},${showText},N,N^FD${data}^FS`
    case 'DATAMATRIX': {
      const mag = Math.max(Math.floor(h / 20), 1)
      return `^FO${x},${y}^BXN,${mag},200^FD${data}^FS`
    }
    case 'PDF417': {
      const cols = Math.max(Math.floor(h / 10), 1)
      return `^FO${x},${y}^B7${rot},${cols},0,0,0,N^FD${data}^FS`
    }
    case 'AZTEC': {
      const mag = Math.max(Math.floor(h / 20), 1)
      return `^FO${x},${y}^BO${rot},${mag},N^FD${data}^FS`
    }
    case 'MAXICODE':
      return `^FO${x},${y}^BD${rot},1,Y^FD${data}^FS`
    case 'POSTNET':
      return `^FO${x},${y}^BZ${rot},${h},${showText},N^FD${data}^FS`
    case 'PLANET':
      return `^FO${x},${y}^BZ${rot},${h},${showText},N^FD${data}^FS`
    case 'GS1_128':
    case 'GS1_DATABAR':
    case 'GS1_DATABAR_STACKED':
    case 'GS1_DATABAR_EXPANDED':
      return `^FO${x},${y}^BC${rot},${h},${showText},N,N^FD${data}^FS`
    default:
      // Fallback to Code 128
      return `^FO${x},${y}^BC${rot},${h},${showText},N,N^FD${data}^FS`
  }
}

// ── QR Code ──────────────────────────────────────────────────

function qrToZpl(element, row, context, x, y, dpmm, mapping) {
  let data = resolveCodeValue(element, row, mapping, context)
  data = escapeZpl(data)
  const size = mmToDots(element.width || 10, dpmm)
  const mag = Math.max(Math.floor(size / 30), 2)

  let errorLevel
  switch (element.qr_error_level) {
    case 'L': errorLevel = 'L'; break
    case 'Q': errorLevel = 'Q'; break
    case 'H': errorLevel = 'H'; break
    default: errorLevel = 'M'
  }

  return `^FO${x},${y}^BQN,2,${mag},${errorLevel}^FDQA,${data}^FS`
}

// ── Shapes ───────────────────────────────────────────────────

function rectangleToZpl(element, x, y, dpmm) {
  const w = mmToDots(element.width || 10, dpmm)
  const h = mmToDots(element.height || 10, dpmm)
  let border = mmToDots(element.border_width || 0.5, dpmm)
  border = Math.max(border, 1)

  return `^FO${x},${y}^GB${w},${h},${border}^FS`
}

function lineToZpl(element, x, y, dpmm) {
  const w = mmToDots(element.width || 10, dpmm)
  let thickness = mmToDots(element.border_width || element.height || 0.5, dpmm)
  thickness = Math.max(thickness, 1)

  return `^FO${x},${y}^GB${w},${thickness},${thickness}^FS`
}

function circleToZpl(element, x, y, dpmm) {
  const diameter = mmToDots(Math.min(element.width || 10, element.height || 10), dpmm)
  let border = mmToDots(element.border_width || 0.5, dpmm)
  border = Math.max(border, 1)

  return `^FO${x},${y}^GC${diameter},${border}^FS`
}

function imagePlaceholderToZpl(element, x, y, dpmm) {
  const w = mmToDots(element.width || 10, dpmm)
  const h = mmToDots(element.height || 10, dpmm)

  // MVP: placeholder box for images
  return `^FO${x},${y}^GB${w},${h},1^FS`
}

// ── Helpers ──────────────────────────────────────────────────

function mmToDots(mm, dpmm) {
  if (typeof mm !== 'number') return 0
  return Math.round(mm * dpmm)
}

function rotationToZpl(deg) {
  if (deg == null || typeof deg !== 'number') return 'N'
  let normalized = Math.round(deg) % 360
  if (normalized < 0) normalized += 360

  if (normalized >= 315 || normalized < 45) return 'N'   // 0°
  if (normalized >= 45 && normalized < 135) return 'R'    // 90°
  if (normalized >= 135 && normalized < 225) return 'I'   // 180°
  return 'B'                                               // 270°
}

function escapeZpl(text) {
  if (text == null) return ''
  return String(text).replace(/\^/g, ' ').replace(/~/g, ' ')
}
