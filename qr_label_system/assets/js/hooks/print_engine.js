/**
 * Print Engine Hook
 * Handles label generation, printing and PDF export
 */

import QRCode from 'qrcode'
import JsBarcode from 'jsbarcode'
import { jsPDF } from 'jspdf'

const MM_TO_PX = 3.78

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
  },

  async generateAllLabels(design, data, mapping) {
    const labels = []

    for (const row of data) {
      const labelCodes = {}

      // Generate codes for each element that has a binding
      for (const element of design.elements || []) {
        const columnName = mapping[element.id]
        if (!columnName) continue

        const value = row[columnName]
        if (!value) continue

        if (element.type === 'qr') {
          labelCodes[element.id] = await this.generateQR(String(value), element)
        } else if (element.type === 'barcode') {
          labelCodes[element.id] = this.generateBarcode(String(value), element)
        }
      }

      labels.push({
        rowData: row,
        codes: labelCodes
      })
    }

    return labels
  },

  async generateQR(content, config) {
    try {
      return await QRCode.toDataURL(content, {
        width: Math.round((config.width || 20) * MM_TO_PX),
        margin: 0,
        errorCorrectionLevel: config.qr_error_level || 'M'
      })
    } catch (err) {
      console.error('Error generating QR:', err)
      return null
    }
  },

  generateBarcode(content, config) {
    try {
      const canvas = document.createElement('canvas')
      JsBarcode(canvas, content, {
        format: config.barcode_format || 'CODE128',
        width: 2,
        height: Math.round((config.height || 15) * MM_TO_PX),
        displayValue: config.barcode_show_text !== false,
        margin: 0
      })
      return canvas.toDataURL('image/png')
    } catch (err) {
      console.error('Error generating barcode:', err)
      return null
    }
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

    // Render elements
    for (const element of design.elements || []) {
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
        let textContent = element.text_content || ''

        // Use column_mapping to resolve the actual column name, then fall back to binding
        if (label.rowData) {
          const columnName = this.columnMapping[element.id]
          if (columnName && label.rowData[columnName] != null) {
            textContent = String(label.rowData[columnName])
          } else if (element.binding && label.rowData[element.binding] != null) {
            textContent = String(label.rowData[element.binding])
          }
        }

        div.textContent = textContent
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.fontSize = `${(element.font_size || 12) * scale}px`
        div.style.fontFamily = element.font_family || 'Arial'
        div.style.fontWeight = element.font_weight || 'normal'
        div.style.color = element.color || '#000000'
        div.style.textAlign = element.text_align || 'left'
        div.style.overflow = 'hidden'
        div.style.whiteSpace = 'nowrap'
        div.style.textOverflow = 'ellipsis'
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
        div.style.border = `${(element.border_width || 0.5) * scale}px solid ${element.border_color || '#000000'}`
        break

      case 'circle':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${element.height * scale * MM_TO_PX}px`
        div.style.backgroundColor = element.background_color || 'transparent'
        div.style.border = `${(element.border_width || 0.5) * scale}px solid ${element.border_color || '#000000'}`
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

  printLabels() {
    const printWindow = window.open('', '_blank')
    if (!printWindow) {
      alert('Por favor permite las ventanas emergentes para imprimir')
      return
    }

    const html = this.generatePrintHTML()
    printWindow.document.write(html)
    printWindow.document.close()
    printWindow.onload = () => {
      printWindow.print()
      // Record print after window closes
      printWindow.onafterprint = () => {
        this.pushEvent("print_recorded", {count: this.labels.length})
      }
    }
  },

  generatePrintHTML() {
    const config = this.printConfig
    const design = this.design

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
    const pages = []

    for (let i = 0; i < this.labels.length; i += labelsPerPage) {
      const pageLabels = this.labels.slice(i, i + labelsPerPage)
      pages.push(pageLabels)
    }

    let labelsHTML = ''
    for (const pageLabels of pages) {
      labelsHTML += '<div class="page">'
      labelsHTML += '<div class="grid">'

      for (const label of pageLabels) {
        labelsHTML += this.labelToHTML(label)
      }

      labelsHTML += '</div></div>'
    }

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Imprimir Etiquetas</title>
        <style>
          @page {
            size: ${pageSize.width}mm ${pageSize.height}mm;
            margin: 0;
          }

          * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
          }

          body {
            font-family: Arial, sans-serif;
          }

          .page {
            width: ${pageSize.width}mm;
            height: ${pageSize.height}mm;
            padding: ${config.margin_top}mm ${config.margin_right}mm ${config.margin_bottom}mm ${config.margin_left}mm;
            page-break-after: always;
          }

          .page:last-child {
            page-break-after: auto;
          }

          .grid {
            display: grid;
            grid-template-columns: repeat(${config.columns}, 1fr);
            gap: ${config.gap_vertical}mm ${config.gap_horizontal}mm;
          }

          .label {
            width: ${design.width_mm}mm;
            height: ${design.height_mm}mm;
            background-color: ${design.background_color || '#FFFFFF'};
            border: ${design.border_width || 0}mm solid ${design.border_color || '#000000'};
            border-radius: ${design.border_radius || 0}mm;
            position: relative;
            overflow: hidden;
          }

          .element {
            position: absolute;
          }

          img {
            display: block;
          }

          @media print {
            body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          }
        </style>
      </head>
      <body>
        ${labelsHTML}
      </body>
      </html>
    `
  },

  labelToHTML(label) {
    const design = this.design

    let elementsHTML = ''
    for (const element of design.elements || []) {
      elementsHTML += this.elementToHTML(element, label)
    }

    return `
      <div class="label">
        ${elementsHTML}
      </div>
    `
  },

  elementToHTML(element, label) {
    let style = `left: ${element.x}mm; top: ${element.y}mm;`

    if (element.rotation) {
      style += ` transform: rotate(${element.rotation}deg);`
    }

    switch (element.type) {
      case 'qr':
      case 'barcode':
        const codeImg = label.codes[element.id]
        if (codeImg) {
          return `<div class="element" style="${style}">
            <img src="${codeImg}" style="width: ${element.width}mm; height: ${element.height}mm;">
          </div>`
        }
        return ''

      case 'text':
        let textContent = element.text_content || ''
        if (label.rowData) {
          const columnName = this.columnMapping[element.id]
          if (columnName && label.rowData[columnName] != null) {
            textContent = String(label.rowData[columnName])
          } else if (element.binding && label.rowData[element.binding] != null) {
            textContent = String(label.rowData[element.binding])
          }
        }

        return `<div class="element" style="${style} width: ${element.width}mm; font-size: ${element.font_size || 12}pt; font-family: ${element.font_family || 'Arial'}; font-weight: ${element.font_weight || 'normal'}; color: ${element.color || '#000000'}; text-align: ${element.text_align || 'left'}; overflow: hidden; white-space: nowrap;">
          ${this.escapeHtml(textContent)}
        </div>`

      case 'line':
        return `<div class="element" style="${style} width: ${element.width}mm; height: ${Math.max(element.height, 0.3)}mm; background-color: ${element.color || '#000000'};"></div>`

      case 'rectangle':
        return `<div class="element" style="${style} width: ${element.width}mm; height: ${element.height}mm; background-color: ${element.background_color || 'transparent'}; border: ${element.border_width || 0.5}mm solid ${element.border_color || '#000000'};"></div>`

      case 'circle':
        // border_radius: 0 = rectangle, 100 = full ellipse
        const htmlRoundness = (element.border_radius ?? 100) / 100
        const htmlMaxRadius = Math.min(element.width, element.height) / 2
        const htmlRadius = htmlRoundness * htmlMaxRadius
        return `<div class="element" style="${style} width: ${element.width}mm; height: ${element.height}mm; background-color: ${element.background_color || 'transparent'}; border: ${element.border_width || 0.5}mm solid ${element.border_color || '#000000'}; border-radius: ${htmlRadius}mm;"></div>`

      default:
        return ''
    }
  },

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  },

  async exportPDF(filename) {
    const config = this.printConfig
    const design = this.design

    const pageSizes = {
      a4: [210, 297],
      letter: [216, 279],
      legal: [216, 356]
    }

    let pageSize = pageSizes[config.page_size] || pageSizes.a4
    const orientation = config.orientation === 'landscape' ? 'l' : 'p'

    const pdf = new jsPDF({
      orientation: orientation,
      unit: 'mm',
      format: pageSize
    })

    if (orientation === 'l') {
      pageSize = [pageSize[1], pageSize[0]]
    }

    const labelsPerPage = config.columns * config.rows
    let currentLabel = 0
    let pageNum = 0

    const usableWidth = pageSize[0] - config.margin_left - config.margin_right
    const usableHeight = pageSize[1] - config.margin_top - config.margin_bottom

    const cellWidth = (usableWidth - (config.columns - 1) * config.gap_horizontal) / config.columns
    const cellHeight = (usableHeight - (config.rows - 1) * config.gap_vertical) / config.rows

    while (currentLabel < this.labels.length) {
      if (pageNum > 0) {
        pdf.addPage()
      }

      for (let row = 0; row < config.rows && currentLabel < this.labels.length; row++) {
        for (let col = 0; col < config.columns && currentLabel < this.labels.length; col++) {
          const label = this.labels[currentLabel]

          const x = config.margin_left + col * (cellWidth + config.gap_horizontal)
          const y = config.margin_top + row * (cellHeight + config.gap_vertical)

          await this.renderLabelToPDF(pdf, label, x, y)

          currentLabel++
        }
      }

      pageNum++
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
        let textContent = element.text_content || ''
        if (label.rowData) {
          const columnName = this.columnMapping[element.id]
          if (columnName && label.rowData[columnName] != null) {
            textContent = String(label.rowData[columnName])
          } else if (element.binding && label.rowData[element.binding] != null) {
            textContent = String(label.rowData[element.binding])
          }
        }

        pdf.setFontSize(element.font_size || 12)
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

        pdf.text(textContent, textX, y + (element.font_size || 12) * 0.35, {
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
