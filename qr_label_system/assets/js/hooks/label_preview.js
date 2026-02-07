/**
 * Label Preview Hook
 * Renders a single label preview with QR/barcode generation
 */

import QRCode from 'qrcode'
import JsBarcode from 'jsbarcode'

const MM_TO_PX = 3.78

const LabelPreview = {
  mounted() {
    this.renderPreview()
  },

  updated() {
    this.renderPreview()
  },

  async renderPreview() {
    const design = JSON.parse(this.el.dataset.design || '{}')
    const row = JSON.parse(this.el.dataset.row || '{}')
    const mapping = JSON.parse(this.el.dataset.mapping || '{}')

    // Clear container
    this.el.innerHTML = ''

    if (!design.id) {
      this.el.innerHTML = '<div class="text-gray-500">Cargando...</div>'
      return
    }

    // Calculate scale to fit in preview panel (max width ~340px to leave padding)
    const maxWidth = 340
    const maxHeight = 400
    const labelWidthPx = design.width_mm * MM_TO_PX
    const labelHeightPx = design.height_mm * MM_TO_PX

    // Calculate scale to fit within bounds
    const scaleX = maxWidth / labelWidthPx
    const scaleY = maxHeight / labelHeightPx
    const scale = Math.min(scaleX, scaleY, 2) // Cap at 2x for small labels

    // Generate codes for this row (pass label_type to differentiate single vs multiple)
    const labelType = design.label_type || 'single'
    const codes = await this.generateCodes(design.elements || [], row, mapping, scale, labelType)

    // Create label element
    const labelDiv = document.createElement('div')
    labelDiv.className = 'relative shadow-lg'
    labelDiv.style.width = `${design.width_mm * MM_TO_PX * scale}px`
    labelDiv.style.height = `${design.height_mm * MM_TO_PX * scale}px`
    labelDiv.style.backgroundColor = design.background_color || '#FFFFFF'
    labelDiv.style.border = `${Math.max((design.border_width || 0) * scale, 1)}px solid ${design.border_color || '#000000'}`
    labelDiv.style.borderRadius = `${(design.border_radius || 0) * MM_TO_PX * scale}px`
    labelDiv.style.overflow = 'hidden'

    // Render elements (sorted by z_index, skip invisible)
    const sortedElements = [...(design.elements || [])].sort((a, b) => (a.z_index || 0) - (b.z_index || 0))
    for (const element of sortedElements) {
      // Skip invisible elements
      if (element.visible === false) continue

      const elementDiv = this.renderElement(element, row, mapping, codes, scale, labelType)
      if (elementDiv) {
        labelDiv.appendChild(elementDiv)
      }
    }

    this.el.appendChild(labelDiv)
  },

  async generateCodes(elements, row, mapping, scale, labelType) {
    const codes = {}

    for (const element of elements) {
      if (element.type !== 'qr' && element.type !== 'barcode') continue

      // Try mapped data first (multiple labels), then text_content, then binding
      // This matches the canvas logic: element.text_content || element.binding || ''
      const columnName = mapping[element.id]
      const value = (columnName ? row[columnName] : null) || element.text_content || element.binding

      if (!value) continue

      if (element.type === 'qr') {
        codes[element.id] = await this.generateQR(String(value), element, scale)
      } else if (element.type === 'barcode') {
        codes[element.id] = this.generateBarcode(String(value), element, scale)
      }
    }

    return codes
  },

  async generateQR(content, config, scale) {
    try {
      return await QRCode.toDataURL(content, {
        width: Math.round((config.width || 20) * MM_TO_PX * scale),
        margin: 0,
        errorCorrectionLevel: config.qr_error_level || 'M'
      })
    } catch (err) {
      console.error('Error generating QR:', err)
      return null
    }
  },

  generateBarcode(content, config, scale) {
    try {
      const canvas = document.createElement('canvas')
      JsBarcode(canvas, content, {
        format: config.barcode_format || 'CODE128',
        width: Math.max(1, Math.round(scale)),
        height: Math.round((config.height || 15) * MM_TO_PX * scale),
        displayValue: config.barcode_show_text !== false,
        margin: 0
      })
      return canvas.toDataURL('image/png')
    } catch (err) {
      console.error('Error generating barcode:', err)
      return null
    }
  },

  renderElement(element, row, mapping, codes, scale, labelType) {
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
        const codeImg = codes[element.id]
        if (codeImg) {
          const img = document.createElement('img')
          img.src = codeImg
          img.style.width = `${element.width * scale * MM_TO_PX}px`
          img.style.height = `${element.height * scale * MM_TO_PX}px`
          div.appendChild(img)
        } else {
          // Placeholder
          div.style.width = `${element.width * scale * MM_TO_PX}px`
          div.style.height = `${element.height * scale * MM_TO_PX}px`
          div.style.backgroundColor = '#e5e7eb'
          div.style.display = 'flex'
          div.style.alignItems = 'center'
          div.style.justifyContent = 'center'
          div.style.fontSize = '12px'
          div.style.color = '#6b7280'
          div.style.border = '1px dashed #9ca3af'
          div.textContent = element.type === 'qr' ? 'QR' : 'Barcode'
        }
        break

      case 'text':
        let textContent = element.text_content || ''

        // For multiple labels, try to get value from row data
        if (labelType === 'multiple') {
          const columnName = mapping[element.id]
          if (columnName && row[columnName]) {
            textContent = row[columnName]
          } else if (element.binding && row[element.binding]) {
            textContent = row[element.binding]
          }
        }

        div.textContent = textContent || '[Texto]'
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.fontSize = `${(element.font_size || 12) * scale}px`
        div.style.fontFamily = element.font_family || 'Arial'
        div.style.fontWeight = element.font_weight || 'normal'
        div.style.color = element.color || '#000000'
        div.style.textAlign = element.text_align || 'left'
        div.style.overflow = 'visible'
        div.style.whiteSpace = 'normal'
        div.style.wordBreak = 'break-word'
        break

      case 'line':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${Math.max(element.height * scale * MM_TO_PX, 2)}px`
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

      case 'image':
        div.style.width = `${element.width * scale * MM_TO_PX}px`
        div.style.height = `${element.height * scale * MM_TO_PX}px`

        if (element.image_data) {
          // Show actual image
          const img = document.createElement('img')
          img.src = element.image_data
          img.style.width = '100%'
          img.style.height = '100%'
          img.style.objectFit = 'contain'
          div.appendChild(img)
        } else {
          // Show placeholder
          div.style.backgroundColor = '#e5e7eb'
          div.style.display = 'flex'
          div.style.alignItems = 'center'
          div.style.justifyContent = 'center'
          div.style.fontSize = '12px'
          div.style.color = '#6b7280'
          div.textContent = 'IMG'
        }
        break

      default:
        return null
    }

    return div
  }
}

export default LabelPreview
