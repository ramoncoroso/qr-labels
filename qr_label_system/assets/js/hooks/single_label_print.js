/**
 * Single Label Print Hook
 * Handles printing single labels (static content) without data binding
 */

import QRCode from 'qrcode'
import JsBarcode from 'jsbarcode'
import { jsPDF } from 'jspdf'

const MM_TO_PX = 3.78

const SingleLabelPrint = {
  mounted() {
    this.setupEventListeners()
  },

  setupEventListeners() {
    this.handleEvent("print_single_labels", async ({design, quantity}) => {
      try {
        await this.printLabels(design, quantity)
        this.pushEvent("print_complete", {})
      } catch (err) {
        console.error('Error printing labels:', err)
      }
    })

    this.handleEvent("download_single_pdf", async ({design, quantity}) => {
      try {
        await this.exportPDF(design, quantity)
      } catch (err) {
        console.error('Error exporting PDF:', err)
      }
    })
  },

  async generateCodes(design) {
    const codes = {}

    for (const element of design.elements || []) {
      if (element.type === 'qr') {
        const content = element.binding || element.text_content || 'QR'
        codes[element.id] = await this.generateQR(content, element)
      } else if (element.type === 'barcode') {
        const content = element.binding || element.text_content || '123456789'
        codes[element.id] = this.generateBarcode(content, element)
      }
    }

    return codes
  },

  async generateQR(content, config) {
    try {
      return await QRCode.toDataURL(String(content), {
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
      JsBarcode(canvas, String(content), {
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

  async printLabels(design, quantity) {
    const codes = await this.generateCodes(design)

    const printWindow = window.open('', '_blank')
    if (!printWindow) {
      alert('Por favor permite las ventanas emergentes para imprimir')
      return
    }

    const html = this.generatePrintHTML(design, codes, quantity)
    printWindow.document.write(html)
    printWindow.document.close()
    printWindow.onload = () => {
      printWindow.print()
    }
  },

  generatePrintHTML(design, codes, quantity) {
    // Default to A4 portrait
    const pageSize = { width: 210, height: 297 }
    const margin = 10

    // Calculate how many labels fit per row/page
    const labelsPerRow = Math.floor((pageSize.width - margin * 2 + 5) / (design.width_mm + 5))
    const labelsPerCol = Math.floor((pageSize.height - margin * 2 + 5) / (design.height_mm + 5))
    const labelsPerPage = labelsPerRow * labelsPerCol

    const pages = []
    for (let i = 0; i < quantity; i += labelsPerPage) {
      const pageLabels = Math.min(labelsPerPage, quantity - i)
      pages.push(pageLabels)
    }

    let pagesHTML = ''
    for (const labelCount of pages) {
      pagesHTML += '<div class="page"><div class="grid">'
      for (let i = 0; i < labelCount; i++) {
        pagesHTML += this.labelToHTML(design, codes)
      }
      pagesHTML += '</div></div>'
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
            padding: ${margin}mm;
            page-break-after: always;
          }

          .page:last-child {
            page-break-after: auto;
          }

          .grid {
            display: grid;
            grid-template-columns: repeat(${labelsPerRow}, ${design.width_mm}mm);
            gap: 5mm;
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
        ${pagesHTML}
      </body>
      </html>
    `
  },

  labelToHTML(design, codes) {
    let elementsHTML = ''
    for (const element of design.elements || []) {
      elementsHTML += this.elementToHTML(element, codes)
    }

    return `
      <div class="label">
        ${elementsHTML}
      </div>
    `
  },

  elementToHTML(element, codes) {
    let style = `left: ${element.x}mm; top: ${element.y}mm;`

    if (element.rotation) {
      style += ` transform: rotate(${element.rotation}deg);`
    }

    switch (element.type) {
      case 'qr':
      case 'barcode':
        const codeImg = codes[element.id]
        if (codeImg) {
          return `<div class="element" style="${style}">
            <img src="${codeImg}" style="width: ${element.width}mm; height: ${element.height}mm;">
          </div>`
        }
        return ''

      case 'text':
        const textContent = element.text_content || ''
        return `<div class="element" style="${style} width: ${element.width}mm; font-size: ${element.font_size || 12}pt; font-family: ${element.font_family || 'Arial'}; font-weight: ${element.font_weight || 'normal'}; color: ${element.color || '#000000'}; text-align: ${element.text_align || 'left'}; overflow: hidden; white-space: nowrap;">
          ${this.escapeHtml(textContent)}
        </div>`

      case 'line':
        return `<div class="element" style="${style} width: ${element.width}mm; height: ${Math.max(element.height, 0.3)}mm; background-color: ${element.color || '#000000'};"></div>`

      case 'rectangle':
        return `<div class="element" style="${style} width: ${element.width}mm; height: ${element.height}mm; background-color: ${element.background_color || 'transparent'}; border: ${element.border_width || 0.5}mm solid ${element.border_color || '#000000'};"></div>`

      case 'image':
        if (element.image_data) {
          return `<div class="element" style="${style}">
            <img src="${element.image_data}" style="width: ${element.width}mm; height: ${element.height}mm; object-fit: contain;">
          </div>`
        }
        return ''

      default:
        return ''
    }
  },

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  },

  async exportPDF(design, quantity) {
    const codes = await this.generateCodes(design)

    // Default to A4 portrait
    const pageSize = [210, 297]
    const margin = 10
    const gap = 5

    const pdf = new jsPDF({
      orientation: 'p',
      unit: 'mm',
      format: pageSize
    })

    // Calculate how many labels fit per row/page
    const labelsPerRow = Math.floor((pageSize[0] - margin * 2 + gap) / (design.width_mm + gap))
    const labelsPerCol = Math.floor((pageSize[1] - margin * 2 + gap) / (design.height_mm + gap))
    const labelsPerPage = labelsPerRow * labelsPerCol

    let currentLabel = 0
    let pageNum = 0

    while (currentLabel < quantity) {
      if (pageNum > 0) {
        pdf.addPage()
      }

      for (let row = 0; row < labelsPerCol && currentLabel < quantity; row++) {
        for (let col = 0; col < labelsPerRow && currentLabel < quantity; col++) {
          const x = margin + col * (design.width_mm + gap)
          const y = margin + row * (design.height_mm + gap)

          await this.renderLabelToPDF(pdf, design, codes, x, y)
          currentLabel++
        }
      }

      pageNum++
    }

    pdf.save(`etiquetas-${design.name || 'label'}.pdf`)
  },

  async renderLabelToPDF(pdf, design, codes, offsetX, offsetY) {
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
      await this.renderElementToPDF(pdf, element, codes, offsetX, offsetY)
    }
  },

  async renderElementToPDF(pdf, element, codes, offsetX, offsetY) {
    const x = offsetX + element.x
    const y = offsetY + element.y

    switch (element.type) {
      case 'qr':
      case 'barcode':
        const codeImg = codes[element.id]
        if (codeImg) {
          pdf.addImage(codeImg, 'PNG', x, y, element.width, element.height)
        }
        break

      case 'text':
        const textContent = element.text_content || ''

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

      case 'image':
        if (element.image_data) {
          try {
            pdf.addImage(element.image_data, 'PNG', x, y, element.width, element.height)
          } catch (e) {
            console.warn('Could not add image to PDF:', e)
          }
        }
        break
    }
  }
}

export default SingleLabelPrint
