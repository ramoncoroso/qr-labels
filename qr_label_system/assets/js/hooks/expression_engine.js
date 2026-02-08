/**
 * Expression Engine
 * Evaluates {{}} expressions in element bindings.
 *
 * If binding contains `{{`, it's an expression template.
 * Otherwise it's a plain column reference (backwards compatible).
 *
 * Functions use Spanish names: HOY(), MAYUS(), CONTADOR(), SI(), etc.
 * Security: NO eval(). All functions are whitelisted.
 *
 * @module ExpressionEngine
 */

// ─── Core API ─────────────────────────────────────────────────

/**
 * Check if a binding string is an expression (contains `{{`)
 */
export function isExpression(binding) {
  return typeof binding === 'string' && binding.includes('{{')
}

/**
 * Evaluate a template string, replacing all {{...}} with resolved values.
 * @param {string} template - e.g. "Lote: {{lote}} - {{HOY()}}"
 * @param {Object} row - CSV row data, e.g. { lote: "A1", nombre: "Test" }
 * @param {Object} context - { rowIndex, batchSize, now }
 * @returns {string}
 */
export function evaluate(template, row = {}, context = {}) {
  if (!template || typeof template !== 'string') return template || ''
  if (!template.includes('{{')) return template

  return template.replace(/\{\{(.+?)\}\}/g, (_match, expr) => {
    try {
      return resolveExpression(expr.trim(), row, context)
    } catch (_e) {
      return '#ERR#'
    }
  })
}

/**
 * Resolve the final text for an element, handling expressions, bindings, and fallbacks.
 * @param {Object} element - design element
 * @param {Object} row - CSV row data (may be empty)
 * @param {Object|null} mapping - column_mapping { elementId: columnName }
 * @param {Object} context - { rowIndex, batchSize, now }
 * @returns {string}
 */
export function resolveText(element, row = {}, mapping = null, context = {}) {
  const binding = element.binding
  const textContent = element.text_content || ''

  // 1. Expression mode: binding contains {{
  if (isExpression(binding)) {
    return evaluate(binding, row, context)
  }

  // 2. Column binding mode (plain binding without {{)
  if (binding && binding !== '') {
    // Try mapped column first
    if (mapping && mapping[element.id]) {
      const col = mapping[element.id]
      if (row[col] != null) return String(row[col])
    }
    // Direct binding match
    if (row[binding] != null) return String(row[binding])
    // No data available, return text_content as fallback
    return textContent
  }

  // 3. Fixed text mode (no binding)
  return textContent
}

/**
 * Resolve value for QR/barcode elements (similar to text but returns the code value).
 */
export function resolveCodeValue(element, row = {}, mapping = null, context = {}) {
  const binding = element.binding
  const textContent = element.text_content || element.binding || ''

  // 1. Expression mode
  if (isExpression(binding)) {
    return evaluate(binding, row, context)
  }

  // 2. Mapped column
  if (mapping && mapping[element.id]) {
    const col = mapping[element.id]
    if (row[col] != null) return String(row[col])
  }

  // 3. Direct binding
  if (binding && row[binding] != null) {
    return String(row[binding])
  }

  // 4. Static content
  return element.text_content || element.binding || ''
}

// ─── Expression resolver ──────────────────────────────────────

function resolveExpression(expr, row, context) {
  // Check for default operator: expr || alternative
  if (expr.includes('||')) {
    const parts = expr.split('||').map(s => s.trim())
    const primary = resolveExpression(parts[0], row, context)
    if (primary && primary !== '' && primary !== '#ERR#') return primary
    return resolveExpression(parts.slice(1).join('||'), row, context)
  }

  // Function call: NAME(args...)
  if (expr.includes('(')) {
    return resolveFunction(expr, row, context)
  }

  // Simple column reference
  if (row[expr] != null) return String(row[expr])

  // Try case-insensitive match
  const key = Object.keys(row).find(k => k.toLowerCase() === expr.toLowerCase())
  if (key && row[key] != null) return String(row[key])

  return ''
}

// ─── Function parser ──────────────────────────────────────────

function resolveFunction(expr, row, context) {
  const parenIdx = expr.indexOf('(')
  const name = expr.substring(0, parenIdx).trim().toUpperCase()
  const argsStr = expr.substring(parenIdx + 1, expr.lastIndexOf(')'))
  const args = parseArgs(argsStr, row, context)

  const fn = FUNCTIONS[name]
  if (!fn) return '#ERR#'
  return fn(args, row, context)
}

/**
 * Parse function arguments, handling nested functions and quoted strings.
 */
function parseArgs(argsStr, row, context) {
  if (!argsStr.trim()) return []

  const args = []
  let current = ''
  let depth = 0
  let inQuote = false
  let quoteChar = ''

  for (let i = 0; i < argsStr.length; i++) {
    const ch = argsStr[i]

    if (inQuote) {
      if (ch === quoteChar) {
        inQuote = false
      } else {
        current += ch
      }
      continue
    }

    if (ch === '"' || ch === "'") {
      inQuote = true
      quoteChar = ch
      continue
    }

    if (ch === '(') { depth++; current += ch; continue }
    if (ch === ')') { depth--; current += ch; continue }

    if (ch === ',' && depth === 0) {
      args.push(resolveArg(current.trim(), row, context))
      current = ''
      continue
    }

    current += ch
  }

  if (current.trim()) {
    args.push(resolveArg(current.trim(), row, context))
  }

  return args
}

/**
 * Resolve a single argument: could be a nested function, column ref, number, or literal.
 */
function resolveArg(arg, row, context) {
  if (!arg) return ''

  // Nested function
  if (arg.includes('(')) {
    return resolveFunction(arg, row, context)
  }

  // Numeric literal
  if (/^-?\d+(\.\d+)?$/.test(arg)) {
    return arg
  }

  // Column reference (if exists in row)
  if (row[arg] != null) return String(row[arg])
  const key = Object.keys(row).find(k => k.toLowerCase() === arg.toLowerCase())
  if (key && row[key] != null) return String(row[key])

  // Return as literal string
  return arg
}

// ─── Function registry ────────────────────────────────────────

const FUNCTIONS = {}

// --- Text functions ---

FUNCTIONS['MAYUS'] = (args) => {
  return String(args[0] || '').toUpperCase()
}

FUNCTIONS['MINUS'] = (args) => {
  return String(args[0] || '').toLowerCase()
}

FUNCTIONS['RECORTAR'] = (args) => {
  const val = String(args[0] || '')
  const len = parseInt(args[1]) || val.length
  return val.substring(0, len)
}

FUNCTIONS['CONCAT'] = (args) => {
  return args.map(a => String(a || '')).join('')
}

FUNCTIONS['REEMPLAZAR'] = (args) => {
  const val = String(args[0] || '')
  const search = String(args[1] || '')
  const replace = String(args[2] || '')
  if (!search) return val
  return val.split(search).join(replace)
}

FUNCTIONS['LARGO'] = (args) => {
  return String(String(args[0] || '').length)
}

// --- Date functions ---

function formatDate(date, fmt) {
  if (!fmt) fmt = 'DD/MM/AAAA'
  const d = String(date.getDate()).padStart(2, '0')
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const yyyy = String(date.getFullYear())
  const yy = yyyy.slice(-2)
  const hh = String(date.getHours()).padStart(2, '0')
  const mm = String(date.getMinutes()).padStart(2, '0')
  const ss = String(date.getSeconds()).padStart(2, '0')

  return fmt
    .replace('DD', d)
    .replace('MM', m)
    .replace('AAAA', yyyy)
    .replace('AA', yy)
    .replace('hh', hh)
    .replace('mm', mm)
    .replace('ss', ss)
}

function parseDate(str) {
  if (str instanceof Date) return str
  const d = new Date(str)
  return isNaN(d.getTime()) ? new Date() : d
}

FUNCTIONS['HOY'] = (args, _row, context) => {
  const now = context.now || new Date()
  return formatDate(now, args[0] || 'DD/MM/AAAA')
}

FUNCTIONS['AHORA'] = (args, _row, context) => {
  const now = context.now || new Date()
  return formatDate(now, args[0] || 'DD/MM/AAAA hh:mm')
}

FUNCTIONS['SUMAR_DIAS'] = (args, _row, context) => {
  const base = args[0] ? parseDate(args[0]) : (context.now || new Date())
  const days = parseInt(args[1]) || 0
  const result = new Date(base)
  result.setDate(result.getDate() + days)
  return formatDate(result, args[2] || 'DD/MM/AAAA')
}

FUNCTIONS['SUMAR_MESES'] = (args, _row, context) => {
  const base = args[0] ? parseDate(args[0]) : (context.now || new Date())
  const months = parseInt(args[1]) || 0
  const result = new Date(base)
  result.setMonth(result.getMonth() + months)
  return formatDate(result, args[2] || 'DD/MM/AAAA')
}

FUNCTIONS['FORMATO_FECHA'] = (args) => {
  const date = parseDate(args[0])
  return formatDate(date, args[1] || 'DD/MM/AAAA')
}

// --- Counter functions ---

FUNCTIONS['CONTADOR'] = (args, _row, context) => {
  const start = parseInt(args[0]) || 1
  const step = parseInt(args[1]) || 1
  const padding = parseInt(args[2]) || 0
  const idx = context.rowIndex || 0
  const value = start + (idx * step)
  return padding > 0 ? String(value).padStart(padding, '0') : String(value)
}

FUNCTIONS['LOTE'] = (args, _row, context) => {
  const fmt = args[0] || 'AAMM-####'
  const now = context.now || new Date()
  const yyyy = String(now.getFullYear())
  const yy = yyyy.slice(-2)
  const mm = String(now.getMonth() + 1).padStart(2, '0')
  const dd = String(now.getDate()).padStart(2, '0')
  const idx = (context.rowIndex || 0) + 1

  let result = fmt
    .replace('AAAA', yyyy)
    .replace('AA', yy)
    .replace('MM', mm)
    .replace('DD', dd)

  // Replace # sequences with counter: #### → 0001
  result = result.replace(/#+/g, (match) => {
    return String(idx).padStart(match.length, '0')
  })

  return result
}

FUNCTIONS['REDONDEAR'] = (args) => {
  const val = parseFloat(args[0]) || 0
  const dec = parseInt(args[1]) || 0
  return val.toFixed(dec)
}

FUNCTIONS['FORMATO_NUM'] = (args) => {
  const val = parseFloat(args[0]) || 0
  const dec = parseInt(args[1]) || 0
  const sep = args[2] || '.'
  const formatted = val.toFixed(dec)
  if (sep === ',') {
    return formatted.replace('.', ',')
  }
  return formatted
}

// --- Conditional functions ---

FUNCTIONS['SI'] = (args) => {
  const condStr = String(args[0] || '')
  const trueVal = args[1] !== undefined ? args[1] : ''
  const falseVal = args[2] !== undefined ? args[2] : ''

  // Parse condition: left op right
  const ops = ['==', '!=', '>=', '<=', '>', '<']
  for (const op of ops) {
    const idx = condStr.indexOf(op)
    if (idx !== -1) {
      const left = condStr.substring(0, idx).trim()
      const right = condStr.substring(idx + op.length).trim()
      return evalCondition(left, op, right) ? trueVal : falseVal
    }
  }

  // No operator found: truthy check
  return condStr && condStr !== '0' && condStr !== 'false' && condStr !== '' ? trueVal : falseVal
}

function evalCondition(left, op, right) {
  // Try numeric comparison
  const numL = parseFloat(left)
  const numR = parseFloat(right)
  const isNumeric = !isNaN(numL) && !isNaN(numR)

  switch (op) {
    case '==': return isNumeric ? numL === numR : left === right
    case '!=': return isNumeric ? numL !== numR : left !== right
    case '>':  return isNumeric ? numL > numR : left > right
    case '<':  return isNumeric ? numL < numR : left < right
    case '>=': return isNumeric ? numL >= numR : left >= right
    case '<=': return isNumeric ? numL <= numR : left <= right
    default: return false
  }
}

FUNCTIONS['VACIO'] = (args) => {
  const val = String(args[0] || '')
  return val === '' ? 'true' : 'false'
}

FUNCTIONS['POR_DEFECTO'] = (args) => {
  const val = String(args[0] || '')
  const alt = args[1] !== undefined ? String(args[1]) : ''
  return val !== '' ? val : alt
}

// ─── Available functions list (for UI) ────────────────────────

export const FUNCTION_GROUPS = [
  {
    name: 'Texto',
    functions: [
      { name: 'MAYUS', template: 'MAYUS(valor)', desc: 'Convierte a mayúsculas' },
      { name: 'MINUS', template: 'MINUS(valor)', desc: 'Convierte a minúsculas' },
      { name: 'RECORTAR', template: 'RECORTAR(valor, largo)', desc: 'Recorta texto' },
      { name: 'CONCAT', template: 'CONCAT(v1, v2)', desc: 'Concatena valores' },
      { name: 'REEMPLAZAR', template: 'REEMPLAZAR(valor, buscar, reemplazo)', desc: 'Reemplaza texto' },
      { name: 'LARGO', template: 'LARGO(valor)', desc: 'Largo del texto' }
    ]
  },
  {
    name: 'Fechas',
    functions: [
      { name: 'HOY', template: 'HOY()', desc: 'Fecha actual' },
      { name: 'AHORA', template: 'AHORA()', desc: 'Fecha y hora actual' },
      { name: 'SUMAR_DIAS', template: 'SUMAR_DIAS(HOY(), 30)', desc: 'Suma días a fecha' },
      { name: 'SUMAR_MESES', template: 'SUMAR_MESES(HOY(), 6)', desc: 'Suma meses a fecha' },
      { name: 'FORMATO_FECHA', template: 'FORMATO_FECHA(valor, DD/MM/AAAA)', desc: 'Formatea fecha' }
    ]
  },
  {
    name: 'Contadores',
    functions: [
      { name: 'CONTADOR', template: 'CONTADOR(1, 1, 4)', desc: 'Contador secuencial' },
      { name: 'LOTE', template: 'LOTE(AAMM-####)', desc: 'Código de lote' },
      { name: 'REDONDEAR', template: 'REDONDEAR(valor, 2)', desc: 'Redondea número' },
      { name: 'FORMATO_NUM', template: 'FORMATO_NUM(valor, 2, ",")', desc: 'Formatea número' }
    ]
  },
  {
    name: 'Condicionales',
    functions: [
      { name: 'SI', template: 'SI(valor == X, si, no)', desc: 'Condición SI/SINO' },
      { name: 'VACIO', template: 'VACIO(valor)', desc: 'Verifica si está vacío' },
      { name: 'POR_DEFECTO', template: 'POR_DEFECTO(valor, alternativa)', desc: 'Valor por defecto' }
    ]
  }
]
