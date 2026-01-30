/**
 * Canvas Designer Hook
 * Uses Fabric.js for visual label design with drag & drop
 *
 * @module CanvasDesigner
 */

import { fabric } from 'fabric'

// Constants
const PX_PER_MM = 6 // Fixed pixels per mm - good balance between size and usability
const RULER_SIZE = 35 // pixels
const MAX_CANVAS_SIZE_MM = 500 // Maximum canvas dimension in mm
const MIN_CANVAS_SIZE_MM = 10 // Minimum canvas dimension in mm
const SAVE_DEBOUNCE_MS = 300 // Debounce time for save operations

const CanvasDesigner = {
  mounted() {
    console.log('CanvasDesigner: mounted() called')
    this._saveTimeout = null
    this._isDestroyed = false
    this._alignmentLines = []

    // Snap settings
    this.snapEnabled = this.el.dataset.snapEnabled === 'true'
    this.gridSnapEnabled = this.el.dataset.gridSnapEnabled === 'true'
    this.gridSize = parseFloat(this.el.dataset.gridSize) || 5
    this.snapThreshold = parseFloat(this.el.dataset.snapThreshold) || 5

    try {
      console.log('CanvasDesigner: initializing canvas...')
      this.initCanvas()
      console.log('CanvasDesigner: setting up event listeners...')
      this.setupEventListeners()
      console.log('CanvasDesigner: pushing canvas_ready event...')
      this.pushEvent("canvas_ready", {})
      console.log('CanvasDesigner: initialization complete')
    } catch (error) {
      console.error('CanvasDesigner initialization failed:', error)
      console.error('Stack trace:', error.stack)
    }
  },

  destroyed() {
    this._isDestroyed = true

    // Clear any pending timeouts
    if (this._saveTimeout) {
      clearTimeout(this._saveTimeout)
    }

    // Clear alignment lines
    this.clearAlignmentLines()

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
    // Element selection - support multi-selection
    this.canvas.on('selection:created', (e) => {
      const selected = e.selected || []
      if (selected.length === 1 && selected[0]?.elementId) {
        this.pushEvent("element_selected", { id: selected[0].elementId })
      } else if (selected.length > 1) {
        const ids = selected.filter(obj => obj.elementId).map(obj => obj.elementId)
        this.pushEvent("elements_selected", { ids })
      }
    })

    this.canvas.on('selection:updated', (e) => {
      const selected = e.selected || []
      if (selected.length === 1 && selected[0]?.elementId) {
        this.pushEvent("element_selected", { id: selected[0].elementId })
      } else if (selected.length > 1) {
        const ids = selected.filter(obj => obj.elementId).map(obj => obj.elementId)
        this.pushEvent("elements_selected", { ids })
      }
    })

    this.canvas.on('selection:cleared', () => {
      this.pushEvent("element_deselected", {})
    })

    // Element modification (drag, resize, rotate)
    this.canvas.on('object:modified', (e) => {
      this.clearAlignmentLines()
      // Mark the element as modified so we know to recalculate its dimensions
      if (e.target && e.target.elementId) {
        e.target._wasModified = true
      }
      this.saveElements()
    })

    // Snap while moving
    this.canvas.on('object:moving', (e) => {
      if (this.snapEnabled || this.gridSnapEnabled) {
        this.handleSnap(e.target)
      }
    })

    // Clear alignment lines when done moving
    this.canvas.on('mouse:up', () => {
      this.clearAlignmentLines()
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

    // Image upload
    this.handleEvent("update_element_image", ({ element_id, image_data, image_filename }) => {
      if (!this._isDestroyed) {
        this.updateElementImage(element_id, image_data, image_filename)
      }
    })

    // Multi-selection
    this.handleEvent("paste_elements", ({ elements, offset }) => {
      if (!this._isDestroyed) {
        this.pasteElements(elements, offset)
      }
    })

    this.handleEvent("select_all", () => {
      if (!this._isDestroyed) {
        this.selectAllElements()
      }
    })

    this.handleEvent("select_element", ({ id }) => {
      if (!this._isDestroyed) {
        this.selectElement(id)
      }
    })

    // Alignment
    this.handleEvent("align_elements", ({ direction }) => {
      if (!this._isDestroyed) {
        this.alignElements(direction)
      }
    })

    this.handleEvent("distribute_elements", ({ direction }) => {
      if (!this._isDestroyed) {
        this.distributeElements(direction)
      }
    })

    // Layer management
    this.handleEvent("reorder_layers", ({ ordered_ids }) => {
      if (!this._isDestroyed) {
        this.reorderLayers(ordered_ids)
      }
    })

    this.handleEvent("toggle_visibility", ({ id }) => {
      if (!this._isDestroyed) {
        this.toggleElementVisibility(id)
      }
    })

    this.handleEvent("toggle_lock", ({ id }) => {
      if (!this._isDestroyed) {
        this.toggleElementLock(id)
      }
    })

    this.handleEvent("bring_to_front", ({ id }) => {
      if (!this._isDestroyed) {
        this.bringToFront(id)
      }
    })

    this.handleEvent("send_to_back", ({ id }) => {
      if (!this._isDestroyed) {
        this.sendToBack(id)
      }
    })

    this.handleEvent("move_layer_up", ({ id }) => {
      if (!this._isDestroyed) {
        this.moveLayerUp(id)
      }
    })

    this.handleEvent("move_layer_down", ({ id }) => {
      if (!this._isDestroyed) {
        this.moveLayerDown(id)
      }
    })

    this.handleEvent("rename_element", ({ id, name }) => {
      if (!this._isDestroyed) {
        this.renameElement(id, name)
      }
    })

    // Snap settings
    this.handleEvent("update_snap_settings", ({ snap_enabled, grid_snap_enabled, grid_size }) => {
      if (!this._isDestroyed) {
        this.snapEnabled = snap_enabled
        this.gridSnapEnabled = grid_snap_enabled
        this.gridSize = grid_size
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

    // Handle visibility
    const isVisible = element.visible !== false
    obj.set('visible', isVisible)

    // Handle locked state
    const isLocked = element.locked === true
    obj.set({
      selectable: !isLocked,
      evented: !isLocked,
      lockMovementX: isLocked,
      lockMovementY: isLocked,
      lockRotation: isLocked,
      lockScalingX: isLocked,
      lockScalingY: isLocked
    })

    // Style the controls
    obj.set({
      cornerColor: '#3b82f6',
      cornerStyle: 'circle',
      cornerSize: 8,
      transparentCorners: false,
      borderColor: isLocked ? '#f59e0b' : '#3b82f6',
      borderScaleFactor: 2
    })

    this.elements.set(element.id, obj)
    this.canvas.add(obj)

    // Handle z-index ordering
    if (element.z_index !== undefined) {
      this.applyZIndexOrdering()
    } else {
      this.canvas.bringToFront(obj)
    }

    if (save) {
      this.canvas.setActiveObject(obj)
    }
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

    // If we have image data, load the actual image
    if (element.image_data) {
      // Create a placeholder first, then load image asynchronously
      const placeholder = this.createImagePlaceholder(w, h, x, y, element.rotation)
      placeholder._imageLoading = true

      // Load image asynchronously
      fabric.Image.fromURL(element.image_data, (img) => {
        if (this._isDestroyed) return

        const obj = this.elements.get(element.id)
        if (!obj || !obj._imageLoading) return

        // Calculate scale to fit the target dimensions
        const scaleX = w / img.width
        const scaleY = h / img.height

        img.set({
          left: x,
          top: y,
          scaleX: scaleX,
          scaleY: scaleY,
          angle: element.rotation || 0
        })

        // Copy over element data
        img.elementId = obj.elementId
        img.elementType = obj.elementType
        img.elementData = obj.elementData

        // Copy visibility and lock state
        img.set({
          visible: obj.visible,
          selectable: obj.selectable,
          evented: obj.evented,
          lockMovementX: obj.lockMovementX,
          lockMovementY: obj.lockMovementY,
          lockRotation: obj.lockRotation,
          lockScalingX: obj.lockScalingX,
          lockScalingY: obj.lockScalingY,
          cornerColor: '#3b82f6',
          cornerStyle: 'circle',
          cornerSize: 8,
          transparentCorners: false,
          borderColor: '#3b82f6',
          borderScaleFactor: 2
        })

        // Replace placeholder with actual image
        this.canvas.remove(obj)
        this.elements.set(element.id, img)
        this.canvas.add(img)
        this.applyZIndexOrdering()
        this.canvas.renderAll()
      }, { crossOrigin: 'anonymous' })

      return placeholder
    }

    // No image data - show placeholder
    return this.createImagePlaceholder(w, h, x, y, element.rotation)
  },

  createImagePlaceholder(w, h, x, y, rotation) {
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
      angle: rotation || 0
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

      // Calculate position from canvas coordinates
      const currentX = Math.round(((obj.left - this.labelBounds.left) / PX_PER_MM) * 100) / 100
      const currentY = Math.round(((obj.top - this.labelBounds.top) / PX_PER_MM) * 100) / 100

      // IMPORTANT: Preserve original width/height from elementData
      // Only update them if the element was explicitly resized (scaleX/scaleY != 1)
      let width = data.width
      let height = data.height

      // If element was scaled by user, recalculate dimensions
      const scaleX = obj.scaleX || 1
      const scaleY = obj.scaleY || 1
      if (Math.abs(scaleX - 1) > 0.01 || Math.abs(scaleY - 1) > 0.01) {
        // Element was resized - calculate new dimensions
        width = Math.round((data.width * scaleX) * 100) / 100
        height = Math.round((data.height * scaleY) * 100) / 100
        // Reset scale and update data
        obj.set({ scaleX: 1, scaleY: 1 })
        obj.setCoords()
        data.width = width
        data.height = height
        obj.elementData = data
      }

      elements.push({
        ...data,
        id: id,
        type: obj.elementType,
        x: currentX,
        y: currentY,
        width: width,
        height: height,
        rotation: Math.round((obj.angle || 0) * 100) / 100,
        visible: obj.visible !== false,
        locked: obj.lockMovementX === true,
        z_index: data.z_index || 0,
        name: data.name
      })
    })

    this.pushEvent("element_modified", { elements })
  },

  // ============================================================================
  // Image Methods
  // ============================================================================

  updateElementImage(elementId, imageData, imageFilename) {
    const obj = this.elements.get(elementId)
    if (!obj) return

    const data = obj.elementData || {}
    data.image_data = imageData
    data.image_filename = imageFilename
    obj.elementData = data

    // Reload the element with the new image
    const x = obj.left
    const y = obj.top
    const w = (obj.width * (obj.scaleX || 1))
    const h = (obj.height * (obj.scaleY || 1))
    const angle = obj.angle

    fabric.Image.fromURL(imageData, (img) => {
      if (this._isDestroyed) return

      const scaleX = w / img.width
      const scaleY = h / img.height

      img.set({
        left: x,
        top: y,
        scaleX: scaleX,
        scaleY: scaleY,
        angle: angle,
        cornerColor: '#3b82f6',
        cornerStyle: 'circle',
        cornerSize: 8,
        transparentCorners: false,
        borderColor: '#3b82f6',
        borderScaleFactor: 2
      })

      img.elementId = elementId
      img.elementType = 'image'
      img.elementData = data

      this.canvas.remove(obj)
      this.elements.set(elementId, img)
      this.canvas.add(img)
      this.applyZIndexOrdering()
      this.canvas.setActiveObject(img)
      this.canvas.renderAll()
      this.saveElements()
    }, { crossOrigin: 'anonymous' })
  },

  // ============================================================================
  // Multi-selection Methods
  // ============================================================================

  selectAllElements() {
    const objects = []
    this.elements.forEach((obj) => {
      if (obj.selectable && obj.visible) {
        objects.push(obj)
      }
    })

    if (objects.length > 0) {
      this.canvas.discardActiveObject()
      const selection = new fabric.ActiveSelection(objects, { canvas: this.canvas })
      this.canvas.setActiveObject(selection)
      this.canvas.renderAll()

      const ids = objects.map(obj => obj.elementId)
      this.pushEvent("elements_selected", { ids })
    }
  },

  selectElement(id) {
    const obj = this.elements.get(id)
    if (obj && obj.selectable) {
      this.canvas.discardActiveObject()
      this.canvas.setActiveObject(obj)
      this.canvas.renderAll()
    }
  },

  pasteElements(elements, offset) {
    const newElements = []

    elements.forEach(el => {
      const newElement = {
        ...el,
        id: this.generateId(),
        x: (el.x || 0) + offset,
        y: (el.y || 0) + offset,
        name: el.name ? `${el.name} (copia)` : undefined
      }
      this.addElement(newElement, false)
      newElements.push(this.elements.get(newElement.id))
    })

    // Select the pasted elements
    if (newElements.length > 0) {
      this.canvas.discardActiveObject()
      if (newElements.length === 1) {
        this.canvas.setActiveObject(newElements[0])
      } else {
        const selection = new fabric.ActiveSelection(newElements, { canvas: this.canvas })
        this.canvas.setActiveObject(selection)
      }
      this.canvas.renderAll()
    }

    this.saveElements()
  },

  generateId() {
    return 'el_' + Math.random().toString(36).substr(2, 9)
  },

  // ============================================================================
  // Alignment Methods
  // ============================================================================

  alignElements(direction) {
    const activeObj = this.canvas.getActiveObject()
    if (!activeObj || activeObj.type !== 'activeSelection') return

    const objects = activeObj.getObjects()
    if (objects.length < 2) return

    // Get bounds of all objects
    const bounds = objects.map(obj => {
      const coords = obj.getCoords()
      return {
        obj,
        left: Math.min(...coords.map(c => c.x)),
        right: Math.max(...coords.map(c => c.x)),
        top: Math.min(...coords.map(c => c.y)),
        bottom: Math.max(...coords.map(c => c.y)),
        centerX: obj.left + (obj.width * (obj.scaleX || 1)) / 2,
        centerY: obj.top + (obj.height * (obj.scaleY || 1)) / 2
      }
    })

    let targetValue

    switch (direction) {
      case 'left':
        targetValue = Math.min(...bounds.map(b => b.left))
        bounds.forEach(b => {
          b.obj.set('left', b.obj.left + (targetValue - b.left))
        })
        break
      case 'center':
        const minLeft = Math.min(...bounds.map(b => b.left))
        const maxRight = Math.max(...bounds.map(b => b.right))
        targetValue = (minLeft + maxRight) / 2
        bounds.forEach(b => {
          b.obj.set('left', b.obj.left + (targetValue - b.centerX))
        })
        break
      case 'right':
        targetValue = Math.max(...bounds.map(b => b.right))
        bounds.forEach(b => {
          b.obj.set('left', b.obj.left + (targetValue - b.right))
        })
        break
      case 'top':
        targetValue = Math.min(...bounds.map(b => b.top))
        bounds.forEach(b => {
          b.obj.set('top', b.obj.top + (targetValue - b.top))
        })
        break
      case 'middle':
        const minTop = Math.min(...bounds.map(b => b.top))
        const maxBottom = Math.max(...bounds.map(b => b.bottom))
        targetValue = (minTop + maxBottom) / 2
        bounds.forEach(b => {
          b.obj.set('top', b.obj.top + (targetValue - b.centerY))
        })
        break
      case 'bottom':
        targetValue = Math.max(...bounds.map(b => b.bottom))
        bounds.forEach(b => {
          b.obj.set('top', b.obj.top + (targetValue - b.bottom))
        })
        break
    }

    this.canvas.renderAll()
    this.saveElements()
  },

  distributeElements(direction) {
    const activeObj = this.canvas.getActiveObject()
    if (!activeObj || activeObj.type !== 'activeSelection') return

    const objects = activeObj.getObjects()
    if (objects.length < 3) return

    const bounds = objects.map(obj => ({
      obj,
      left: obj.left,
      top: obj.top,
      width: obj.width * (obj.scaleX || 1),
      height: obj.height * (obj.scaleY || 1),
      centerX: obj.left + (obj.width * (obj.scaleX || 1)) / 2,
      centerY: obj.top + (obj.height * (obj.scaleY || 1)) / 2
    }))

    if (direction === 'horizontal') {
      bounds.sort((a, b) => a.centerX - b.centerX)
      const first = bounds[0]
      const last = bounds[bounds.length - 1]
      const totalSpace = last.centerX - first.centerX
      const spacing = totalSpace / (bounds.length - 1)

      bounds.forEach((b, i) => {
        if (i > 0 && i < bounds.length - 1) {
          const newCenterX = first.centerX + spacing * i
          b.obj.set('left', newCenterX - b.width / 2)
        }
      })
    } else if (direction === 'vertical') {
      bounds.sort((a, b) => a.centerY - b.centerY)
      const first = bounds[0]
      const last = bounds[bounds.length - 1]
      const totalSpace = last.centerY - first.centerY
      const spacing = totalSpace / (bounds.length - 1)

      bounds.forEach((b, i) => {
        if (i > 0 && i < bounds.length - 1) {
          const newCenterY = first.centerY + spacing * i
          b.obj.set('top', newCenterY - b.height / 2)
        }
      })
    }

    this.canvas.renderAll()
    this.saveElements()
  },

  // ============================================================================
  // Layer Management Methods
  // ============================================================================

  applyZIndexOrdering() {
    // Get all elements sorted by z_index
    const sorted = []
    this.elements.forEach((obj, id) => {
      const zIndex = obj.elementData?.z_index || 0
      sorted.push({ obj, zIndex })
    })
    sorted.sort((a, b) => a.zIndex - b.zIndex)

    // Re-order on canvas (lower z_index = further back)
    sorted.forEach(item => {
      this.canvas.bringToFront(item.obj)
    })
  },

  reorderLayers(orderedIds) {
    // Update z_index based on new order (first = highest z_index)
    orderedIds.forEach((id, index) => {
      const obj = this.elements.get(id)
      if (obj && obj.elementData) {
        obj.elementData.z_index = orderedIds.length - 1 - index
      }
    })

    this.applyZIndexOrdering()
    this.canvas.renderAll()
    this.saveElements()
  },

  toggleElementVisibility(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    const isVisible = !obj.visible
    obj.set('visible', isVisible)
    obj.elementData.visible = isVisible

    if (!isVisible && this.canvas.getActiveObject() === obj) {
      this.canvas.discardActiveObject()
    }

    this.canvas.renderAll()
    this.saveElements()
  },

  toggleElementLock(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    const isLocked = !obj.lockMovementX
    obj.set({
      selectable: !isLocked,
      evented: !isLocked,
      lockMovementX: isLocked,
      lockMovementY: isLocked,
      lockRotation: isLocked,
      lockScalingX: isLocked,
      lockScalingY: isLocked,
      borderColor: isLocked ? '#f59e0b' : '#3b82f6'
    })
    obj.elementData.locked = isLocked

    if (isLocked && this.canvas.getActiveObject() === obj) {
      this.canvas.discardActiveObject()
    }

    this.canvas.renderAll()
    this.saveElements()
  },

  bringToFront(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    // Find max z_index
    let maxZ = 0
    this.elements.forEach((o) => {
      const z = o.elementData?.z_index || 0
      if (z > maxZ) maxZ = z
    })

    obj.elementData.z_index = maxZ + 1
    this.canvas.bringToFront(obj)
    this.canvas.renderAll()
    this.saveElements()
  },

  sendToBack(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    // Find min z_index
    let minZ = 0
    this.elements.forEach((o) => {
      const z = o.elementData?.z_index || 0
      if (z < minZ) minZ = z
    })

    obj.elementData.z_index = minZ - 1
    this.applyZIndexOrdering()
    this.canvas.renderAll()
    this.saveElements()
  },

  moveLayerUp(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    const currentZ = obj.elementData?.z_index || 0

    // Find the object just above this one
    let nextHigherZ = null
    let nextHigherObj = null
    this.elements.forEach((o, oId) => {
      if (oId === id) return
      const z = o.elementData?.z_index || 0
      if (z > currentZ && (nextHigherZ === null || z < nextHigherZ)) {
        nextHigherZ = z
        nextHigherObj = o
      }
    })

    if (nextHigherObj) {
      // Swap z_indices
      obj.elementData.z_index = nextHigherZ
      nextHigherObj.elementData.z_index = currentZ
      this.applyZIndexOrdering()
      this.canvas.renderAll()
      this.saveElements()
    }
  },

  moveLayerDown(id) {
    const obj = this.elements.get(id)
    if (!obj) return

    const currentZ = obj.elementData?.z_index || 0

    // Find the object just below this one
    let nextLowerZ = null
    let nextLowerObj = null
    this.elements.forEach((o, oId) => {
      if (oId === id) return
      const z = o.elementData?.z_index || 0
      if (z < currentZ && (nextLowerZ === null || z > nextLowerZ)) {
        nextLowerZ = z
        nextLowerObj = o
      }
    })

    if (nextLowerObj) {
      // Swap z_indices
      obj.elementData.z_index = nextLowerZ
      nextLowerObj.elementData.z_index = currentZ
      this.applyZIndexOrdering()
      this.canvas.renderAll()
      this.saveElements()
    }
  },

  renameElement(id, name) {
    const obj = this.elements.get(id)
    if (obj && obj.elementData) {
      obj.elementData.name = name
      this.saveElements()
    }
  },

  // ============================================================================
  // Snap and Guides Methods
  // ============================================================================

  handleSnap(movingObj) {
    if (!movingObj) return

    const snapLines = []
    const threshold = this.snapThreshold

    // Get moving object bounds
    const movingBounds = this.getObjectBounds(movingObj)

    // Grid snap
    if (this.gridSnapEnabled) {
      const gridPx = this.gridSize * PX_PER_MM

      // Snap left edge to grid
      const snapLeft = Math.round((movingBounds.left - this.labelBounds.left) / gridPx) * gridPx + this.labelBounds.left
      if (Math.abs(movingBounds.left - snapLeft) < threshold) {
        movingObj.set('left', movingObj.left + (snapLeft - movingBounds.left))
      }

      // Snap top edge to grid
      const snapTop = Math.round((movingBounds.top - this.labelBounds.top) / gridPx) * gridPx + this.labelBounds.top
      if (Math.abs(movingBounds.top - snapTop) < threshold) {
        movingObj.set('top', movingObj.top + (snapTop - movingBounds.top))
      }
    }

    // Element snap
    if (this.snapEnabled) {
      // Update bounds after grid snap
      const updatedBounds = this.getObjectBounds(movingObj)

      // Snap to other elements
      this.elements.forEach((obj, id) => {
        if (obj === movingObj || !obj.visible) return

        const targetBounds = this.getObjectBounds(obj)

        // Horizontal snaps (left, center, right)
        // Left to left
        if (Math.abs(updatedBounds.left - targetBounds.left) < threshold) {
          movingObj.set('left', movingObj.left + (targetBounds.left - updatedBounds.left))
          snapLines.push({ type: 'vertical', x: targetBounds.left })
        }
        // Right to right
        else if (Math.abs(updatedBounds.right - targetBounds.right) < threshold) {
          movingObj.set('left', movingObj.left + (targetBounds.right - updatedBounds.right))
          snapLines.push({ type: 'vertical', x: targetBounds.right })
        }
        // Left to right
        else if (Math.abs(updatedBounds.left - targetBounds.right) < threshold) {
          movingObj.set('left', movingObj.left + (targetBounds.right - updatedBounds.left))
          snapLines.push({ type: 'vertical', x: targetBounds.right })
        }
        // Right to left
        else if (Math.abs(updatedBounds.right - targetBounds.left) < threshold) {
          movingObj.set('left', movingObj.left + (targetBounds.left - updatedBounds.right))
          snapLines.push({ type: 'vertical', x: targetBounds.left })
        }
        // Center to center (horizontal)
        else if (Math.abs(updatedBounds.centerX - targetBounds.centerX) < threshold) {
          movingObj.set('left', movingObj.left + (targetBounds.centerX - updatedBounds.centerX))
          snapLines.push({ type: 'vertical', x: targetBounds.centerX })
        }

        // Vertical snaps (top, middle, bottom)
        const newBounds = this.getObjectBounds(movingObj)

        // Top to top
        if (Math.abs(newBounds.top - targetBounds.top) < threshold) {
          movingObj.set('top', movingObj.top + (targetBounds.top - newBounds.top))
          snapLines.push({ type: 'horizontal', y: targetBounds.top })
        }
        // Bottom to bottom
        else if (Math.abs(newBounds.bottom - targetBounds.bottom) < threshold) {
          movingObj.set('top', movingObj.top + (targetBounds.bottom - newBounds.bottom))
          snapLines.push({ type: 'horizontal', y: targetBounds.bottom })
        }
        // Top to bottom
        else if (Math.abs(newBounds.top - targetBounds.bottom) < threshold) {
          movingObj.set('top', movingObj.top + (targetBounds.bottom - newBounds.top))
          snapLines.push({ type: 'horizontal', y: targetBounds.bottom })
        }
        // Bottom to top
        else if (Math.abs(newBounds.bottom - targetBounds.top) < threshold) {
          movingObj.set('top', movingObj.top + (targetBounds.top - newBounds.bottom))
          snapLines.push({ type: 'horizontal', y: targetBounds.top })
        }
        // Center to center (vertical)
        else if (Math.abs(newBounds.centerY - targetBounds.centerY) < threshold) {
          movingObj.set('top', movingObj.top + (targetBounds.centerY - newBounds.centerY))
          snapLines.push({ type: 'horizontal', y: targetBounds.centerY })
        }
      })

      // Snap to label edges
      const finalBounds = this.getObjectBounds(movingObj)

      // Left edge of label
      if (Math.abs(finalBounds.left - this.labelBounds.left) < threshold) {
        movingObj.set('left', movingObj.left + (this.labelBounds.left - finalBounds.left))
        snapLines.push({ type: 'vertical', x: this.labelBounds.left })
      }
      // Right edge of label
      else if (Math.abs(finalBounds.right - (this.labelBounds.left + this.labelBounds.width)) < threshold) {
        movingObj.set('left', movingObj.left + ((this.labelBounds.left + this.labelBounds.width) - finalBounds.right))
        snapLines.push({ type: 'vertical', x: this.labelBounds.left + this.labelBounds.width })
      }

      // Top edge of label
      if (Math.abs(finalBounds.top - this.labelBounds.top) < threshold) {
        movingObj.set('top', movingObj.top + (this.labelBounds.top - finalBounds.top))
        snapLines.push({ type: 'horizontal', y: this.labelBounds.top })
      }
      // Bottom edge of label
      else if (Math.abs(finalBounds.bottom - (this.labelBounds.top + this.labelBounds.height)) < threshold) {
        movingObj.set('top', movingObj.top + ((this.labelBounds.top + this.labelBounds.height) - finalBounds.bottom))
        snapLines.push({ type: 'horizontal', y: this.labelBounds.top + this.labelBounds.height })
      }
    }

    // Draw alignment lines
    this.clearAlignmentLines()
    this.drawAlignmentLines(snapLines)
  },

  getObjectBounds(obj) {
    const w = obj.width * (obj.scaleX || 1)
    const h = obj.height * (obj.scaleY || 1)
    return {
      left: obj.left,
      top: obj.top,
      right: obj.left + w,
      bottom: obj.top + h,
      centerX: obj.left + w / 2,
      centerY: obj.top + h / 2,
      width: w,
      height: h
    }
  },

  drawAlignmentLines(lines) {
    const uniqueLines = []
    lines.forEach(line => {
      const exists = uniqueLines.some(l =>
        l.type === line.type && (l.x === line.x || l.y === line.y)
      )
      if (!exists) uniqueLines.push(line)
    })

    uniqueLines.forEach(line => {
      let fabricLine
      if (line.type === 'vertical') {
        fabricLine = new fabric.Line(
          [line.x, 0, line.x, this.canvas.height],
          {
            stroke: '#3b82f6',
            strokeWidth: 1,
            strokeDashArray: [5, 5],
            selectable: false,
            evented: false,
            excludeFromExport: true
          }
        )
      } else {
        fabricLine = new fabric.Line(
          [0, line.y, this.canvas.width, line.y],
          {
            stroke: '#3b82f6',
            strokeWidth: 1,
            strokeDashArray: [5, 5],
            selectable: false,
            evented: false,
            excludeFromExport: true
          }
        )
      }
      this._alignmentLines.push(fabricLine)
      this.canvas.add(fabricLine)
    })
  },

  clearAlignmentLines() {
    this._alignmentLines.forEach(line => {
      this.canvas.remove(line)
    })
    this._alignmentLines = []
  }
}

export default CanvasDesigner
