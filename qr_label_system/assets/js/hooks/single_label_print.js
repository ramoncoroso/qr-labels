/**
 * Single Label Print Hook
 * Handles printing single labels (static content) without data binding
 */

import { generateQR, generateBarcode } from './barcode_generator'
import { resolveText, resolveCodeValue } from './expression_engine'
import { jsPDF } from 'jspdf'

const MM_TO_PX = 3.78

/**
 * Print a PDF blob by opening it in a new window and triggering print().
 */
function printPdfBlob(blob) {
  const url = URL.createObjectURL(blob)
  const win = window.open(url, '_blank')
  if (!win) return

  win.addEventListener('load', () => {
    setTimeout(() => {
      win.focus()
      win.print()
    }, 300)
  })
}

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

  async generateCodes(design, context) {
    const codes = {}

    for (const element of design.elements || []) {
      if (element.type === 'qr') {
        const content = resolveCodeValue(element, {}, null, context)
        codes[element.id] = await this.generateQR(content || 'QR', element)
      } else if (element.type === 'barcode') {
        const content = resolveCodeValue(element, {}, null, context)
        codes[element.id] = this.generateBarcode(content || '123456789', element)
      }
    }

    return codes
  },

  async generateQR(content, config) {
    return generateQR(content, config)
  },

  generateBarcode(content, config) {
    return generateBarcode(content, config)
  },

  async printLabels(design, quantity) {
    const w = design.width_mm
    const h = design.height_mm
    const now = new Date()

    const pdf = new jsPDF({
      orientation: w > h ? 'l' : 'p',
      unit: 'mm',
      format: [w, h]
    })

    for (let i = 0; i < quantity; i++) {
      if (i > 0) pdf.addPage([w, h], w > h ? 'l' : 'p')
      const context = { rowIndex: i, batchSize: quantity, now }
      const codes = await this.generateCodes(design, context)
      await this.renderLabelToPDF(pdf, design, codes, 0, 0, context)
    }

    printPdfBlob(pdf.output('blob'))
  },

  async exportPDF(design, quantity) {
    const w = design.width_mm
    const h = design.height_mm
    const now = new Date()

    const pdf = new jsPDF({
      orientation: w > h ? 'l' : 'p',
      unit: 'mm',
      format: [w, h]
    })

    for (let i = 0; i < quantity; i++) {
      if (i > 0) {
        pdf.addPage([w, h], w > h ? 'l' : 'p')
      }
      const context = { rowIndex: i, batchSize: quantity, now }
      const codes = await this.generateCodes(design, context)
      await this.renderLabelToPDF(pdf, design, codes, 0, 0, context)
    }

    pdf.save(`etiquetas-${design.name || 'label'}.pdf`)
  },

  async renderLabelToPDF(pdf, design, codes, offsetX, offsetY, context) {
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
      await this.renderElementToPDF(pdf, element, codes, offsetX, offsetY, context)
    }
  },

  async renderElementToPDF(pdf, element, codes, offsetX, offsetY, context) {
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
        const textContent = resolveText(element, {}, null, context || {})

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
