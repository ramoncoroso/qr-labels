/**
 * Template Download
 * Generates a sample Excel file from design elements, including
 * language suffix columns for multi-language designs.
 *
 * @module TemplateDownload
 */

import * as XLSX from 'xlsx'

/**
 * Extract column references from an expression binding like "{{MAYUS(nombre)}}"
 * Returns an array of column names found.
 */
function extractColumnsFromExpression(binding) {
  const cols = []
  // Match everything inside {{ }}
  const matches = binding.match(/\{\{(.+?)\}\}/g)
  if (!matches) return cols

  for (const m of matches) {
    const inner = m.slice(2, -2).trim()
    extractColumnsFromExpr(inner, cols)
  }
  return cols
}

/**
 * Recursively extract column names from a single expression.
 * Skips known function names, quoted strings, numbers, and operators.
 */
function extractColumnsFromExpr(expr, cols) {
  // Known function names (Spanish)
  const FUNCTIONS = new Set([
    'MAYUS', 'MINUS', 'RECORTAR', 'CONCAT', 'REEMPLAZAR', 'LARGO',
    'HOY', 'AHORA', 'SUMAR_DIAS', 'SUMAR_MESES', 'FORMATO_FECHA',
    'CONTADOR', 'LOTE', 'REDONDEAR', 'FORMATO_NUM',
    'SI', 'VACIO', 'POR_DEFECTO', 'IDIOMA',
    'IZQUIERDA', 'DERECHA', 'SUBCADENA', 'BUSCAR', 'POSICION'
  ])

  // Strip outer parens/whitespace
  expr = expr.trim()

  // Handle || operator
  if (expr.includes('||')) {
    expr.split('||').forEach(part => extractColumnsFromExpr(part.trim(), cols))
    return
  }

  // Handle function call: NAME(args)
  const fnMatch = expr.match(/^([A-Z_]+)\((.+)\)$/s)
  if (fnMatch) {
    // Parse args and recurse
    const argsStr = fnMatch[2]
    splitArgs(argsStr).forEach(arg => extractColumnsFromExpr(arg.trim(), cols))
    return
  }

  // Skip quoted strings
  if (/^["'].*["']$/.test(expr)) return
  // Skip numbers
  if (/^-?\d+(\.\d+)?$/.test(expr)) return
  // Skip comparison operators
  if (/^[<>=!]+$/.test(expr)) return
  // Skip empty
  if (!expr) return
  // Skip function names alone
  if (FUNCTIONS.has(expr.toUpperCase())) return

  // It's a column reference
  if (!cols.includes(expr)) cols.push(expr)
}

/**
 * Split function arguments respecting nested parentheses and quotes.
 */
function splitArgs(argsStr) {
  const args = []
  let current = ''
  let depth = 0
  let inQuote = false
  let quoteChar = ''

  for (let i = 0; i < argsStr.length; i++) {
    const ch = argsStr[i]
    if (inQuote) {
      current += ch
      if (ch === quoteChar) inQuote = false
      continue
    }
    if (ch === '"' || ch === "'") {
      inQuote = true
      quoteChar = ch
      current += ch
      continue
    }
    if (ch === '(') { depth++; current += ch; continue }
    if (ch === ')') { depth--; current += ch; continue }
    if (ch === ',' && depth === 0) {
      args.push(current)
      current = ''
      continue
    }
    current += ch
  }
  if (current.trim()) args.push(current)
  return args
}

/**
 * Language names in Spanish for the instructions sheet.
 */
const LANG_NAMES = {
  es: 'Español', en: 'Inglés', fr: 'Francés', de: 'Alemán',
  it: 'Italiano', pt: 'Portugués', nl: 'Neerlandés', pl: 'Polaco',
  ro: 'Rumano', sv: 'Sueco', da: 'Danés', fi: 'Finés',
  el: 'Griego', hu: 'Húngaro', cs: 'Checo', bg: 'Búlgaro',
  hr: 'Croata', zh: 'Chino', ja: 'Japonés', ko: 'Coreano', ar: 'Árabe'
}

/**
 * Generate and download a sample Excel template for a design.
 *
 * @param {Object} design - The design object with elements, languages, etc.
 * @param {string} design.name - Design name (used for filename)
 * @param {Array} design.elements - Design elements
 * @param {Array} design.languages - Configured languages e.g. ["es", "en", "fr"]
 * @param {string} design.default_language - Default language e.g. "es"
 */
export function downloadTemplate(design) {
  const elements = design.elements || []
  const languages = design.languages || ['es']
  const defaultLang = design.default_language || 'es'
  const nonDefaultLangs = languages.filter(l => l !== defaultLang)

  // 1. Collect unique column names from bound elements only
  // Elements without binding use static translations (managed in the editor's Translate panel)
  const columnSet = new Set()
  const elementInfo = [] // Track which elements use which columns

  for (const el of elements) {
    if (!el.binding || el.binding.trim() === '') continue

    if (el.binding.includes('{{')) {
      // Expression mode — extract column references
      const cols = extractColumnsFromExpression(el.binding)
      for (const c of cols) {
        columnSet.add(c)
        elementInfo.push({ column: c, element: el.name || el.id, type: 'expresión' })
      }
    } else {
      // Direct column binding
      columnSet.add(el.binding)
      elementInfo.push({ column: el.binding, element: el.name || el.id, type: 'columna' })
    }
  }

  const baseColumns = Array.from(columnSet)

  // 2. Build headers: base columns + language suffix columns
  const headers = []
  const headerStyles = [] // Track which headers are translations

  for (const col of baseColumns) {
    headers.push(col)
    headerStyles.push('base')

    for (const lang of nonDefaultLangs) {
      headers.push(`${col}_${lang}`)
      headerStyles.push('translation')
    }
  }

  // If no columns found, create a minimal template
  if (headers.length === 0) {
    headers.push('columna_1', 'columna_2')
    headerStyles.push('base', 'base')
  }

  // 3. Build sample row with placeholder values
  const sampleRow = {}
  for (let i = 0; i < headers.length; i++) {
    const h = headers[i]
    // Check if it's a translation column
    const langSuffix = h.match(/_([a-z]{2})$/)
    if (langSuffix && nonDefaultLangs.includes(langSuffix[1])) {
      const base = h.replace(/_[a-z]{2}$/, '')
      const langName = LANG_NAMES[langSuffix[1]] || langSuffix[1]
      sampleRow[h] = `(${base} en ${langName})`
    } else {
      sampleRow[h] = `(valor de ${h})`
    }
  }

  // 4. Create "Datos" sheet
  const dataSheet = XLSX.utils.json_to_sheet([sampleRow], { header: headers })

  // Set column widths
  dataSheet['!cols'] = headers.map(h => ({ wch: Math.max(h.length + 4, 20) }))

  // 5. Create "Instrucciones" sheet
  const instructions = buildInstructions(baseColumns, nonDefaultLangs, elementInfo, design)
  const instrSheet = XLSX.utils.aoa_to_sheet(instructions)
  instrSheet['!cols'] = [{ wch: 30 }, { wch: 50 }, { wch: 30 }]

  // 6. Create workbook and download
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, dataSheet, 'Datos')
  XLSX.utils.book_append_sheet(wb, instrSheet, 'Instrucciones')

  const filename = `plantilla_${slugify(design.name)}.xlsx`
  XLSX.writeFile(wb, filename)
}

/**
 * Build instruction rows for the second sheet.
 */
function buildInstructions(baseColumns, nonDefaultLangs, elementInfo, design) {
  const rows = []
  const defaultLang = design.default_language || 'es'
  const defaultLangName = LANG_NAMES[defaultLang] || defaultLang

  rows.push(['PLANTILLA DE DATOS', '', ''])
  rows.push([`Diseño: ${design.name}`, '', ''])
  rows.push(['', '', ''])

  rows.push(['CÓMO USAR ESTA PLANTILLA', '', ''])
  rows.push(['', '', ''])
  rows.push(['1. Rellena la hoja "Datos" con tus registros (uno por fila).', '', ''])
  rows.push(['2. La primera fila contiene los nombres de columna — no la modifiques.', '', ''])
  rows.push(['3. La fila de ejemplo muestra dónde va cada dato — reemplázala con datos reales.', '', ''])
  rows.push(['4. Guarda el archivo y súbelo en la aplicación.', '', ''])
  rows.push(['', '', ''])

  // Column reference
  rows.push(['COLUMNAS', 'DESCRIPCIÓN', 'ELEMENTO'])
  for (const info of elementInfo) {
    rows.push([info.column, `Columna base (${defaultLangName})`, info.element])
  }
  rows.push(['', '', ''])

  // Language instructions
  if (nonDefaultLangs.length > 0) {
    rows.push(['COLUMNAS DE TRADUCCIÓN', '', ''])
    rows.push(['', '', ''])
    rows.push([
      `El idioma por defecto es ${defaultLangName} (${defaultLang}).`,
      '',
      ''
    ])
    rows.push([
      'Las columnas con sufijo _xx contienen la traducción a ese idioma.',
      '',
      ''
    ])
    rows.push(['', '', ''])
    rows.push(['Columna', 'Idioma', 'Ejemplo'])

    for (const col of baseColumns) {
      rows.push([col, `${defaultLangName} (base)`, ''])
      for (const lang of nonDefaultLangs) {
        const langName = LANG_NAMES[lang] || lang
        rows.push([`${col}_${lang}`, langName, ''])
      }
    }
    rows.push(['', '', ''])
    rows.push([
      'Si una columna de traducción está vacía, se usará el valor de la columna base.',
      '',
      ''
    ])
  }

  // Tips
  rows.push(['', '', ''])
  rows.push(['CONSEJOS', '', ''])
  rows.push(['- Puedes añadir columnas extra que no estén en la plantilla.', '', ''])
  rows.push(['- Las columnas que no se usen en el diseño se ignorarán.', '', ''])
  rows.push(['- Formatos de fecha: usa AAAA-MM-DD para mejor compatibilidad.', '', ''])

  return rows
}

/**
 * Slugify a string for use in filenames.
 */
function slugify(str) {
  return (str || 'diseno')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    .substring(0, 40)
}

/**
 * TemplateDownload LiveView Hook
 * Listens for "download_template" event from the server.
 */
const TemplateDownload = {
  mounted() {
    this.handleEvent("download_template", (design) => {
      downloadTemplate(design)
    })
  }
}

export default TemplateDownload
