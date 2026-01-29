/**
 * Excel Reader Hook
 * Reads Excel/CSV files in the browser using xlsx library
 */

import * as XLSX from 'xlsx'

const ExcelReader = {
  mounted() {
    this.setupEventListeners()
  },

  setupEventListeners() {
    this.handleEvent("read_file", ({file}) => {
      this.readFile(file)
    })
  },

  async readFile(file) {
    try {
      const arrayBuffer = await file.arrayBuffer()
      const workbook = XLSX.read(arrayBuffer, {type: 'array'})

      // Get first sheet
      const sheetName = workbook.SheetNames[0]
      const sheet = workbook.Sheets[sheetName]

      // Convert to JSON
      const data = XLSX.utils.sheet_to_json(sheet, {header: 1})

      if (data.length === 0) {
        this.pushEvent("file_error", {error: "El archivo está vacío"})
        return
      }

      // First row is headers
      const headers = data[0].map(h => String(h).trim())
      const rows = data.slice(1).map(row => {
        const obj = {}
        headers.forEach((header, idx) => {
          obj[header] = row[idx] !== undefined ? String(row[idx]) : ''
        })
        return obj
      }).filter(row => Object.values(row).some(v => v !== ''))

      this.pushEvent("file_read", {
        columns: headers,
        rows: rows,
        total: rows.length
      })
    } catch (err) {
      console.error('Error reading file:', err)
      this.pushEvent("file_error", {error: err.message})
    }
  }
}

export default ExcelReader
