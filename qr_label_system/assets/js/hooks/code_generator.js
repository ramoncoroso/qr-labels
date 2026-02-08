/**
 * Code Generator Hook
 * Generates QR codes and barcodes client-side using qrcode and JsBarcode
 */

import { generateQR, generateBarcode } from './barcode_generator'

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
    return generateQR(content, config)
  },

  generateBarcode(content, config) {
    return generateBarcode(content, config)
  }
}

export default CodeGenerator
