/**
 * Code Generator Hook
 * Generates QR codes and barcodes client-side using qrcode and JsBarcode
 */

import QRCode from 'qrcode'
import JsBarcode from 'jsbarcode'

const CodeGenerator = {
  mounted() {
    this.setupEventListeners()
  },

  setupEventListeners() {
    this.handleEvent("generate_codes", async ({elements, rowData, mapping}) => {
      const codes = await this.generateCodes(elements, rowData, mapping)
      this.pushEvent("codes_generated", {codes})
    })
  },

  async generateCodes(elements, rowData, mapping) {
    const codes = {}

    for (const element of elements) {
      const columnName = mapping[element.id]
      if (!columnName) continue

      const value = rowData[columnName]
      if (!value) continue

      if (element.type === 'qr') {
        codes[element.id] = await this.generateQR(String(value), element)
      } else if (element.type === 'barcode') {
        codes[element.id] = this.generateBarcode(String(value), element)
      }
    }

    return codes
  },

  async generateQR(content, config) {
    try {
      const options = {
        width: Math.round((config.width || 20) * 3.78),
        margin: 0,
        errorCorrectionLevel: config.qr_error_level || 'M',
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      }

      return await QRCode.toDataURL(content, options)
    } catch (err) {
      console.error('Error generating QR code:', err)
      return null
    }
  },

  generateBarcode(content, config) {
    try {
      const canvas = document.createElement('canvas')

      JsBarcode(canvas, content, {
        format: config.barcode_format || 'CODE128',
        width: 2,
        height: Math.round((config.height || 15) * 3.78),
        displayValue: config.barcode_show_text !== false,
        fontSize: 12,
        margin: 0,
        background: '#FFFFFF',
        lineColor: '#000000'
      })

      return canvas.toDataURL('image/png')
    } catch (err) {
      console.error('Error generating barcode:', err)
      return null
    }
  }
}

export default CodeGenerator
