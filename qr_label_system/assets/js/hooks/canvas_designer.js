/**
 * Canvas Designer Hook
 * Uses Fabric.js for visual label design with drag & drop
 *
 * @module CanvasDesigner
 */

import { fabric } from 'fabric'

// Constants
const PX_PER_MM = 3.78 // Pixels per mm at 96 DPI (screen standard)
const RULER_SIZE = 30 // pixels
const MAX_CANVAS_SIZE_MM = 500 // Maximum canvas dimension in mm
const MIN_CANVAS_SIZE_MM = 10 // Minimum canvas dimension in mm
const SAVE_DEBOUNCE_MS = 300 // Debounce time for save operations

const CanvasDesigner = {
  mounted() {
    this._saveTimeout = null
    this._isDestroyed = false

    try {
      this.initCanvas()
      this.setupEventListeners()
      this.pushEvent("canvas_ready", {})
    } catch (error) {
      console.error('CanvasDesigner initialization failed:', error)
    }
  },

  destroyed() {
    this._isDestroyed = true

    // Clear any pending timeouts
    if (this._saveTimeout) {
      clearTimeout(this._saveTimeout)
    }

    // Properly dispose of Fabric.js canvas to prevent memory leaks
    if (this.canvas) {
      this.canvas.dispose()
      this.canvas = null
    }

    // Clear element references
    if (this.elements) {
      this.elements.clear()
    }
  },

  /**
   * Clamps a value between min and max bounds
   */
  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  },

  /**
   * Validates and sanitizes a hex color string
   */
  sanitizeColor(color, defaultColor = '#FFFFFF') {
    if (!color || typeof color !== 'string') return defaultColor
    const hexPattern = /^#[0-9A-Fa-f]{6}$/
    return hexPattern.test(color) ? color : defaultColor
  },

  initCanvas() {
    // Parse and validate dimensions with bounds checking
    this.widthMM = this.clamp(
      parseFloat(this.el.dataset.width) || 50,
      MIN_CANVAS_SIZE_MM,
      MAX_CANVAS_SIZE_MM
    )
    this.heightMM = this.clamp(
      parseFloat(this.el.dataset.height) || 30,
      MIN_CANVAS_SIZE_MM,
      MAX_CANVAS_SIZE_MM
    )

    // Sanitize color inputs to prevent injection
    this.bgColor = this.sanitizeColor(this.el.dataset.backgroundColor, '#FFFFFF')
    this.borderColor = this.sanitizeColor(this.el.dataset.borderColor, '#000000')

    // Validate numeric inputs
    this.borderWidth = Math.max(0, parseFloat(this.el.dataset.borderWidth) || 0)
    this.borderRadius = Math.max(0, parseFloat(this.el.dataset.borderRadius) || 0)

    const canvasEl = this.el.querySelector('#label-canvas')
    if (!canvasEl) {
      return // Canvas element not found - silently fail
    }

    // Calculate canvas size
    const width = this.widthMM * PX_PER_MM
    const height = this.heightMM * PX_PER_MM
    const totalWidth = width + RULER_SIZE + 20
    const totalHeight = height + RULER_SIZE + 20

    // Initialize Fabric.js canvas
    this.canvas = new fabric.Canvas(canvasEl, {
      width: totalWidth,
      height: totalHeight,
      backgroundColor: '#f1f5f9',
      selection: true,
      preserveObjectStacking: true
    })

    this.padding = { left: RULER_SIZE + 10, top: RULER_SIZE + 10 }

    // Draw rulers
    this.drawRulers(width, height)

    // Create label background
    this.labelBg = new fabric.Rect({
      left: this.padding.left,
      top: this.padding.top,
      width: width,
      height: height,
      fill: this.bgColor,
      stroke: this.borderWidth > 0 ? this.borderColor : 'transparent',
      strokeWidth: this.borderWidth * PX_PER_MM,
      rx: this.borderRadius * PX_PER_MM,
      ry: this.borderRadius * PX_PER_MM,
      selectable: false,
      evented: false,
      shadow: new fabric.Shadow({
        color: 'rgba(0,0,0,0.1)',
        blur: 8,
        offsetX: 2,
        offsetY: 2
      })
    })
    this.canvas.add(this.labelBg)

    this.labelBounds = {
      left: this.padding.left,
      top: this.padding.top,
      width: width,
      height: height
    }

    this.elements = new Map()
  },

  drawRulers(width, height) {
    // Horizontal ruler background
    this.canvas.add(new fabric.Rect({
      left: this.padding.left,
      top: 0,
      width: width,
      height: RULER_SIZE,
      fill: '#e2e8f0',
      selectable: false,
      evented: false
    }))

    // Vertical ruler background
    this.canvas.add(new fabric.Rect({
      left: 0,
      top: this.padding.top,
      width: RULER_SIZE,
      height: height,
      fill: '#e2e8f0',
      selectable: false,
      evented: false
    }))

    // Corner
    this.canvas.add(new fabric.Rect({
      left: 0,
      top: 0,
      width: RULER_SIZE,
      height: RULER_SIZE,
      fill: '#e2e8f0',
      selectable: false,
      evented: false
    }))

    // Horizontal tick marks and labels
    for (let mm = 0; mm <= this.widthMM; mm += 5) {
      const x = this.padding.left + mm * PX_PER_MM
      const isMajor = mm % 10 === 0

      this.canvas.add(new fabric.Line(
        [x, RULER_SIZE - (isMajor ? 12 : 6), x, RULER_SIZE],
        { stroke: '#64748b', strokeWidth: 1, selectable: false, evented: false }
      ))

      if (isMajor && mm > 0 && mm < this.widthMM) {
        this.canvas.add(new fabric.Text(mm.toString(), {
          left: x,
          top: 4,
          fontSize: 10,
          fill: '#475569',
          fontFamily: 'Arial',
          originX: 'center',
          selectable: false,
          evented: false
        }))
      }
    }

    // Vertical tick marks and labels
    for (let mm = 0; mm <= this.heightMM; mm += 5) {
      const y = this.padding.top + mm * PX_PER_MM
      const isMajor = mm % 10 === 0

      this.canvas.add(new fabric.Line(
        [RULER_SIZE - (isMajor ? 12 : 6), y, RULER_SIZE, y],
        { stroke: '#64748b', strokeWidth: 1, selectable: false, evented: false }
      ))

      if (isMajor && mm > 0 && mm < this.heightMM) {
        this.canvas.add(new fabric.Text(mm.toString(), {
          left: 4,
          top: y,
          fontSize: 10,
          fill: '#475569',
          fontFamily: 'Arial',
          originY: 'center',
          selectable: false,
          evented: false
        }))
      }
    }

    // mm label in corner
    this.canvas.add(new fabric.Text('mm', {
      left: RULER_SIZE / 2,
      top: RULER_SIZE / 2,
      fontSize: 9,
      fill: '#64748b',
      fontFamily: 'Arial',
      fontWeight: 'bold',
      originX: 'center',
      originY: 'center',
      selectable: false,
      evented: false
    }))
  },

  setupEventListeners() {
    // Element selection
    this.canvas.on('selection:created', (e) => {
      const obj = e.selected?.[0]
      if (obj?.elementId) {
        this.pushEvent("element_selected", { id: obj.elementId })
      }
    })

    this.canvas.on('selection:updated', (e) => {
      const obj = e.selected?.[0]
      if (obj?.elementId) {
        this.pushEvent("element_selected", { id: obj.elementId })
      }
    })

    this.canvas.on('selection:cleared', () => {
      this.pushEvent("element_deselected", {})
    })

    // Element modification (drag, resize, rotate)
    this.canvas.on('object:modified', () => {
      this.saveElements()
    })

    // LiveView events
    this.handleEvent("load_design", ({ design }) => {
      if (design && !this._isDestroyed) {
        this.loadDesign(design)
      }
    })

    this.handleEvent("add_element", ({ element }) => {
      if (element && element.type && !this._isDestroyed) {
        this.addElement(element)
      }
    })

    this.handleEvent("update_element_property", ({ field, value }) => {
      if (field && !this._isDestroyed) {
        this.updateSelectedElement(field, value)
      }
    })

    this.handleEvent("delete_element", ({ id }) => {
      if (id && !this._isDestroyed) {
        this.deleteElement(id)
      }
    })

    this.handleEvent("update_canvas_size", (props) => {
      if (props && !this._isDestroyed) {
        this.updateCanvasSize(props)
      }
    })

    this.handleEvent("save_to_server", () => {
      if (!this._isDestroyed) {
        this.saveElementsImmediate()
      }
    })
  },

  loadDesign(design) {
    // Remove existing elements
    this.elements.forEach((obj) => this.canvas.remove(obj))
    this.elements.clear()

    // Add elements from design
    if (design.elements) {
      design.elements.forEach(el => this.addElement(el, false))
    }
    this.canvas.renderAll()
  },

  addElement(element, save = true) {
    const x = this.labelBounds.left + (element.x || 5) * PX_PER_MM
    const y = this.labelBounds.top + (element.y || 5) * PX_PER_MM

    let obj
    switch (element.type) {
      case 'qr':
        obj = this.createQR(element, x, y)
        break
      case 'barcode':
        obj = this.createBarcode(element, x, y)
        break
      case 'text':
        obj = this.createText(element, x, y)
        break
      case 'line':
        obj = this.createLine(element, x, y)
        break
      case 'rectangle':
        obj = this.createRect(element, x, y)
        break
      case 'image':
        obj = this.createImage(element, x, y)
        break
      default:
        console.warn('Unknown element type:', element.type)
        return
    }

    obj.elementId = element.id
    obj.elementType = element.type
    obj.elementData = { ...element }

    // Style the controls
    obj.set({
      cornerColor: '#3b82f6',
      cornerStyle: 'circle',
      cornerSize: 8,
      transparentCorners: false,
      borderColor: '#3b82f6',
      borderScaleFactor: 2
    })

    this.elements.set(element.id, obj)
    this.canvas.add(obj)
    this.canvas.bringToFront(obj)
    this.canvas.setActiveObject(obj)
    this.canvas.renderAll()

    if (save) {
      this.saveElements()
    }
  },

  createQR(element, x, y) {
    const size = (element.width || 20) * PX_PER_MM

    const rect = new fabric.Rect({
      width: size,
      height: size,
      fill: '#dbeafe',
      stroke: '#3b82f6',
      strokeWidth: 2,
      strokeDashArray: [4, 4]
    })

    const text = new fabric.Text('QR', {
      fontSize: size * 0.3,
      fill: '#3b82f6',
      fontWeight: 'bold',
      originX: 'center',
      originY: 'center',
      left: size / 2,
      top: size / 2
    })

    return new fabric.Group([rect, text], {
      left: x,
      top: y,
      angle: element.rotation || 0
    })
  },

  createBarcode(element, x, y) {
    const w = (element.width || 40) * PX_PER_MM
    const h = (element.height || 15) * PX_PER_MM

    const rect = new fabric.Rect({
      width: w,
      height: h,
      fill: '#dbeafe',
      stroke: '#3b82f6',
      strokeWidth: 2,
      strokeDashArray: [4, 4]
    })

    const text = new fabric.Text('BARCODE', {
      fontSize: Math.min(w, h) * 0.2,
      fill: '#3b82f6',
      fontWeight: 'bold',
      originX: 'center',
      originY: 'center',
      left: w / 2,
      top: h / 2
    })

    return new fabric.Group([rect, text], {
      left: x,
      top: y,
      angle: element.rotation || 0
    })
  },

  createText(element, x, y) {
    const content = element.text_content || element.binding || 'Texto'
    const fontSize = element.font_size || 12

    return new fabric.Textbox(content, {
      left: x,
      top: y,
      width: (element.width || 30) * PX_PER_MM,
      fontSize: fontSize,
      fontFamily: element.font_family || 'Arial',
      fontWeight: element.font_weight || 'normal',
      fill: element.color || '#000000',
      textAlign: element.text_align || 'left',
      angle: element.rotation || 0
    })
  },

  createLine(element, x, y) {
    const w = (element.width || 50) * PX_PER_MM
    const h = Math.max((element.height || 0.5) * PX_PER_MM, 2)

    return new fabric.Rect({
      left: x,
      top: y,
      width: w,
      height: h,
      fill: element.color || '#000000',
      angle: element.rotation || 0
    })
  },

  createRect(element, x, y) {
    return new fabric.Rect({
      left: x,
      top: y,
      width: (element.width || 30) * PX_PER_MM,
      height: (element.height || 20) * PX_PER_MM,
      fill: element.background_color || 'transparent',
      stroke: element.border_color || '#000000',
      strokeWidth: (element.border_width || 0.5) * PX_PER_MM,
      angle: element.rotation || 0
    })
  },

  createImage(element, x, y) {
    const w = (element.width || 20) * PX_PER_MM
    const h = (element.height || 20) * PX_PER_MM

    const rect = new fabric.Rect({
      width: w,
      height: h,
      fill: '#f1f5f9',
      stroke: '#94a3b8',
      strokeWidth: 2,
      strokeDashArray: [4, 4]
    })

    const text = new fabric.Text('IMG', {
      fontSize: Math.min(w, h) * 0.25,
      fill: '#94a3b8',
      fontWeight: 'bold',
      originX: 'center',
      originY: 'center',
      left: w / 2,
      top: h / 2
    })

    return new fabric.Group([rect, text], {
      left: x,
      top: y,
      angle: element.rotation || 0
    })
  },

  updateSelectedElement(field, value) {
    const obj = this.canvas.getActiveObject()
    if (!obj?.elementId) return

    const data = obj.elementData || {}

    // Parse numeric values
    if (['x', 'y', 'width', 'height', 'rotation', 'font_size', 'border_width'].includes(field)) {
      value = parseFloat(value) || 0
    }

    data[field] = value

    // Apply changes
    switch (field) {
      case 'x':
        obj.set('left', this.labelBounds.left + value * PX_PER_MM)
        break
      case 'y':
        obj.set('top', this.labelBounds.top + value * PX_PER_MM)
        break
      case 'rotation':
        obj.set('angle', value)
        break
      case 'color':
        obj.set('fill', value)
        break
      case 'text_content':
        if (obj.type === 'textbox') obj.set('text', value)
        break
      case 'font_size':
        if (obj.type === 'textbox') obj.set('fontSize', value)
        break
    }

    obj.elementData = data
    obj.setCoords()
    this.canvas.renderAll()
    this.saveElements()
  },

  deleteElement(id) {
    const obj = this.elements.get(id)
    if (obj) {
      this.canvas.remove(obj)
      this.elements.delete(id)
      this.canvas.renderAll()
      this.saveElements()
    }
  },

  updateCanvasSize(props) {
    // Save existing elements before clearing
    const savedElements = []
    this.elements.forEach((obj) => {
      if (obj && obj.elementData) {
        savedElements.push({ ...obj.elementData })
      }
    })

    // Update dimensions with validation
    this.widthMM = this.clamp(
      parseFloat(props.width) || this.widthMM,
      MIN_CANVAS_SIZE_MM,
      MAX_CANVAS_SIZE_MM
    )
    this.heightMM = this.clamp(
      parseFloat(props.height) || this.heightMM,
      MIN_CANVAS_SIZE_MM,
      MAX_CANVAS_SIZE_MM
    )

    // Sanitize colors
    this.bgColor = this.sanitizeColor(props.background_color, this.bgColor)
    this.borderColor = this.sanitizeColor(props.border_color, this.borderColor)

    // Validate numeric properties
    this.borderWidth = Math.max(0, parseFloat(props.border_width) || 0)
    this.borderRadius = Math.max(0, parseFloat(props.border_radius) || 0)

    const width = this.widthMM * PX_PER_MM
    const height = this.heightMM * PX_PER_MM
    const totalWidth = width + RULER_SIZE + 20
    const totalHeight = height + RULER_SIZE + 20

    // Clear and resize canvas
    this.canvas.clear()
    this.canvas.setWidth(totalWidth)
    this.canvas.setHeight(totalHeight)
    this.elements.clear()

    // Redraw rulers
    this.drawRulers(width, height)

    // Recreate label background
    this.labelBg = new fabric.Rect({
      left: this.padding.left,
      top: this.padding.top,
      width: width,
      height: height,
      fill: this.bgColor,
      stroke: this.borderWidth > 0 ? this.borderColor : 'transparent',
      strokeWidth: this.borderWidth * PX_PER_MM,
      rx: this.borderRadius * PX_PER_MM,
      ry: this.borderRadius * PX_PER_MM,
      selectable: false,
      evented: false,
      shadow: new fabric.Shadow({
        color: 'rgba(0,0,0,0.1)',
        blur: 8,
        offsetX: 2,
        offsetY: 2
      })
    })
    this.canvas.add(this.labelBg)

    this.labelBounds = {
      left: this.padding.left,
      top: this.padding.top,
      width: width,
      height: height
    }

    // Re-add elements
    savedElements.forEach(el => this.addElement(el, false))

    this.canvas.renderAll()
  },

  /**
   * Debounced save to prevent excessive server calls during drag operations
   */
  saveElements() {
    if (this._isDestroyed) return

    // Clear any existing timeout
    if (this._saveTimeout) {
      clearTimeout(this._saveTimeout)
    }

    // Debounce the save operation
    this._saveTimeout = setTimeout(() => {
      this.saveElementsImmediate()
    }, SAVE_DEBOUNCE_MS)
  },

  /**
   * Immediate save without debouncing (used for explicit save actions)
   */
  saveElementsImmediate() {
    if (this._isDestroyed || !this.elements) return

    const elements = []

    this.elements.forEach((obj, id) => {
      if (!obj || !obj.elementType) return

      const data = obj.elementData || {}
      elements.push({
        ...data,
        id: id,
        type: obj.elementType,
        x: Math.round(((obj.left - this.labelBounds.left) / PX_PER_MM) * 100) / 100,
        y: Math.round(((obj.top - this.labelBounds.top) / PX_PER_MM) * 100) / 100,
        width: Math.round(((obj.width * (obj.scaleX || 1)) / PX_PER_MM) * 100) / 100,
        height: Math.round(((obj.height * (obj.scaleY || 1)) / PX_PER_MM) * 100) / 100,
        rotation: Math.round((obj.angle || 0) * 100) / 100
      })
    })

    this.pushEvent("element_modified", { elements })
  }
}

export default CanvasDesigner
