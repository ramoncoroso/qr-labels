/**
 * Text Auto-Fit Utilities
 * Shared measurement and auto-fit logic for text elements.
 *
 * Uses Canvas 2D API to measure text width and simulate word-wrap,
 * then iteratively shrinks font size until text fits the bounding box.
 *
 * @module text_utils
 */

let _measureCtx = null

/**
 * Get a singleton Canvas 2D context for text measurement.
 */
export function getMeasurementContext() {
  if (!_measureCtx) {
    const canvas = document.createElement('canvas')
    _measureCtx = canvas.getContext('2d')
  }
  return _measureCtx
}

/**
 * Measure text with word-wrap simulation.
 * @param {string} text - Text to measure
 * @param {number} maxWidthPx - Maximum line width in pixels
 * @param {number} fontSize - Font size in pixels
 * @param {string} fontFamily - Font family name
 * @param {string} fontWeight - Font weight (normal, bold)
 * @param {CanvasRenderingContext2D} ctx - Measurement context
 * @returns {{ height: number, lines: number }}
 */
export function measureWrappedText(text, maxWidthPx, fontSize, fontFamily, fontWeight, ctx) {
  ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`

  if (!text || text.length === 0) {
    return { height: fontSize * 1.2, lines: 1 }
  }

  const words = text.split(/\s+/)
  let lines = 1
  let currentLine = ''

  for (const word of words) {
    const testLine = currentLine ? `${currentLine} ${word}` : word
    const metrics = ctx.measureText(testLine)

    if (metrics.width > maxWidthPx && currentLine !== '') {
      lines++
      currentLine = word
    } else {
      currentLine = testLine
    }
  }

  const lineHeight = fontSize * 1.2
  return { height: lines * lineHeight, lines }
}

/**
 * Calculate the best font size to fit text within a bounding box.
 * Iteratively reduces font size by 0.5px until text fits or reaches minimum.
 *
 * @param {string} text - Text content
 * @param {number} boxWidthPx - Box width in pixels
 * @param {number} boxHeightPx - Box height in pixels
 * @param {number} maxFontSize - Starting (maximum) font size in pixels
 * @param {number} minFontSize - Minimum allowed font size in pixels
 * @param {string} fontFamily - Font family name
 * @param {string} fontWeight - Font weight (normal, bold)
 * @returns {{ fontSize: number, overflows: boolean }}
 */
export function calcAutoFitFontSize(text, boxWidthPx, boxHeightPx, maxFontSize, minFontSize, fontFamily, fontWeight) {
  if (!text || text.trim() === '' || boxWidthPx <= 0 || boxHeightPx <= 0) {
    return { fontSize: maxFontSize, overflows: false }
  }

  const ctx = getMeasurementContext()
  let fontSize = maxFontSize

  while (fontSize >= minFontSize) {
    const { height } = measureWrappedText(text, boxWidthPx, fontSize, fontFamily, fontWeight, ctx)
    if (height <= boxHeightPx) {
      return { fontSize, overflows: false }
    }
    fontSize -= 0.5
  }

  // At minimum font size, check if it still overflows
  fontSize = minFontSize
  const { height } = measureWrappedText(text, boxWidthPx, fontSize, fontFamily, fontWeight, ctx)
  return { fontSize, overflows: height > boxHeightPx }
}
