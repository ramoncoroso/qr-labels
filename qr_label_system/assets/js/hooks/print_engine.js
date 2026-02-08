/**
 * Print Engine Hook
 * Handles label generation, printing and PDF export
 */

import { generateQR, generateBarcode } from './barcode_generator'
import { resolveText, resolveCodeValue } from './expression_engine'
import { calcAutoFitFontSize } from './text_utils'
import { jsPDF } from 'jspdf'

const MM_TO_PX = 3.78
// Canvas uses PX_PER_MM=6 for font sizes — convert to mm: font_size / PX_PER_MM
const PX_PER_MM = 6
// Convert canvas font pixels to pt for jsPDF: (font_size / PX_PER_MM) * (72 / 25.4)
const FONT_PX_TO_PT = 72 / (PX_PER_MM * 25.4)

/**
 * Print a PDF blob by opening it in a new window and triggering print().
 * The browser's PDF viewer in a full window responds to print() correctly,
 * unlike an iframe where the PDF plugin doesn't expose content to the DOM.
 */
function printPdfBlob(blob) {
  const url = URL.createObjectURL(blob)
  const win = window.open(url, '_blank')
  if (!win) return

  // The PDF viewer needs time to initialize before print() works.
  // Listen for load, then add a small delay for the viewer to render.
  win.addEventListener('load', () => {
    setTimeout(() => {
      win.focus()
      win.print()
    }, 300)
  })
}

const PrintEngine = {
  mounted() {
    this.labels = []
    this.design = null
    this.printConfig = null
    this.columnMapping = {}
    this.setupEventListeners()
  },

  setupEventListeners() {
    this.handleEvent("generate_batch", async ({design, data, column_mapping, print_config}) => {
      this.design = design
      this.printConfig = print_config
      this.columnMapping = column_mapping || {}

      try {
        this.labels = await this.generateAllLabels(design, data, column_mapping)
        this.renderPreview()
        this.pushEvent("generation_complete", {})
      } catch (err) {
        console.error('Error generating labels:', err)
      }
    })

    this.handleEvent("print_labels", () => {
      this.printLabels()
    })

    this.handleEvent("export_pdf", ({filename}) => {
      this.exportPDF(filename)
    })

    // Generic file download handler (used by ZPL export and others)
    this.handleEvent("download_file", ({content, filename, mime_type}) => {
      const blob = new Blob([content], { type: mime_type })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = filename
      a.click()
      URL.revokeObjectURL(url)
    })
  },

  async generateAllLabels(design, data, mapping) {
    const labels = []
    const batchSize = data.length
    const now = new Date()

    for (let rowIndex = 0; rowIndex < data.length; rowIndex++) {
      const row = data[rowIndex]
      const context = { rowIndex, batchSize, now }
      const labelCodes = {}

      for (const element of design.elements || []) {
        if (element.type !== 'qr' && element.type !== 'barcode') continue

        const value = resolveCodeValue(element, row, mapping, context)
        if (!value) continue

        if (element.type === 'qr') {
          labelCodes[element.id] = await this.generateQR(value, element)
        } else if (element.type === 'barcode') {
          labelCodes[element.id] = this.generateBarcode(value, element)
        }
      }

      labels.push({
        rowData: row,
        codes: labelCodes,
        context
      })
    }

    return labels
  },

  async generateQR(content, config) {
    return generateQR(content, config)
  },

  generateBarcode(content, config) {
    return generateBarcode(content, config)
  },

  renderPreview() {
    // Find or create a dedicated preview container (don't overwrite hook element children)
    let container = this.el.querySelector('[data-print-preview]')
    if (!container) {
      // If no dedicated preview container exists, skip inline preview
      // (the editor uses LabelPreview for preview, PrintEngine is only for print/PDF)
      return
    }

    container.innerHTML = ''

    if (this.labels.length === 0) {
      container.innerHTML = '<div class="text-center text-gray-500 py-8">No hay etiquetas para mostrar</div>'
      return
    }

    const config = this.printConfig

    if (config.printer_type === 'normal') {
      this.renderSheetPreview(container)
    } else {
      this.renderRollPreview(container)
    }
  },

  renderSheetPreview(container) {
    const config = this.printConfig
    const design = this.design

    // Calculate page dimensions
    const pageSizes = {
      a4: { width: 210, height: 297 },
      letter: { width: 216, height: 279 },
      legal: { width: 216, height: 356 }
    }

    let pageSize = pageSizes[config.page_size] || pageSizes.a4
    if (config.orientation === 'landscape') {
      pageSize = { width: pageSize.height, height: pageSize.width }
    }

    const labelsPerPage = config.columns * config.rows
    const totalPages = Math.ceil(this.labels.length / labelsPerPage)

    // Create page container
    const pagesContainer = document.createElement('div')
    pagesContainer.className = 'space-y-4'

    for (let pageIdx = 0; pageIdx < Math.min(totalPages, 3); pageIdx++) {
      const pageDiv = document.createElement('div')
      pageDiv.className = 'bg-white shadow-lg mx-auto'
      pageDiv.style.width = `${pageSize.width * 2}px`
      pageDiv.style.height = `${pageSize.height * 2}px`
      pageDiv.style.padding = `${config.margin_top * 2}px ${config.margin_right * 2}px ${config.margin_bottom * 2}px ${config.margin_left * 2}px`

      const grid = document.createElement('div')
      grid.style.display = 'grid'
      grid.style.gridTemplateColumns = `repeat(${config.columns}, 1fr)`
      grid.style.gap = `${config.gap_vertical * 2}px ${config.gap_horizontal * 2}px`

      const startIdx = pageIdx * labelsPerPage
      const endIdx = Math.min(startIdx + labelsPerPage, this.labels.length)

      for (let i = startIdx; i < endIdx; i++) {
        const label = this.labels[i]
        const labelDiv = this.createLabelElement(label, 2)
        grid.appendChild(labelDiv)
      }

      pageDiv.appendChild(grid)
      pagesContainer.appendChild(pageDiv)

      if (pageIdx === 0) {
        const pageInfo = document.createElement('div')
        pageInfo.className = 'text-center text-sm text-gray-500 mt-2'
        pageInfo.textContent = `Página 1 de ${totalPages} (mostrando hasta 3 páginas de vista previa)`
        pagesContainer.appendChild(pageInfo)
      }
    }

    container.appendChild(pagesContainer)
  },

  renderRollPreview(container) {
    const config = this.printConfig
    const design = this.design

    const rollContainer = document.createElement('div')
    rollContainer.className = 'flex flex-col items-center space-y-2 overflow-x-auto'

    // Show first 5 labels
    const maxPreview = Math.min(5, this.labels.length)
    for (let i = 0; i < maxPreview; i++) {
      const label = this.labels[i]
      const labelDiv = this.createLabelElement(label, 2)
      rollContainer.appendChild(labelDiv)
    }

    if (this.labels.length > 5) {
      const more = document.createElement('div')
      more.className = 'text-gray-500 text-sm'
      more.textContent = `... y ${this.labels.length - 5} etiquetas más`
      rollContainer.appendChild(more)
    }

    container.appendChild(rollContainer)
  },

  createLabelElement(label, scale = 1) {
    const design = this.design

    const labelDiv = document.createElement('div')
    labelDiv.className = 'relative'
    labelDiv.style.width = `${design.width_mm * scale * MM_TO_PX}px`
    labelDiv.style.height = `${design.height_mm * scale * MM_TO_PX}px`
    labelDiv.style.backgroundColor = design.background_color || '#FFFFFF'
    labelDiv.style.border = `${(design.border_width || 0) * scale}px solid ${design.border_color || '#000000'}`
    labelDiv.style.borderRadius = `${(design.border_radius || 0) * scale * MM_TO_PX}px`
    labelDiv.style.overflow = 'hidden'

    // Render elements sorted by z_index (lower = back, higher = front)
    const sortedElements = [...(design.elements || [])].sort((a, b) => (a.z_index || 0) - (b.z_index || 0))
    for (const element of sortedElements) {
      if (element.visible === false) continue
      const elementDiv = this.renderElement(element, label, scale)
      if (elementDiv) {
        labelDiv.appendChild(elementDiv)
      }
    }

    return labelDiv
  },

  renderElement(element, label, scale) {
    const div = document.createElement('div')
    div.style.position = 'absolute'
    div.style.left = `${element.x * scale * MM_TO_PX}px`
    div.style.top = `${element.y * scale * MM_TO_PX}px`

    if (element.rotation) {
      div.style.transform = `rotate(${element.rotation}deg)`
    }

    switch (element.type) {
      case 'qr':
      case 'barcode':
        const codeImg = label.codes[element.id]
        if (codeImg) {
          const img = document.createElement('img')
          img.src = codeImg
          img.style.width = `${element.width * scale * MM_TO_PX}px`
          img.style.height = `${element.height * scale * MM_TO_PX}px`
          div.appendChild(img)
        } else {
          div.style.width = `${element.width * scale * MM_TO_PX}px`
          div.style.height = `${element.height * scale * MM_TO_PX}px`
          div.style.backgroundColor = '#e5e7eb'
          div.style.display = 'flex'
          div.style.alignItems = 'center'
          div.style.justifyContent = 'center'
          div.style.fontSize = '10px'
          div.style.color = '#9ca3af'
          div.textContent = element.type.toUpperCase()
        }
        break

      case 'text':
        const textContent = resolveText(element, label.rowData || {}, this.columnMapping, label.context || {})

        div.textContent = textContent
        div.style.width = `${element.width * scale * MM_TO_PX}px`

        let printFontSize = (element.font_size || 12) * (MM_TO_PX / PX_PER_MM) * scale
        if (element.text_auto_fit === true && textContent && element.width && element.height) {
          const printBoxW = element.width * scale * MM_TO_PX
          const printBoxH = element.height * scale * MM_TO_PX
          div.style.height = `${printBoxH}px`
          const minFs = (element.text_min_font_size || 6) * (MM_TO_PX / PX_PER_MM) * scale
          const result = calcAutoFitFontSize(
            textContent, printBoxW, printBoxH, printFontSize, minFs,
            element.font_family || 'Arial', element.font_weight || 'normal'
          )
          printFontSize = result.fontSize
          div.style.overflow = 'hidden'
        } else {
          div.style.overflow = 'visible'
        }

        div.style.fontSize = `${printFontSize}px`
        div.style.fontFamily = element.font_family || 'Arial'
        div.style.fontWeight = element.font_weight || 'normal'
        div.style.color = element.color || '#000000'
        div.style.textAlign = element.text_align || 'left'
        div.style.whiteSpace = 'normal'
        div.style.wordBreak = 'break-word'
        break

      case 'line':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${Math.max(element.height * scale * MM_TO_PX, 1)}px`
        div.style.backgroundColor = element.color || '#000000'
        break

      case 'rectangle':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${element.height * scale * MM_TO_PX}px`
        div.style.backgroundColor = element.background_color || 'transparent'
        div.style.border = `${(element.border_width || 0.5) * MM_TO_PX * scale}px solid ${element.border_color || '#000000'}`
        break

      case 'circle':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${element.height * scale * MM_TO_PX}px`
        div.style.backgroundColor = element.background_color || 'transparent'
        div.style.border = `${(element.border_width || 0.5) * MM_TO_PX * scale}px solid ${element.border_color || '#000000'}`
        // border_radius: 0 = rectangle, 100 = full ellipse (50% CSS border-radius)
        const circleRoundness = (element.border_radius ?? 100) / 100
        const circleMaxRadius = Math.min(element.width, element.height) * scale * MM_TO_PX / 2
        div.style.borderRadius = `${circleRoundness * circleMaxRadius}px`
        break

      default:
        return null
    }

    return div
  },

  async printLabels() {
    const design = this.design
    const w = design.width_mm
    const h = design.height_mm

    const pdf = new jsPDF({
      orientation: w > h ? 'l' : 'p',
      unit: 'mm',
      format: [w, h]
    })

    for (let i = 0; i < this.labels.length; i++) {
      if (i > 0) pdf.addPage([w, h], w > h ? 'l' : 'p')
      await this.renderLabelToPDF(pdf, this.labels[i], 0, 0)
    }

    printPdfBlob(pdf.output('blob'))
  },

  async exportPDF(filename) {
    const design = this.design
    const labelWidth = design.width_mm
    const labelHeight = design.height_mm

    const pdf = new jsPDF({
      orientation: labelWidth > labelHeight ? 'l' : 'p',
      unit: 'mm',
      format: [labelWidth, labelHeight]
    })

    for (let i = 0; i < this.labels.length; i++) {
      if (i > 0) {
        pdf.addPage([labelWidth, labelHeight], labelWidth > labelHeight ? 'l' : 'p')
      }
      await this.renderLabelToPDF(pdf, this.labels[i], 0, 0)
    }

    pdf.save(filename)
  },

  async renderLabelToPDF(pdf, label, offsetX, offsetY) {
    const design = this.design

    // Draw label background
    pdf.setFillColor(design.background_color || '#FFFFFF')
    pdf.rect(offsetX, offsetY, design.width_mm, design.height_mm, 'F')

    // Draw border if exists
    if (design.border_width > 0) {
      pdf.setDrawColor(design.border_color || '#000000')
      pdf.setLineWidth(design.border_width)
      pdf.rect(offsetX, offsetY, design.width_mm, design.height_mm, 'S')
    }

    // Render elements
    for (const element of design.elements || []) {
      await this.renderElementToPDF(pdf, element, label, offsetX, offsetY)
    }
  },

  async renderElementToPDF(pdf, element, label, offsetX, offsetY) {
    const x = offsetX + element.x
    const y = offsetY + element.y

    switch (element.type) {
      case 'qr':
      case 'barcode':
        const codeImg = label.codes[element.id]
        if (codeImg) {
          pdf.addImage(codeImg, 'PNG', x, y, element.width, element.height)
        }
        break

      case 'text':
        const pdfTextContent = resolveText(element, label.rowData || {}, this.columnMapping, label.context || {})

        let pdfFontSizePx = element.font_size || 12
        if (element.text_auto_fit === true && pdfTextContent && element.width && element.height) {
          const boxWPx = element.width * PX_PER_MM
          const boxHPx = element.height * PX_PER_MM
          const minFsPx = (element.text_min_font_size || 6)
          const result = calcAutoFitFontSize(
            pdfTextContent, boxWPx, boxHPx, pdfFontSizePx, minFsPx,
            element.font_family || 'Arial', element.font_weight || 'normal'
          )
          pdfFontSizePx = result.fontSize
        }

        const fontSizePt = pdfFontSizePx * FONT_PX_TO_PT
        const fontSizeMM = pdfFontSizePx / PX_PER_MM
        pdf.setFontSize(fontSizePt)
        pdf.setTextColor(element.color || '#000000')

        if (element.font_weight === 'bold') {
          pdf.setFont(undefined, 'bold')
        } else {
          pdf.setFont(undefined, 'normal')
        }

        let textX = x
        if (element.text_align === 'center') {
          textX = x + element.width / 2
        } else if (element.text_align === 'right') {
          textX = x + element.width
        }

        pdf.text(pdfTextContent, textX, y + fontSizeMM * 0.75, {
          align: element.text_align || 'left',
          maxWidth: element.width
        })
        break

      case 'line':
        pdf.setDrawColor(element.color || '#000000')
        pdf.setLineWidth(Math.max(element.height, 0.1))
        pdf.line(x, y, x + element.width, y)
        break

      case 'rectangle':
        if (element.background_color && element.background_color !== 'transparent') {
          pdf.setFillColor(element.background_color)
          pdf.rect(x, y, element.width, element.height, 'F')
        }
        if (element.border_width > 0) {
          pdf.setDrawColor(element.border_color || '#000000')
          pdf.setLineWidth(element.border_width)
          pdf.rect(x, y, element.width, element.height, 'S')
        }
        break

      case 'circle':
        // Calculate border radius based on roundness percentage
        const pdfRoundness = (element.border_radius ?? 100) / 100
        const pdfMaxRadius = Math.min(element.width, element.height) / 2
        const pdfRadius = pdfRoundness * pdfMaxRadius

        // Determine fill/stroke mode
        let circleStyle = 'S' // Default: stroke only
        if (element.background_color && element.background_color !== 'transparent') {
          pdf.setFillColor(element.background_color)
          circleStyle = element.border_width > 0 ? 'FD' : 'F' // Fill+Draw or Fill only
        }
        if (element.border_width > 0) {
          pdf.setDrawColor(element.border_color || '#000000')
          pdf.setLineWidth(element.border_width)
        }
        pdf.roundedRect(x, y, element.width, element.height, pdfRadius, pdfRadius, circleStyle)
        break
    }
  }
}

export default PrintEngine
