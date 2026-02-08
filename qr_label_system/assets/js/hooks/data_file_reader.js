/**
 * Data File Reader Hook
 * Reads Excel/CSV files and pasted data client-side, stores in IndexedDB,
 * and pushes metadata to the server.
 * Replaces the old ExcelReader hook.
 */

import * as XLSX from 'xlsx'
import { putDataset, associateDataset, clearDataset, getDataset } from './data_store'

const MAX_SAMPLE_ROWS = 5

const DataFileReader = {
  mounted() {
    this.userId = parseInt(this.el.dataset.userId)
    this.designId = this.el.dataset.designId ? parseInt(this.el.dataset.designId) : null

    // File input change → parse → IndexedDB → push metadata
    const input = this.el.querySelector('input[type="file"]')
    if (input) {
      input.addEventListener('change', (e) => {
        if (e.target.files[0]) {
          this.handleFile(e.target.files[0])
        }
      })
    }

    // Paste parsing from server
    this.handleEvent("process_paste_client", ({text}) => this.handlePaste(text))

    // Associate when design is selected
    this.handleEvent("associate_dataset", ({design_id}) => {
      associateDataset(this.userId, design_id)
    })

    // Clear dataset
    this.handleEvent("clear_dataset", ({design_id}) => {
      clearDataset(this.userId, design_id)
    })

    // Check IDB data (for server restart recovery)
    this.handleEvent("check_idb_data", async ({design_id}) => {
      const dataset = await getDataset(this.userId, design_id)
      if (dataset && dataset.totalRows > 0) {
        const sampleRows = dataset.rows.slice(0, MAX_SAMPLE_ROWS)
        this.pushEvent("idb_data_available", {
          columns: dataset.columns,
          total_rows: dataset.totalRows,
          sample_rows: sampleRows
        })
      }
    })
  },

  async handleFile(file) {
    // Validate extension
    const ext = file.name.split('.').pop().toLowerCase()
    if (!['xlsx', 'xls', 'csv'].includes(ext)) {
      this.pushEvent("file_error", {error: "Formato no soportado. Usa .xlsx, .xls o .csv"})
      return
    }

    // Validate size (10MB)
    if (file.size > 10 * 1024 * 1024) {
      this.pushEvent("file_error", {error: "El archivo excede el límite de 10MB"})
      return
    }

    try {
      const arrayBuffer = await file.arrayBuffer()
      const workbook = XLSX.read(arrayBuffer, {type: 'array'})

      const sheetName = workbook.SheetNames[0]
      const sheet = workbook.Sheets[sheetName]
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

      if (rows.length === 0) {
        this.pushEvent("file_error", {error: "El archivo no contiene datos (solo encabezados)"})
        return
      }

      // Store in IndexedDB
      await putDataset(this.userId, this.designId, headers, rows)

      // Push metadata to server
      const sampleRows = rows.slice(0, MAX_SAMPLE_ROWS)
      this.pushEvent("client_file_read", {
        columns: headers,
        total_rows: rows.length,
        sample_rows: sampleRows
      })
    } catch (err) {
      console.error('Error reading file:', err)
      this.pushEvent("file_error", {error: err.message})
    }
  },

  handlePaste(text) {
    try {
      const trimmed = (text || '').trim()
      if (!trimmed) {
        this.pushEvent("file_error", {error: "No hay datos para procesar"})
        return
      }

      const lines = trimmed.split(/\r?\n/).filter(l => l.trim() !== '')

      if (lines.length < 2) {
        this.pushEvent("file_error", {error: "Solo se detectó una fila. Incluye datos además de los encabezados."})
        return
      }

      // Auto-detect separator
      const header = lines[0]
      let separator
      if (header.includes('\t')) {
        separator = '\t'
      } else if (header.includes(';')) {
        separator = ';'
      } else if (header.includes(',')) {
        separator = ','
      } else if (/\s{2,}/.test(header)) {
        separator = /\s{2,}/
      } else if (header.includes(' ')) {
        separator = /\s+/
      } else {
        separator = '\t'
      }

      const columns = header.split(separator).map(s => s.trim()).filter(s => s !== '')

      if (columns.length === 0) {
        this.pushEvent("file_error", {error: "No se detectaron columnas."})
        return
      }

      const rows = lines.slice(1).map(line => {
        const values = line.split(separator).map(s => s.trim())
        const obj = {}
        columns.forEach((col, idx) => {
          obj[col] = values[idx] || ''
        })
        return obj
      })

      // Store in IndexedDB (async but fire-and-forget for UI responsiveness)
      putDataset(this.userId, this.designId, columns, rows).then(() => {
        const sampleRows = rows.slice(0, MAX_SAMPLE_ROWS)
        this.pushEvent("client_file_read", {
          columns,
          total_rows: rows.length,
          sample_rows: sampleRows
        })
      }).catch(err => {
        console.error('Error storing pasted data:', err)
        this.pushEvent("file_error", {error: "Error al almacenar datos"})
      })
    } catch (err) {
      console.error('Error parsing pasted data:', err)
      this.pushEvent("file_error", {error: err.message})
    }
  }
}

export default DataFileReader
