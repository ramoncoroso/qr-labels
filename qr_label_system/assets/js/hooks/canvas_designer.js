/**
 * Canvas Designer Hook
 * Uses Fabric.js for visual label design with drag & drop
 */

const MM_TO_PX = 3.78 // Conversion factor mm to px at 96 DPI

const CanvasDesigner = {
  mounted() {
    this.initCanvas()
    this.setupEventListeners()
    this.pushEvent("canvas_ready", {})
  },

  initCanvas() {
    const width = parseFloat(this.el.dataset.width) * MM_TO_PX
    const height = parseFloat(this.el.dataset.height) * MM_TO_PX
    const bgColor = this.el.dataset.backgroundColor || '#FFFFFF'
    const borderWidth = parseFloat(this.el.dataset.borderWidth) || 0
    const borderColor = this.el.dataset.borderColor || '#000000'
    const borderRadius = parseFloat(this.el.dataset.borderRadius) || 0

    // Create canvas container
    const canvasEl = this.el.querySelector('#label-canvas')

    // Initialize Fabric.js canvas
    this.canvas = new fabric.Canvas(canvasEl, {
      width: width + 40, // Add padding
      height: height + 40,
      backgroundColor: '#f3f4f6',
      selection: true
    })

    // Create label background
    this.labelBg = new fabric.Rect({
      left: 20,
      top: 20,
      width: width,
      height: height,
      fill: bgColor,
      stroke: borderColor,
      strokeWidth: borderWidth * MM_TO_PX,
      rx: borderRadius * MM_TO_PX,
      ry: borderRadius * MM_TO_PX,
      selectable: false,
      evented: false
    })
    this.canvas.add(this.labelBg)

    // Store label bounds
    this.labelBounds = {
      left: 20,
      top: 20,
      width: width,
      height: height
    }

    this.elements = new Map()
  },

  setupEventListeners() {
    // Handle element selection
    this.canvas.on('selection:created', (e) => {
      if (e.selected && e.selected.length === 1) {
        const obj = e.selected[0]
        if (obj.elementId) {
          this.pushEvent("element_selected", {id: obj.elementId})
        }
      }
    })

    this.canvas.on('selection:updated', (e) => {
      if (e.selected && e.selected.length === 1) {
        const obj = e.selected[0]
        if (obj.elementId) {
          this.pushEvent("element_selected", {id: obj.elementId})
        }
      }
    })

    this.canvas.on('selection:cleared', () => {
      this.pushEvent("element_deselected", {})
    })

    // Handle element modification
    this.canvas.on('object:modified', (e) => {
      this.saveElements()
    })

    // LiveView event handlers
    this.handleEvent("load_design", ({design}) => {
      this.loadDesign(design)
    })

    this.handleEvent("add_element", ({element}) => {
      this.addElement(element)
    })

    this.handleEvent("update_element_property", ({field, value}) => {
      this.updateSelectedElement(field, value)
    })

    this.handleEvent("delete_element", ({id}) => {
      this.deleteElement(id)
    })

    this.handleEvent("update_canvas_size", (props) => {
      this.updateCanvasSize(props)
    })

    this.handleEvent("save_to_server", () => {
      this.saveElements()
    })
  },

  loadDesign(design) {
    // Clear existing elements
    this.elements.forEach((obj, id) => {
      this.canvas.remove(obj)
    })
    this.elements.clear()

    // Add elements from design
    if (design.elements) {
      design.elements.forEach(element => {
        this.addElement(element, false)
      })
    }
    this.canvas.renderAll()
  },

  addElement(element, save = true) {
    let obj

    const baseProps = {
      left: this.labelBounds.left + (element.x || 10) * MM_TO_PX,
      top: this.labelBounds.top + (element.y || 10) * MM_TO_PX,
      angle: element.rotation || 0
    }

    switch (element.type) {
      case 'qr':
        obj = this.createQRPlaceholder(element, baseProps)
        break
      case 'barcode':
        obj = this.createBarcodePlaceholder(element, baseProps)
        break
      case 'text':
        obj = this.createTextElement(element, baseProps)
        break
      case 'line':
        obj = this.createLineElement(element, baseProps)
        break
      case 'rectangle':
        obj = this.createRectElement(element, baseProps)
        break
      case 'image':
        obj = this.createImagePlaceholder(element, baseProps)
        break
      default:
        return
    }

    obj.elementId = element.id
    obj.elementType = element.type
    obj.elementData = element

    this.elements.set(element.id, obj)
    this.canvas.add(obj)
    this.canvas.setActiveObject(obj)
    this.canvas.renderAll()

    if (save) {
      this.saveElements()
    }
  },

  createQRPlaceholder(element, baseProps) {
    const size = (element.width || 20) * MM_TO_PX

    const rect = new fabric.Rect({
      ...baseProps,
      width: size,
      height: size,
      fill: '#e5e7eb',
      stroke: '#6366f1',
      strokeWidth: 1,
      strokeDashArray: [3, 3]
    })

    const text = new fabric.Text('QR', {
      fontSize: 12,
      fill: '#6366f1',
      fontFamily: 'Arial'
    })

    const group = new fabric.Group([rect, text], {
      ...baseProps,
      hasControls: true,
      lockRotation: false
    })

    // Center text
    text.set({
      left: (size - text.width) / 2,
      top: (size - text.height) / 2
    })

    return group
  },

  createBarcodePlaceholder(element, baseProps) {
    const width = (element.width || 40) * MM_TO_PX
    const height = (element.height || 15) * MM_TO_PX

    const rect = new fabric.Rect({
      width: width,
      height: height,
      fill: '#e5e7eb',
      stroke: '#6366f1',
      strokeWidth: 1,
      strokeDashArray: [3, 3]
    })

    const text = new fabric.Text('Barcode', {
      fontSize: 10,
      fill: '#6366f1',
      fontFamily: 'Arial'
    })

    const group = new fabric.Group([rect, text], {
      ...baseProps,
      hasControls: true,
      lockRotation: false
    })

    text.set({
      left: (width - text.width) / 2,
      top: (height - text.height) / 2
    })

    return group
  },

  createTextElement(element, baseProps) {
    const content = element.text_content || element.binding || 'Texto'

    return new fabric.Textbox(content, {
      ...baseProps,
      width: (element.width || 30) * MM_TO_PX,
      fontSize: element.font_size || 12,
      fontFamily: element.font_family || 'Arial',
      fontWeight: element.font_weight || 'normal',
      fill: element.color || '#000000',
      textAlign: element.text_align || 'left',
      hasControls: true
    })
  },

  createLineElement(element, baseProps) {
    const width = (element.width || 50) * MM_TO_PX
    const height = (element.height || 0.5) * MM_TO_PX

    return new fabric.Rect({
      ...baseProps,
      width: width,
      height: Math.max(height, 2),
      fill: element.color || '#000000',
      hasControls: true
    })
  },

  createRectElement(element, baseProps) {
    return new fabric.Rect({
      ...baseProps,
      width: (element.width || 30) * MM_TO_PX,
      height: (element.height || 20) * MM_TO_PX,
      fill: element.background_color || 'transparent',
      stroke: element.border_color || '#000000',
      strokeWidth: (element.border_width || 0.5) * MM_TO_PX,
      hasControls: true
    })
  },

  createImagePlaceholder(element, baseProps) {
    const width = (element.width || 20) * MM_TO_PX
    const height = (element.height || 20) * MM_TO_PX

    const rect = new fabric.Rect({
      width: width,
      height: height,
      fill: '#e5e7eb',
      stroke: '#9ca3af',
      strokeWidth: 1,
      strokeDashArray: [3, 3]
    })

    const text = new fabric.Text('IMG', {
      fontSize: 10,
      fill: '#9ca3af',
      fontFamily: 'Arial'
    })

    const group = new fabric.Group([rect, text], {
      ...baseProps,
      hasControls: true
    })

    text.set({
      left: (width - text.width) / 2,
      top: (height - text.height) / 2
    })

    return group
  },

  updateSelectedElement(field, value) {
    const activeObject = this.canvas.getActiveObject()
    if (!activeObject || !activeObject.elementId) return

    const elementData = activeObject.elementData || {}

    // Parse numeric values
    if (['x', 'y', 'width', 'height', 'rotation', 'font_size', 'border_width'].includes(field)) {
      value = parseFloat(value)
    }

    elementData[field] = value

    // Apply visual changes
    switch (field) {
      case 'x':
        activeObject.set('left', this.labelBounds.left + value * MM_TO_PX)
        break
      case 'y':
        activeObject.set('top', this.labelBounds.top + value * MM_TO_PX)
        break
      case 'rotation':
        activeObject.set('angle', value)
        break
      case 'color':
        activeObject.set('fill', value)
        break
      case 'text_content':
        if (activeObject.type === 'textbox') {
          activeObject.set('text', value)
        }
        break
      case 'font_size':
        if (activeObject.type === 'textbox') {
          activeObject.set('fontSize', value)
        }
        break
    }

    activeObject.elementData = elementData
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
    const width = props.width * MM_TO_PX
    const height = props.height * MM_TO_PX

    this.canvas.setWidth(width + 40)
    this.canvas.setHeight(height + 40)

    this.labelBg.set({
      width: width,
      height: height,
      fill: props.background_color,
      stroke: props.border_color,
      strokeWidth: props.border_width * MM_TO_PX,
      rx: props.border_radius * MM_TO_PX,
      ry: props.border_radius * MM_TO_PX
    })

    this.labelBounds = {
      left: 20,
      top: 20,
      width: width,
      height: height
    }

    this.canvas.renderAll()
  },

  saveElements() {
    const elements = []

    this.elements.forEach((obj, id) => {
      const data = obj.elementData || {}
      const element = {
        ...data,
        id: id,
        type: obj.elementType,
        x: (obj.left - this.labelBounds.left) / MM_TO_PX,
        y: (obj.top - this.labelBounds.top) / MM_TO_PX,
        width: (obj.width || obj.getScaledWidth()) / MM_TO_PX,
        height: (obj.height || obj.getScaledHeight()) / MM_TO_PX,
        rotation: obj.angle || 0
      }
      elements.push(element)
    })

    this.pushEvent("element_modified", {elements: elements})
  }
}

export default CanvasDesigner
