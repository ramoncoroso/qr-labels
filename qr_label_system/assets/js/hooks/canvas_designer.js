/**
 * Canvas Designer Hook
 * Uses Fabric.js for visual label design with drag & drop
 *
 * Apple-level engineering: The canvas must survive LiveView re-renders.
 * Key insight: LiveView morphs the DOM, but Fabric.js manages its own state.
 * We use updated() to detect changes without recreating the canvas.
 *
 * @module CanvasDesigner
 */

import { fabric } from 'fabric'
import { generateQR as sharedGenerateQR, generateBarcode as sharedGenerateBarcode, validateBarcodeContent as sharedValidateBarcodeContent, getFormatInfo, is2DFormat as sharedIs2DFormat } from './barcode_generator'
import { isExpression, evaluate } from './expression_engine'
import { calcAutoFitFontSize } from './text_utils'

// Constants
const PX_PER_MM = 6 // Fixed pixels per mm - good balance between size and usability
const RULER_SIZE = 35 // pixels
const MAX_CANVAS_SIZE_MM = 500 // Maximum canvas dimension in mm
const MIN_CANVAS_SIZE_MM = 10 // Minimum canvas dimension in mm
const SAVE_DEBOUNCE_MS = 100 // Debounce time for save operations (reduced for faster response)

// Instance counter for debugging
let instanceCounter = 0

const CanvasDesigner = {
  mounted() {
    this._instanceId = ++instanceCounter
    this._saveTimeout = null
    this._isDestroyed = false
    this._isInitialized = false
    this._alignmentLines = []
    this._currentZoom = 1.0
    this._lastSaveTime = null
    this._isInitialLoad = true  // Flag to allow first load_design

    // Snap settings
    this.snapEnabled = this.el.dataset.snapEnabled === 'true'
    this.snapThreshold = parseFloat(this.el.dataset.snapThreshold) || 5

    try {
      this.initCanvas()
      this.setupEventListeners()
      this._isInitialized = true
      this.pushEvent("canvas_ready", {})

      // Save immediately before page unload to prevent data loss
      this._beforeUnloadHandler = () => {
        if (this._saveTimeout) {
          clearTimeout(this._saveTimeout)
          this._saveTimeout = null
          // Force immediate save synchronously before page closes
          this.saveElementsImmediate()
        }
      }
      window.addEventListener('beforeunload', this._beforeUnloadHandler)
    } catch (error) {
      console.error('CanvasDesigner initialization failed:', error)
      console.error('Stack trace:', error.stack)
    }
  },

  /**
   * CRITICAL: Handle LiveView DOM updates without destroying the canvas.
   * This is called every time LiveView updates the DOM (after element_modified events, etc.)
   *
   * With phx-update="ignore", this should rarely be called, but we handle it defensively.
   */
  updated() {
    // Don't do anything if canvas isn't initialized
    if (!this._isInitialized || !this.canvas) {
      return
    }

    // Update snap settings from data attributes if they changed
    const newSnapEnabled = this.el.dataset.snapEnabled === 'true'

    if (this.snapEnabled !== newSnapEnabled) {
      this.snapEnabled = newSnapEnabled
    }

    // With phx-update="ignore", the canvas should never be replaced
    // But verify it's still there
    if (!this.canvas.lowerCanvasEl || !this.canvas.lowerCanvasEl.isConnected) {
      console.error('CanvasDesigner: Canvas element was disconnected from DOM!')
      // Try to recover by re-rendering
      this.canvas.renderAll()
    }
  },

  /**
   * Reinitialize canvas preserving elements (emergency recovery)
   */
  reinitializeCanvas() {
    // Save current elements
    const savedElements = []
    if (this.elements) {
      this.elements.forEach((obj) => {
        if (obj && obj.elementData) {
          savedElements.push({ ...obj.elementData })
        }
      })
    }

    // Dispose old canvas
    if (this.canvas) {
      this.canvas.dispose()
      this.canvas = null
    }
    if (this.elements) {
      this.elements.clear()
    }

    // Reinitialize
    this.initCanvas()

    // Restore elements (skip overlays during bulk load)
    this._isBulkLoading = true
    savedElements.forEach(el => this.addElement(el, false))
    this._isBulkLoading = false
    this.updateDepthOverlays()
    this.canvas.renderAll()
  },

  destroyed() {
    this._isDestroyed = true
    this._isInitialized = false

    // Clear any pending timeouts
    if (this._saveTimeout) {
      clearTimeout(this._saveTimeout)
    }

    if (this._resizeTimeout) {
      clearTimeout(this._resizeTimeout)
    }

    // Remove resize handler
    if (this._resizeHandler) {
      window.removeEventListener('resize', this._resizeHandler)
    }

    // Remove beforeunload handler
    if (this._beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this._beforeUnloadHandler)
    }

    // Clear alignment lines
    this.clearAlignmentLines()

    // Properly dispose of Fabric.js canvas to prevent memory leaks
    if (this.canvas) {
      this.canvas.dispose()
      this.canvas = null
    }

    // Clear element, group, and compliance references
    if (this.elements) {
      this.elements.clear()
    }
    if (this.groups) {
      this.groups.clear()
    }
    this._complianceErrors = new Set()
    this._complianceWarnings = new Set()
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
      console.error('CanvasDesigner: Canvas element #label-canvas not found!')
      return
    }

    // Calculate canvas size
    const width = this.widthMM * PX_PER_MM
    const height = this.heightMM * PX_PER_MM
    const totalWidth = width + RULER_SIZE + 20
    const totalHeight = height + RULER_SIZE + 20

    // Set canvas dimensions before Fabric initialization
    canvasEl.width = totalWidth
    canvasEl.height = totalHeight

    // Initialize Fabric.js canvas with explicit interaction settings
    this.canvas = new fabric.Canvas(canvasEl, {
      width: totalWidth,
      height: totalHeight,
      backgroundColor: '#f1f5f9',
      selection: true,
      preserveObjectStacking: true,
      renderOnAddRemove: true,
      skipTargetFind: false, // Ensure mouse targeting works
      stopContextMenu: true,
      fireRightClick: true
    })

    // Verify canvas was created properly
    if (!this.canvas || !this.canvas.lowerCanvasEl) {
      console.error('CanvasDesigner: Failed to create Fabric canvas properly!')
      return
    }

    // Ensure the upper canvas (for interactions) exists and has correct style
    const upperCanvas = this.canvas.upperCanvasEl
    if (upperCanvas) {
      upperCanvas.style.position = 'absolute'
      upperCanvas.style.top = '0'
      upperCanvas.style.left = '0'
      upperCanvas.style.pointerEvents = 'auto'
    }

    // Ensure the wrapper element doesn't block pointer events
    const wrapperEl = this.canvas.wrapperEl
    if (wrapperEl) {
      wrapperEl.style.position = 'relative'
      // Don't set pointer-events on wrapper - let Fabric handle it
    }

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

    // Store base (unzoomed) canvas dimensions for zoom calculations
    this._baseCanvasWidth = totalWidth
    this._baseCanvasHeight = totalHeight

    // Draw compliance highlight borders after each render
    this.canvas.on('after:render', () => {
      if (this._complianceErrors.size === 0 && this._complianceWarnings.size === 0) return
      const ctx = this.canvas.getContext()
      ctx.save()
      this.elements.forEach((obj, id) => {
        const isError = this._complianceErrors.has(id)
        const isWarning = !isError && this._complianceWarnings.has(id)
        if (!isError && !isWarning) return
        if (!obj.visible) return
        const bounds = obj.getBoundingRect(true, true)
        const pad = 3
        ctx.strokeStyle = isError ? '#ef4444' : '#f59e0b'
        ctx.lineWidth = 2
        ctx.setLineDash(isError ? [] : [6, 3])
        ctx.strokeRect(bounds.left - pad, bounds.top - pad, bounds.width + pad * 2, bounds.height + pad * 2)
      })
      ctx.restore()
    })

    this.elements = new Map()
    this.groups = new Map()  // group_id -> {id, name, locked, visible, collapsed}
    this._complianceErrors = new Set()    // element IDs with errors
    this._complianceWarnings = new Set()  // element IDs with warnings

    // Final verification - ensure canvas is interactive
    this.verifyCanvasInteractive()

    // Auto-fit to container after a short delay to ensure DOM is ready
    setTimeout(() => {
      this.fitToContainer()
    }, 100)
  },

  /**
   * Calculate and apply the optimal zoom to fit the canvas within the container
   */
  fitToContainer() {
    if (!this.canvas || this._isDestroyed) return

    // Calculate available space: viewport minus fixed sidebars
    // Left sidebar: 80px, Layers: 224px (w-56), Properties: 288px (w-72)
    // Plus padding (64px) and header (60px)
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight

    const sidebarLeft = 80
    const sidebarLayers = 224
    const sidebarProperties = 288
    const padding = 64
    const headerAndToolbar = 140

    const availableWidth = viewportWidth - sidebarLeft - sidebarLayers - sidebarProperties - padding
    const availableHeight = viewportHeight - headerAndToolbar - padding

    // Get canvas dimensions (original unzoomed size)
    const canvasWidth = this._baseCanvasWidth || this.canvas.width
    const canvasHeight = this._baseCanvasHeight || this.canvas.height

    // Calculate the zoom level needed to fit
    const scaleX = availableWidth / canvasWidth
    const scaleY = availableHeight / canvasHeight
    const fitZoom = Math.min(scaleX, scaleY, 1) // Don't zoom in beyond 100%

    // Apply minimum zoom of 10% and maximum of 100%
    const finalZoom = Math.max(0.1, Math.min(1, fitZoom))

    this._currentZoom = finalZoom
    this.applyZoom(finalZoom)

    // Notify LiveView of the new zoom level
    this.pushEvent("zoom_changed", { zoom: Math.round(finalZoom * 100) })
  },

  /**
   * Apply zoom using Fabric.js native zoom
   * Re-renders at full resolution so text stays crisp at any zoom level
   */
  applyZoom(zoomLevel) {
    if (!this.canvas) return

    const baseW = this._baseCanvasWidth || this.canvas.width
    const baseH = this._baseCanvasHeight || this.canvas.height
    const scaledWidth = Math.round(baseW * zoomLevel)
    const scaledHeight = Math.round(baseH * zoomLevel)

    // Resize container to match zoomed dimensions
    this.el.style.width = `${scaledWidth}px`
    this.el.style.height = `${scaledHeight}px`
    this.el.style.position = 'relative'
    this.el.style.overflow = 'hidden'

    // Clear any CSS transform from previous implementation
    const fabricWrapper = this.canvas.wrapperEl
    if (fabricWrapper) {
      fabricWrapper.style.transform = ''
      fabricWrapper.style.transformOrigin = ''
    }

    // Resize the canvas element to the zoomed pixel dimensions
    this.canvas.setDimensions({ width: scaledWidth, height: scaledHeight })

    // Apply Fabric.js native zoom — re-renders text as vectors at full resolution
    this.canvas.setZoom(zoomLevel)
    this.canvas.requestRenderAll()
  },

  /**
   * Verify that the canvas is properly set up for interaction
   */
  verifyCanvasInteractive() {
    if (!this.canvas) return

    const upperCanvas = this.canvas.upperCanvasEl
    if (!upperCanvas) return

    // Ensure wrapper and canvases are visible
    const wrapper = this.canvas.wrapperEl
    if (wrapper) {
      wrapper.style.display = 'block'
      wrapper.style.visibility = 'visible'
      wrapper.style.opacity = '1'
    }

    const lowerCanvas = this.canvas.lowerCanvasEl
    if (lowerCanvas) {
      lowerCanvas.style.display = 'block'
      lowerCanvas.style.visibility = 'visible'
    }

    if (upperCanvas) {
      upperCanvas.style.display = 'block'
      upperCanvas.style.visibility = 'visible'
      upperCanvas.style.pointerEvents = 'auto'
    }

    // Fix pointer-events if needed
    const computedStyle = window.getComputedStyle(upperCanvas)
    const pointerEvents = computedStyle.getPropertyValue('pointer-events')

    if (pointerEvents === 'none') {
      upperCanvas.style.pointerEvents = 'auto !important'
    }
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
    // Element selection — notify server with expanded group IDs.
    // Visual expansion to group members happens in mouse:up (not here)
    // to avoid disrupting Fabric.js drag state.
    this.canvas.on('selection:created', (e) => {
      const isCtrlClick = e.e && (e.e.ctrlKey || e.e.metaKey)
      const selected = e.selected || []

      // Notify server of expanded group IDs
      const expanded = this.expandSelectionToGroups(selected, isCtrlClick)
      this._pendingGroupExpansion = expanded.length > selected.length ? expanded : null

      if (expanded.length === 1 && expanded[0]?.elementId) {
        this.pushEvent("element_selected", { id: expanded[0].elementId })
      } else if (expanded.length > 1) {
        const ids = expanded.filter(obj => obj.elementId).map(obj => obj.elementId)
        this.pushEvent("elements_selected", { ids })
      }
    })

    this.canvas.on('selection:updated', (e) => {
      const isCtrlClick = e.e && (e.e.ctrlKey || e.e.metaKey)
      const selected = e.selected || []

      const expanded = this.expandSelectionToGroups(selected, isCtrlClick)
      this._pendingGroupExpansion = expanded.length > selected.length ? expanded : null

      if (expanded.length === 1 && expanded[0]?.elementId) {
        this.pushEvent("element_selected", { id: expanded[0].elementId })
      } else if (expanded.length > 1) {
        const ids = expanded.filter(obj => obj.elementId).map(obj => obj.elementId)
        this.pushEvent("elements_selected", { ids })
      }
    })

    this.canvas.on('selection:cleared', () => {
      // Don't send deselection event during element recreation or save
      if (!this._isRecreatingElement && !this._isSavingElements) {
        this.pushEvent("element_deselected", {})
      }
    })

    // Element modification (drag, resize, rotate)
    // Uses saveElementsImmediate() (no debounce) because object:modified only fires
    // once when the user releases the handle — saving immediately prevents race
    // conditions where a subsequent click could reset scale before the debounced save runs.
    this.canvas.on('object:modified', (e) => {
      this.clearAlignmentLines()
      const obj = e.target
      if (obj && obj.elementId) {
        obj._wasModified = true

        // Normalize scale immediately for regular elements.
        // QR/barcode need to be recreated (not just resized) so they are
        // handled via _pendingRecreate in saveElementsImmediate.
        // Textboxes have width managed by Fabric.js directly.
        const isCodeElement = obj.elementType === 'qr' || obj.elementType === 'barcode'
        const isImageElement = obj.elementType === 'image' && obj.type === 'image'
        if (!isCodeElement && !isImageElement && obj.type !== 'textbox') {
          const sx = obj.scaleX || 1
          const sy = obj.scaleY || 1
          if (Math.abs(sx - 1) > 0.01 || Math.abs(sy - 1) > 0.01) {
            const newW = obj.width * sx
            const newH = obj.height * sy
            obj.set({ width: newW, height: newH, scaleX: 1, scaleY: 1 })
            // Recalculate rx/ry for shapes with border_radius after drag-resize
            if ((obj.elementType === 'circle' || obj.elementType === 'rectangle') && obj.type === 'rect') {
              const data = obj.elementData || {}
              const defaultRadius = obj.elementType === 'circle' ? 100 : 0
              const roundness = (data.border_radius ?? defaultRadius) / 100
              const maxRadius = Math.min(newW, newH) / 2
              obj.set({ rx: roundness * maxRadius, ry: roundness * maxRadius })
            }
            obj.setCoords()
            if (obj.elementData) {
              obj.elementData.width = Math.round((newW / PX_PER_MM) * 100) / 100
              obj.elementData.height = Math.round((newH / PX_PER_MM) * 100) / 100
            }
          }
        }
      }
      this.updateFormatBadgePosition(obj)
      this.autoBringToFrontIfOverlapping(obj)
      this.updateDepthOverlays()
      this.saveElementsImmediate()
    })

    // Capture start positions BEFORE Fabric.js starts moving — essential for group movement
    this.canvas.on('mouse:down', (e) => {
      const target = e.target
      if (target && target.elementData && target.elementData.group_id) {
        const gid = target.elementData.group_id
        // Capture current (pre-move) positions of ALL group members
        this.getGroupMembers(gid).forEach(member => {
          member._groupStartLeft = member.left
          member._groupStartTop = member.top
        })
      }
    })

    // Snap while moving + sync format badge + group movement
    this.canvas.on('object:moving', (e) => {
      const obj = e.target
      obj._isDragging = true

      const isGroupMember = obj && obj.elementData && obj.elementData.group_id && !obj._isGroupMoving
      const gid = isGroupMember ? obj.elementData.group_id : null

      // Snap: skip siblings of the same group to avoid feedback loop
      if (this.snapEnabled) {
        this._snapExcludeGroupId = gid
        this.handleSnap(obj)
        this._snapExcludeGroupId = null
      }
      this.updateFormatBadgePosition(obj)

      // Group movement: when moving a single element that belongs to a group,
      // move all other group members by the same delta
      if (isGroupMember) {
        // Positions were captured in mouse:down; if missing, fallback to current
        if (obj._groupStartLeft === undefined) {
          obj._groupStartLeft = obj.left
          obj._groupStartTop = obj.top
        }

        const dx = obj.left - obj._groupStartLeft
        const dy = obj.top - obj._groupStartTop

        // Move siblings
        this.getGroupMembers(gid).forEach(member => {
          if (member !== obj && member._groupStartLeft !== undefined) {
            member._isGroupMoving = true
            member.set({
              left: member._groupStartLeft + dx,
              top: member._groupStartTop + dy
            })
            member.setCoords()
            member._isGroupMoving = false
          }
        })
        this.canvas.requestRenderAll()
      }
      this.updateDepthOverlays()
    })

    // Clear alignment lines + group start positions + drag flag when done moving
    // Also expand visual selection to group members if user clicked without dragging
    this.canvas.on('mouse:up', () => {
      this.clearAlignmentLines()

      // Check if we have a pending group expansion and the user didn't drag
      const didDrag = Array.from(this.elements.values()).some(obj => obj._isDragging)
      if (!didDrag && this._pendingGroupExpansion) {
        const expanded = this._pendingGroupExpansion
        this._pendingGroupExpansion = null
        this.canvas.discardActiveObject()
        if (expanded.length === 1) {
          this.canvas.setActiveObject(expanded[0])
        } else {
          const sel = new fabric.ActiveSelection(expanded, { canvas: this.canvas })
          this.canvas.setActiveObject(sel)
        }
        this.canvas.renderAll()
      }
      this._pendingGroupExpansion = null

      // Clear group movement start positions and drag flag
      this.elements.forEach((obj) => {
        delete obj._groupStartLeft
        delete obj._groupStartTop
        delete obj._isDragging
      })
    })

    // Text editing: clear placeholder on enter, restore on exit
    this.canvas.on('text:editing:entered', (e) => {
      const obj = e.target
      if (obj && obj._isPlaceholder) {
        obj.set('text', '')
        obj.set('fill', obj._originalColor || '#000000')
        obj._isPlaceholder = false
        this.canvas.renderAll()
      }
    })

    this.canvas.on('text:editing:exited', (e) => {
      const obj = e.target
      const hasBinding = obj && obj.elementData && obj.elementData.binding
      if (obj && obj.elementId && (!obj.text || obj.text.trim() === '') && !hasBinding) {
        // Restore placeholder (only for unbound text elements)
        obj.set('text', 'Completar texto')
        obj.set('fill', '#999999')
        obj._isPlaceholder = true
        // Save empty text_content to backend
        if (obj.elementData) {
          obj.elementData.text_content = ''
        }
        this.canvas.renderAll()
      } else if (obj && obj.elementId && (!obj.text || obj.text.trim() === '') && hasBinding) {
        // Bound element with empty text: restore binding display
        const binding = obj.elementData.binding
        if (isExpression(binding)) {
          const preview = evaluate(binding, {}, { rowIndex: 0, batchSize: 1, now: new Date() })
          obj.set('text', preview || binding)
          obj.set('fontStyle', 'italic')
        } else {
          obj.set('text', `[${binding}]`)
        }
        obj.set('fill', obj._originalColor || '#000000')
        obj._isPlaceholder = false
        if (obj.elementData) {
          obj.elementData.text_content = ''
        }
        this.canvas.renderAll()
      } else if (obj && obj.elementId) {
        // User typed real content - update elementData and push to backend
        obj._isPlaceholder = false
        obj.set('fill', obj._originalColor || '#000000')
        if (obj.elementData) {
          obj.elementData.text_content = obj.text
        }
        this.pushEvent("update_element", { id: obj.elementId, field: "text_content", value: obj.text })
      }
    })

    // Drag and drop from sidebar
    this.setupDragAndDrop()

    // LiveView events
    this.handleEvent("load_design", ({ design }) => {
      const now = Date.now()
      const timeSinceLastSave = this._lastSaveTime ? (now - this._lastSaveTime) : Infinity

      // CRITICAL: Don't reload if we just saved (prevents reverting user changes)
      // Wait at least 1 second after a save before accepting load_design
      if (timeSinceLastSave < 1000) {
        return
      }

      // Also don't reload if we already have elements (only load on initial mount)
      if (this.elements && this.elements.size > 0 && !this._isInitialLoad) {
        return
      }

      if (design && !this._isDestroyed) {
        this._isInitialLoad = false
        this.loadDesign(design)
      }
    })

    // Force reload design (used for undo/redo and version restore)
    // Preserves existing images when receiving a light design (image_data: null)
    this.handleEvent("reload_design", ({ design }) => {
      console.log("[reload_design] received, design:", design ? `${design.elements?.length || 0} elements` : "null", "destroyed:", this._isDestroyed)
      if (design && !this._isDestroyed) {
        // Cancel any pending debounced save to prevent old data from overwriting
        // the reloaded design on the server
        if (this._saveTimeout) {
          clearTimeout(this._saveTimeout)
          this._saveTimeout = null
        }

        this._restoreImageDataFromCanvas(design)
        console.log("[reload_design] calling loadDesign...")
        this.loadDesign(design)

        // Mark save time to prevent load_design from reverting and to give the
        // canvas time to settle before any autosave fires
        this._lastSaveTime = Date.now()
        console.log("[reload_design] done, canvas elements:", this.elements.size)
      }
    })

    this.handleEvent("add_element", ({ element }) => {
      if (element && element.type && !this._isDestroyed) {
        this.addElement(element)
      }
    })

    this.handleEvent("update_element_property", ({ id, field, value }) => {
      if (field && !this._isDestroyed) {
        this.updateElementById(id, field, value)
      }
    })

    this.handleEvent("delete_element", ({ id }) => {
      if (id && !this._isDestroyed) {
        this.deleteElement(id)
      }
    })

    this.handleEvent("delete_elements", ({ ids }) => {
      if (ids && Array.isArray(ids) && !this._isDestroyed) {
        this.deleteElements(ids)
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

    // Capture canvas thumbnail for version history
    this.handleEvent("capture_thumbnail", ({ version_number }) => {
      if (!this._isDestroyed && this.canvas && this.labelBounds) {
        this.captureCanvasThumbnail().then(thumbnail => {
          if (thumbnail) {
            this.pushEvent("canvas_thumbnail", {
              version_number: version_number,
              thumbnail: thumbnail
            })
          }
        })
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

    // Group management
    this.handleEvent("create_group", ({ group_id, name, element_ids }) => {
      if (!this._isDestroyed) {
        this.createGroup(group_id, name, element_ids)
      }
    })

    this.handleEvent("ungroup", ({ group_id }) => {
      if (!this._isDestroyed) {
        this.ungroupElements(group_id)
      }
    })

    this.handleEvent("toggle_group_visibility", ({ group_id }) => {
      if (!this._isDestroyed) {
        this.toggleGroupVisibility(group_id)
      }
    })

    this.handleEvent("toggle_group_lock", ({ group_id }) => {
      if (!this._isDestroyed) {
        this.toggleGroupLock(group_id)
      }
    })

    this.handleEvent("rename_group", ({ group_id, name }) => {
      if (!this._isDestroyed) {
        const group = this.groups.get(group_id)
        if (group) {
          group.name = name
          this.saveElements()
        }
      }
    })

    this.handleEvent("remove_from_group", ({ element_id }) => {
      if (!this._isDestroyed) {
        this.removeFromGroup(element_id)
      }
    })

    // Compliance highlights
    this.handleEvent("highlight_compliance_issues", ({ errors, warnings }) => {
      if (!this._isDestroyed) {
        this._complianceErrors = new Set(errors || [])
        this._complianceWarnings = new Set(warnings || [])
        this.canvas.requestRenderAll()
      }
    })

    // Snap settings
    this.handleEvent("update_snap_settings", ({ snap_enabled }) => {
      if (!this._isDestroyed) {
        this.snapEnabled = snap_enabled
      }
    })

    // Mouse wheel zoom - Ctrl/Cmd + scroll to zoom
    const container = document.getElementById('canvas-container')
    if (container) {
      container.addEventListener('wheel', (e) => {
        if (e.ctrlKey || e.metaKey) {
          e.preventDefault()
          const delta = e.deltaY > 0 ? -10 : 10
          const currentZoom = this._currentZoom * 100
          const newZoom = Math.max(25, Math.min(200, currentZoom + delta))
          this.pushEvent("update_zoom_from_wheel", { zoom: newZoom })
        }
      }, { passive: false })
    }

    // Zoom handling - use CSS transform for visual scaling
    this.handleEvent("update_zoom", ({ zoom }) => {
      if (!this._isDestroyed && this.canvas) {
        const zoomLevel = zoom / 100
        this._currentZoom = zoomLevel
        this.applyZoom(zoomLevel)
      }
    })

    // Fit to view event
    this.handleEvent("fit_to_view", () => {
      if (!this._isDestroyed) {
        this.fitToContainer()
      }
    })

    // Handle window resize - re-fit canvas
    this._resizeHandler = () => {
      if (!this._isDestroyed && this.canvas) {
        // Debounce resize
        if (this._resizeTimeout) {
          clearTimeout(this._resizeTimeout)
        }
        this._resizeTimeout = setTimeout(() => {
          this.fitToContainer()
        }, 200)
      }
    }
    window.addEventListener('resize', this._resizeHandler)

    // Custom events from BorderRadiusSlider hook
    window.addEventListener('border-radius-change', (e) => {
      if (this._isDestroyed) return
      const { elementId, value } = e.detail
      const obj = this.elements.get(elementId)
      if (obj && obj.elementType === 'circle' && obj.type === 'rect') {
        const roundness = value / 100
        const maxRadius = Math.min(obj.width, obj.height) / 2
        obj.set({ rx: roundness * maxRadius, ry: roundness * maxRadius })
        // Update elementData
        if (obj.elementData) {
          obj.elementData.border_radius = value
        }
        this.canvas.renderAll()
      }
    })

    window.addEventListener('border-radius-save', (e) => {
      if (this._isDestroyed) return
      const { elementId, value } = e.detail
      const obj = this.elements.get(elementId)
      if (obj && obj.elementData) {
        obj.elementData.border_radius = value
        this.saveElements()
      }
    })
  },

  loadDesign(design) {
    // Remove existing elements, their format badges, and overlays
    this.clearDepthOverlays()
    this.elements.forEach((obj) => {
      this.removeFormatBadge(obj)
      this.canvas.remove(obj)
    })
    this.elements.clear()

    // Load groups
    this.groups.clear()
    if (design.groups) {
      design.groups.forEach(g => {
        this.groups.set(g.id, { ...g })
      })
    }

    // Add elements from design (skip overlays during bulk load)
    this._isBulkLoading = true
    if (design.elements) {
      design.elements.forEach(el => this.addElement(el, false))
    }
    this._isBulkLoading = false

    // Now calculate overlays once for all elements
    this.updateDepthOverlays()
    this.canvas.renderAll()
  },

  // Restore image_data/qr_logo_data from existing canvas elements into design
  // when receiving a "light" design (with null image data) for undo/redo/batch
  _restoreImageDataFromCanvas(design) {
    if (!design || !design.elements) return
    const cache = {}
    this.elements.forEach((obj) => {
      if (obj.elementData) {
        if (obj.elementData.image_data) cache[obj.elementId] = cache[obj.elementId] || {}
        if (obj.elementData.image_data) cache[obj.elementId].image_data = obj.elementData.image_data
        if (obj.elementData.qr_logo_data) {
          cache[obj.elementId] = cache[obj.elementId] || {}
          cache[obj.elementId].qr_logo_data = obj.elementData.qr_logo_data
        }
      }
    })
    design.elements.forEach(el => {
      const cached = cache[el.id]
      if (cached) {
        if (!el.image_data && cached.image_data) el.image_data = cached.image_data
        if (!el.qr_logo_data && cached.qr_logo_data) el.qr_logo_data = cached.qr_logo_data
      }
    })
  },

  addElement(element, save = true) {
    if (!this.canvas || !this.labelBounds) {
      return
    }

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
      case 'circle':
        obj = this.createCircle(element, x, y)
        break
      case 'image':
        obj = this.createImage(element, x, y)
        break
      default:
        return
    }

    if (!obj) {
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
      borderScaleFactor: 2,
      // Explicitly ensure controls are visible
      hasControls: true,
      hasBorders: true
    })

    this.elements.set(element.id, obj)
    this.canvas.add(obj)

    // Add format badge for barcode elements
    if (element.type === 'barcode') {
      this.addFormatBadge(obj, element.barcode_format || 'CODE128', element.id)
    }

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
      // Delay the save slightly to let the canvas settle
      setTimeout(() => {
        if (!this._isDestroyed && this.canvas) {
          this.saveElements()
        }
      }, 100)
    }
  },

  createQR(element, x, y) {
    const size = (element.width || 20) * PX_PER_MM
    // Use text_content for single labels, binding for multiple labels with data
    const content = element.text_content || element.binding || ''

    // If we have content, generate real QR code
    if (content) {
      // Create placeholder first, then load QR asynchronously
      const placeholder = this.createQRPlaceholder(size, x, y, element.rotation, 'Generando...')
      placeholder._qrLoading = true
      placeholder._qrContent = content

      // Generate QR code asynchronously
      sharedGenerateQR(content, element, { sizePx: size }).then(dataUrl => {
        if (!dataUrl) return
        if (this._isDestroyed) return

        const obj = this.elements.get(element.id)
        if (!obj || !obj._qrLoading || obj._qrContent !== content) return

        fabric.Image.fromURL(dataUrl, (img) => {
          if (this._isDestroyed) return

          // Get fresh reference in case element was modified
          const currentObj = this.elements.get(element.id)
          if (!currentObj || currentObj._qrContent !== content) return

          img.set({
            left: x,
            top: y,
            scaleX: size / img.width,
            scaleY: size / img.height,
            angle: element.rotation || 0
          })

          // Copy over element data
          img.elementId = currentObj.elementId
          img.elementType = currentObj.elementType
          img.elementData = currentObj.elementData
          img._qrContent = content

          // Copy visibility and lock state
          img.set({
            visible: currentObj.visible,
            selectable: currentObj.selectable,
            evented: currentObj.evented,
            lockMovementX: currentObj.lockMovementX,
            lockMovementY: currentObj.lockMovementY,
            lockRotation: currentObj.lockRotation,
            lockScalingX: currentObj.lockScalingX,
            lockScalingY: currentObj.lockScalingY,
            cornerColor: '#3b82f6',
            cornerStyle: 'circle',
            cornerSize: 8,
            transparentCorners: false,
            borderColor: currentObj.lockMovementX ? '#f59e0b' : '#3b82f6',
            borderScaleFactor: 2
          })

          // Replace placeholder with actual QR image
          this.canvas.remove(currentObj)
          this.elements.set(element.id, img)
          this.canvas.add(img)
          this.applyZIndexOrdering()
          this.canvas.renderAll()
        }, { crossOrigin: 'anonymous' })
      }).catch(err => {
        console.error('Error generating QR code:', err)
      })

      return placeholder
    }

    // No content - show placeholder
    return this.createQRPlaceholder(size, x, y, element.rotation, 'Completar QR', '#999999')
  },

  createQRPlaceholder(size, x, y, rotation, label, color) {
    const fillColor = color || '#3b82f6'
    const bgColor = color ? '#f3f4f6' : '#dbeafe'
    const moduleColor = color ? '#d1d5db' : '#93c5fd'
    const objects = []

    // Background
    objects.push(new fabric.Rect({
      width: size, height: size,
      fill: bgColor, stroke: fillColor,
      strokeWidth: 2, strokeDashArray: [4, 4]
    }))

    // QR finder patterns (3 corners)
    const fp = size * 0.18 // finder pattern size
    const m = size * 0.06  // margin
    const corners = [[m, m], [size - fp - m, m], [m, size - fp - m]]
    corners.forEach(([cx, cy]) => {
      objects.push(new fabric.Rect({ left: cx, top: cy, width: fp, height: fp, fill: moduleColor, rx: 2, ry: 2 }))
      const inner = fp * 0.5
      const offset = (fp - inner) / 2
      objects.push(new fabric.Rect({ left: cx + offset, top: cy + offset, width: inner, height: inner, fill: bgColor, rx: 1, ry: 1 }))
      const core = fp * 0.22
      const coreOff = (fp - core) / 2
      objects.push(new fabric.Rect({ left: cx + coreOff, top: cy + coreOff, width: core, height: core, fill: moduleColor }))
    })

    // Scattered data modules
    const mod = size * 0.05
    const positions = [
      [0.45, 0.15], [0.55, 0.15], [0.65, 0.15],
      [0.75, 0.35], [0.80, 0.45],
      [0.15, 0.75], [0.25, 0.80],
      [0.75, 0.75], [0.80, 0.80], [0.65, 0.85]
    ]
    positions.forEach(([px, py]) => {
      objects.push(new fabric.Rect({ left: size * px, top: size * py, width: mod, height: mod, fill: moduleColor }))
    })

    // White gap + text in center
    const maxFontSize = size * 0.2
    const fitFontSize = (size * 0.85) / label.length * 1.6
    const fontSize = Math.min(maxFontSize, fitFontSize)
    const gapW = size * 0.75
    const gapH = fontSize * 1.8
    objects.push(new fabric.Rect({
      left: (size - gapW) / 2, top: (size - gapH) / 2,
      width: gapW, height: gapH,
      fill: 'white', rx: 3, ry: 3
    }))
    objects.push(new fabric.Text(label, {
      fontSize: fontSize, fill: fillColor, fontWeight: 'bold',
      originX: 'center', originY: 'center',
      left: size / 2, top: size / 2
    }))

    return new fabric.Group(objects, {
      left: x, top: y, angle: rotation || 0
    })
  },

  createFormatBadge(format, elementId, x, y) {
    const info = getFormatInfo(format)
    if (!info) return null

    const label = info.name
    const colors = info.badge

    const text = new fabric.Text(label, {
      fontSize: 9,
      fontFamily: 'Arial',
      fontWeight: 'bold',
      fill: colors.text,
      originX: 'left',
      originY: 'top'
    })

    const padX = 4
    const padY = 2
    const rect = new fabric.Rect({
      width: text.width + padX * 2,
      height: text.height + padY * 2,
      fill: colors.bg,
      stroke: colors.border,
      strokeWidth: 1,
      rx: 3,
      ry: 3,
      originX: 'left',
      originY: 'top'
    })

    text.set({ left: padX, top: padY })

    const badge = new fabric.Group([rect, text], {
      left: x,
      top: y - (text.height + padY * 2) - 2,
      selectable: false,
      evented: false,
      excludeFromExport: true,
      _isFormatBadge: true,
      _parentElementId: elementId
    })

    return badge
  },

  addFormatBadge(obj, format, elementId) {
    if (!obj || !this.canvas) return
    const badge = this.createFormatBadge(format, elementId, obj.left, obj.top)
    if (badge) {
      obj._formatBadge = badge
      this.canvas.add(badge)
    }
  },

  removeFormatBadge(obj) {
    if (obj && obj._formatBadge && this.canvas) {
      this.canvas.remove(obj._formatBadge)
      obj._formatBadge = null
    }
  },

  updateFormatBadgePosition(obj) {
    if (obj && obj._formatBadge) {
      const badge = obj._formatBadge
      badge.set({
        left: obj.left,
        top: obj.top - badge.height - 2,
        angle: 0
      })
      badge.setCoords()
    }
  },

  createBarcode(element, x, y) {
    let w = (element.width || 40) * PX_PER_MM
    let h = (element.height || 15) * PX_PER_MM
    // Use text_content for single labels, binding for multiple labels with data
    const content = element.text_content || element.binding || ''
    const format = element.barcode_format || 'CODE128'

    // 2D formats (DataMatrix, Aztec, MaxiCode) must be square
    if (sharedIs2DFormat(format) && Math.abs(w - h) > 1) {
      // Use the shorter side, but ensure minimum 20mm for readability
      const minSidePx = 20 * PX_PER_MM
      const side = Math.max(Math.min(w, h), minSidePx)
      w = side
      h = side
    }

    // If we have content, generate real barcode
    if (content) {
      // Validate content for format before attempting generation
      const validation = sharedValidateBarcodeContent(content, format)
      if (!validation.valid) {
        // Show error placeholder with format requirements
        return this.createBarcodeErrorPlaceholder(w, h, x, y, element.rotation, validation.error)
      }

      // Create placeholder first, then generate barcode
      const placeholder = this.createBarcodePlaceholder(w, h, x, y, element.rotation, 'Generando...')
      placeholder._barcodeLoading = true
      placeholder._barcodeContent = content
      placeholder._barcodeFormat = format

      // Generate barcode using shared module
      try {
        const dataUrl = sharedGenerateBarcode(content, element, {
          heightPx: h * 0.7,
          fontSize: Math.max(10, h * 0.15),
          margin: 5
        })

        if (!dataUrl) throw new Error('Barcode generation returned null')

        fabric.Image.fromURL(dataUrl, (img) => {
          if (this._isDestroyed) return

          const obj = this.elements.get(element.id)
          if (!obj || !obj._barcodeLoading || obj._barcodeContent !== content) return

          // Scale to fill the exact target dimensions
          const creationScaleX = w / img.width
          const creationScaleY = h / img.height
          img.set({
            left: x,
            top: y,
            scaleX: creationScaleX,
            scaleY: creationScaleY,
            angle: element.rotation || 0
          })

          // Copy over element data
          img.elementId = obj.elementId
          img.elementType = obj.elementType
          img.elementData = obj.elementData
          img._barcodeContent = content
          img._barcodeFormat = format
          // Track creation scale so saveElementsImmediate only triggers
          // recreation when the user actually resizes (not on every move)
          img._creationScaleX = creationScaleX
          img._creationScaleY = creationScaleY

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
            borderColor: obj.lockMovementX ? '#f59e0b' : '#3b82f6',
            borderScaleFactor: 2
          })

          // Remove old badge if placeholder had one
          this.removeFormatBadge(obj)

          // Replace placeholder with actual barcode image
          this.canvas.remove(obj)
          this.elements.set(element.id, img)
          this.canvas.add(img)

          // Add format badge
          this.addFormatBadge(img, format, element.id)

          this.applyZIndexOrdering()
          this.canvas.renderAll()
        }, { crossOrigin: 'anonymous' })

      } catch (err) {
        console.error('Error generating barcode:', err)
        // Replace placeholder with error indicator
        const errorPlaceholder = this.createBarcodeErrorPlaceholder(w, h, x, y, element.rotation, 'Error de formato')
        errorPlaceholder._barcodeContent = content
        errorPlaceholder._barcodeFormat = format

        // Replace the "Generando..." placeholder with error
        setTimeout(() => {
          const obj = this.elements.get(element.id)
          if (obj && obj._barcodeLoading) {
            errorPlaceholder.elementId = obj.elementId
            errorPlaceholder.elementType = obj.elementType
            errorPlaceholder.elementData = obj.elementData

            this.removeFormatBadge(obj)
            this.canvas.remove(obj)
            this.elements.set(element.id, errorPlaceholder)
            this.canvas.add(errorPlaceholder)
            this.canvas.renderAll()
          }
        }, 0)
      }

      return placeholder
    }

    // No content - show placeholder
    return this.createBarcodePlaceholder(w, h, x, y, element.rotation, 'Completar cód. barras', '#999999')
  },

  // validateBarcodeContent is now in barcode_generator.js (sharedValidateBarcodeContent)

  createBarcodePlaceholder(w, h, x, y, rotation, label, color) {
    const fillColor = color || '#3b82f6'
    const bgColor = color ? '#f3f4f6' : '#dbeafe'
    const barColor = color ? '#d1d5db' : '#93c5fd'
    const objects = []

    // Background
    objects.push(new fabric.Rect({
      width: w, height: h,
      fill: bgColor, stroke: fillColor,
      strokeWidth: 2, strokeDashArray: [4, 4]
    }))

    // Barcode lines
    const barMargin = w * 0.05
    const barAreaW = w - barMargin * 2
    const barH = h * 0.7
    const barY = (h - barH) / 2
    const widths = [2, 1, 3, 1, 2, 1, 3, 2, 1, 2, 1, 3, 1, 2, 3, 1, 2, 1, 3, 1, 2]
    const totalUnits = widths.reduce((a, b) => a + b, 0) + widths.length * 0.5
    const unitW = barAreaW / totalUnits
    let cx = barMargin
    widths.forEach((bw, i) => {
      if (i % 2 === 0) {
        objects.push(new fabric.Rect({
          left: cx, top: barY,
          width: Math.max(bw * unitW, 1), height: barH,
          fill: barColor
        }))
      }
      cx += (bw + 0.5) * unitW
    })

    // White gap + text in center
    const maxFontSize = Math.min(w, h) * 0.2
    const fitFontSize = (w * 0.85) / label.length * 1.6
    const fontSize = Math.min(maxFontSize, fitFontSize)
    const gapW = w * 0.7
    const gapH = fontSize * 1.8
    objects.push(new fabric.Rect({
      left: (w - gapW) / 2, top: (h - gapH) / 2,
      width: gapW, height: gapH,
      fill: 'white', rx: 3, ry: 3
    }))
    objects.push(new fabric.Text(label, {
      fontSize: fontSize, fill: fillColor, fontWeight: 'bold',
      originX: 'center', originY: 'center',
      left: w / 2, top: h / 2
    }))

    return new fabric.Group(objects, {
      left: x, top: y, angle: rotation || 0
    })
  },

  /**
   * Create an error placeholder for invalid barcode content/format
   */
  createBarcodeErrorPlaceholder(w, h, x, y, rotation, errorMsg) {
    const rect = new fabric.Rect({
      width: w,
      height: h,
      fill: '#fef2f2',
      stroke: '#ef4444',
      strokeWidth: 2,
      strokeDashArray: [4, 4]
    })

    const text = new fabric.Text(errorMsg, {
      fontSize: Math.min(w * 0.08, h * 0.25, 14),
      fill: '#dc2626',
      fontWeight: 'bold',
      originX: 'center',
      originY: 'center',
      left: w / 2,
      top: h / 2,
      textAlign: 'center'
    })

    const group = new fabric.Group([rect, text], {
      left: x,
      top: y,
      angle: rotation || 0
    })

    group._barcodeError = true
    return group
  },

  createText(element, x, y) {
    // Show binding as [ColumnName] indicator, or text_content, or placeholder
    // Expressions: evaluate with empty row (functions like HOY() resolve, column refs show placeholder)
    const hasContent = element.binding || (element.text_content && element.text_content.trim() !== '')
    let content
    let isExpr = false
    if (isExpression(element.binding)) {
      isExpr = true
      const preview = evaluate(element.binding, {}, { rowIndex: 0, batchSize: 1, now: new Date() })
      content = preview || element.binding
    } else if (element.binding) {
      content = `[${element.binding}]`
    } else if (hasContent) {
      content = element.text_content
    } else {
      content = 'Completar texto'
    }
    const isPlaceholder = !hasContent
    const fontSize = element.font_size || 12

    // Create textbox with initial width
    const textbox = new fabric.Textbox(content, {
      left: x,
      top: y,
      width: (element.width || 30) * PX_PER_MM,
      fontSize: fontSize,
      fontFamily: element.font_family || 'Arial',
      fontWeight: element.font_weight || 'normal',
      fill: isPlaceholder ? '#999999' : (element.color || '#000000'),
      textAlign: element.text_align || 'left',
      angle: element.rotation || 0,
      // Allow text to wrap but also allow manual resize
      splitByGrapheme: false
    })

    // Track placeholder state, expression state, and original color
    textbox._isPlaceholder = isPlaceholder
    textbox._isExpression = isExpr
    textbox._originalColor = element.color || '#000000'

    // Visual indicator for expressions: italic style
    if (isExpr) {
      textbox.set('fontStyle', 'italic')
    }

    // Auto-fit font size to bounding box (only when explicitly enabled)
    if (element.text_auto_fit === true && content && element.width && element.height) {
      const boxW = (element.width || 30) * PX_PER_MM
      const boxH = (element.height || 14) * PX_PER_MM
      const minFontSize = element.text_min_font_size || 6
      const { fontSize: fittedSize, overflows } = calcAutoFitFontSize(
        content, boxW, boxH, fontSize, minFontSize,
        element.font_family || 'Arial', element.font_weight || 'normal'
      )
      textbox.set('fontSize', fittedSize)
      textbox._textOverflows = overflows
      if (overflows) {
        textbox.set({ stroke: '#dc2626', strokeDashArray: [5, 3], strokeWidth: 1.5 })
      }
    } else {
      // Legacy behavior: auto-fit width to content
      const textWidth = textbox.calcTextWidth()
      const minWidth = 10 * PX_PER_MM // Minimum 10mm
      const padding = 2 * PX_PER_MM // 2mm padding
      const fittedWidth = Math.max(textWidth + padding, minWidth)

      if (!element.width || element.width === 60) {
        textbox.set('width', fittedWidth)
      }
    }

    return textbox
  },

  createLine(element, x, y) {
    const w = (element.width || 50) * PX_PER_MM
    // Use border_width for line thickness (fallback to height for backwards compatibility)
    const thickness = element.border_width || element.height || 0.5
    const h = Math.max(thickness * PX_PER_MM, 2)

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
    const width = (element.width || 30) * PX_PER_MM
    const height = (element.height || 20) * PX_PER_MM

    // border_radius is a percentage (0-100) for rounded corners
    const roundness = (element.border_radius || 0) / 100
    const maxRadius = Math.min(width, height) / 2
    const radius = roundness * maxRadius

    return new fabric.Rect({
      left: x,
      top: y,
      width: width,
      height: height,
      fill: element.background_color || 'transparent',
      stroke: element.border_color || '#000000',
      strokeWidth: (element.border_width || 0.5) * PX_PER_MM,
      rx: radius,
      ry: radius,
      angle: element.rotation || 0
    })
  },

  createCircle(element, x, y) {
    const width = (element.width || 15) * PX_PER_MM
    const height = (element.height || 15) * PX_PER_MM

    // border_radius is a percentage (0-100)
    // 0% = rectangle, 100% = maximum roundness (ellipse-like)
    const roundness = (element.border_radius ?? 100) / 100
    const maxRadius = Math.min(width, height) / 2
    const radius = roundness * maxRadius

    const rect = new fabric.Rect({
      left: x,
      top: y,
      width: width,
      height: height,
      rx: radius,
      ry: radius,
      fill: element.background_color || 'transparent',
      stroke: element.border_color || '#000000',
      strokeWidth: (element.border_width || 0.5) * PX_PER_MM,
      angle: element.rotation || 0
    })

    return rect
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

        // Uniform scale to preserve aspect ratio (fit within the area)
        const uniformScale = Math.min(w / img.width, h / img.height)

        img.set({
          left: x,
          top: y,
          scaleX: uniformScale,
          scaleY: uniformScale,
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

  /**
   * Update element by ID (used when properties panel changes values)
   */
  updateElementById(id, field, value) {
    // Find element by ID instead of relying on active selection
    let obj = null
    if (id) {
      obj = this.elements.get(id)
      // Also try string version of ID
      if (!obj) {
        obj = this.elements.get(String(id))
      }
    }
    if (!obj) {
      obj = this.canvas.getActiveObject()
    }

    if (!obj?.elementId) return
    this.updateSelectedElement(field, value, obj)
  },

  updateSelectedElement(field, value, targetObj = null) {
    const obj = targetObj || this.canvas.getActiveObject()
    if (!obj?.elementId) return

    const data = obj.elementData || {}

    // Parse numeric values
    if (['x', 'y', 'width', 'height', 'rotation', 'font_size', 'border_width', 'border_radius', 'text_min_font_size'].includes(field)) {
      value = parseFloat(value) || 0
    }
    // Parse boolean values
    if (['text_auto_fit'].includes(field)) {
      value = value === true || value === 'true'
    }

    data[field] = value

    // Apply changes based on field
    switch (field) {
      case 'x':
        obj.set('left', this.labelBounds.left + value * PX_PER_MM)
        break
      case 'y':
        obj.set('top', this.labelBounds.top + value * PX_PER_MM)
        break
      case 'width': {
        const isCode = obj.elementType === 'qr' || obj.elementType === 'barcode'
        if (isCode) {
          // QR/barcode: recreate at new size (regenerates the image)
          this.recreateGroupAtSize(obj, value, data.height)
          return // recreateGroupAtSize handles save
        } else if (obj.type === 'textbox') {
          obj.set('width', value * PX_PER_MM)
        } else if (obj.type === 'rect') {
          obj.set('width', value * PX_PER_MM)
          if (obj.elementType === 'circle') {
            const roundness = (data.border_radius ?? 100) / 100
            const maxRadius = Math.min(value * PX_PER_MM, obj.height) / 2
            obj.set({ rx: roundness * maxRadius, ry: roundness * maxRadius })
          }
        } else if (obj.type === 'image') {
          const newW = value * PX_PER_MM
          obj.set('scaleX', newW / obj.width)
          obj._explicitSizeUpdate = true
        }
        break
      }
      case 'height': {
        const isCode = obj.elementType === 'qr' || obj.elementType === 'barcode'
        if (isCode) {
          // QR/barcode: recreate at new size (regenerates the image)
          this.recreateGroupAtSize(obj, data.width, value)
          return // recreateGroupAtSize handles save
        } else if (obj.type === 'rect') {
          obj.set('height', value * PX_PER_MM)
          if (obj.elementType === 'circle') {
            const roundness = (data.border_radius ?? 100) / 100
            const maxRadius = Math.min(obj.width, value * PX_PER_MM) / 2
            obj.set({ rx: roundness * maxRadius, ry: roundness * maxRadius })
          }
        } else if (obj.type === 'image') {
          const newH = value * PX_PER_MM
          obj.set('scaleY', newH / obj.height)
          obj._explicitSizeUpdate = true
        } else if (obj.type === 'textbox' && data.text_auto_fit === true) {
          // When auto-fit is on, height is user-controlled (bounding box)
          this.updateTextFit(obj)
        }
        // When auto-fit is off, height is auto-calculated by Fabric (no action needed)
        break
      }
      case 'rotation':
        obj.set('angle', value)
        break
      case 'color':
        // For QR and barcode, changing color requires regenerating
        if (obj.elementType === 'qr' || obj.elementType === 'barcode') {
          obj.elementData = data
          this.recreateCodeElement(obj, data.binding || data.text_content, 'preserve')
          return // recreateCodeElement handles save
        }
        obj._originalColor = value
        // Only apply color if not showing placeholder
        if (!obj._isPlaceholder) {
          obj.set('fill', value)
        }
        break
      case 'text_content':
        if (obj.type === 'textbox') {
          if (value && value.trim() !== '') {
            obj.set('text', value)
            obj.set('fill', obj._originalColor || data.color || '#000000')
            obj._isPlaceholder = false
          } else if (data.binding) {
            // text_content cleared but has binding: show binding indicator
            if (isExpression(data.binding)) {
              const preview = evaluate(data.binding, {}, { rowIndex: 0, batchSize: 1, now: new Date() })
              obj.set('text', preview || data.binding)
              obj.set('fontStyle', 'italic')
            } else {
              obj.set('text', `[${data.binding}]`)
            }
            obj.set('fill', obj._originalColor || data.color || '#000000')
            obj._isPlaceholder = false
          } else {
            obj.set('text', 'Completar texto')
            obj.set('fill', '#999999')
            obj._isPlaceholder = true
          }
          // Force text recalculation
          obj.initDimensions()
          obj.setCoords()
          // Auto-fit width to content if text is short
          this.updateTextFit(obj)
        } else if (obj.elementType === 'qr' || obj.elementType === 'barcode') {
          // For QR and barcode, changing text_content requires regenerating
          // Pass 'text_content' to preserve the binding value (important for fixed text mode)
          obj.elementData = data
          this.recreateCodeElement(obj, value, 'text_content')
          return // recreateCodeElement handles save
        }
        break
      case 'font_size':
        if (obj.type === 'textbox') {
          obj.set('fontSize', value)
          // Recalculate dimensions after font size change
          this.updateTextFit(obj)
        }
        break
      case 'font_weight':
        if (obj.type === 'textbox') {
          obj.set('fontWeight', value)
          this.updateTextFit(obj)
        }
        break
      case 'font_family':
        if (obj.type === 'textbox') {
          obj.set('fontFamily', value)
          this.updateTextFit(obj)
        }
        break
      case 'text_align':
        if (obj.type === 'textbox') {
          obj.set('textAlign', value)
        }
        break
      case 'text_auto_fit':
      case 'text_min_font_size':
        if (obj.type === 'textbox') {
          this.updateTextFit(obj)
        }
        break
      case 'background_color':
        // For QR and barcode, changing background_color requires regenerating
        if (obj.elementType === 'qr' || obj.elementType === 'barcode') {
          obj.elementData = data
          this.recreateCodeElement(obj, data.binding || data.text_content, 'preserve')
          return // recreateCodeElement handles save
        }
        obj.set('fill', value)
        break
      case 'border_color':
        obj.set('stroke', value)
        break
      case 'border_width':
        if (obj.elementType === 'line') {
          // For lines, border_width controls the line thickness (height of the rect)
          obj.set('height', Math.max(value * PX_PER_MM, 2))
        } else {
          obj.set('strokeWidth', value * PX_PER_MM)
        }
        break
      case 'border_radius':
        // For circle and rectangle elements, update the rx/ry based on roundness percentage
        if ((obj.elementType === 'circle' || obj.elementType === 'rectangle') && obj.type === 'rect') {
          const roundness = value / 100
          const maxRadius = Math.min(obj.width, obj.height) / 2
          obj.set({ rx: roundness * maxRadius, ry: roundness * maxRadius })
        }
        break
      case 'binding':
        // For QR and barcode elements, changing binding requires regenerating the code
        if (obj.elementType === 'qr' || obj.elementType === 'barcode') {
          obj.elementData = data  // Update elementData before recreating
          this.recreateCodeElement(obj, value, 'binding')
          return // recreateCodeElement handles save
        }
        // For text elements, show column name or evaluated expression
        if (obj.type === 'textbox') {
          if (value) {
            if (isExpression(value)) {
              const preview = evaluate(value, {}, { rowIndex: 0, batchSize: 1, now: new Date() })
              obj.set('text', preview || value)
              obj.set('fontStyle', 'italic')
            } else {
              obj.set('text', `[${value}]`)
              obj.set('fontStyle', 'normal')
            }
            obj.set('fill', obj._originalColor || data.color || '#000000')
            obj._isPlaceholder = false
          } else if (data.text_content && data.text_content.trim() !== '') {
            // Binding cleared: restore text_content
            obj.set('text', data.text_content)
            obj.set('fill', obj._originalColor || data.color || '#000000')
            obj._isPlaceholder = false
          } else {
            // Binding cleared, no text_content: show placeholder
            obj.set('text', 'Completar texto')
            obj.set('fill', '#999999')
            obj._isPlaceholder = true
          }
          obj.initDimensions()
          obj.setCoords()
          this.updateTextFit(obj)
        }
        break
      case 'qr_error_level':
        // Changing QR error level requires regenerating the QR code
        if (obj.elementType === 'qr') {
          obj.elementData = data
          this.recreateCodeElement(obj, data.binding || data.text_content, 'preserve')
          return // recreateCodeElement handles save
        }
        break
      case 'barcode_show_text':
        // Changing barcode show_text requires regenerating the barcode
        if (obj.elementType === 'barcode') {
          obj.elementData = data
          this.recreateCodeElement(obj, data.binding || data.text_content, 'preserve')
          return // recreateCodeElement handles save
        }
        break
      case 'barcode_format':
        // Changing barcode format requires regenerating the barcode
        if (obj.elementType === 'barcode') {
          obj.elementData = data  // Update elementData before recreating (includes new format)
          this.recreateCodeElement(obj, data.binding || data.text_content, 'preserve')
          return // recreateCodeElement handles save
        }
        break
    }

    obj.elementData = data
    obj.setCoords()
    this.canvas.renderAll()
    this.saveElements()
  },

  /**
   * Update text fit: auto-shrink font or auto-expand width depending on text_auto_fit setting.
   */
  updateTextFit(textObj) {
    if (!textObj || textObj.type !== 'textbox') return

    const data = textObj.elementData
    if (data && data.text_auto_fit === true) {
      // Auto-fit mode: shrink font to fit bounding box
      const boxW = textObj.width
      const boxH = (data.height || 14) * PX_PER_MM
      const maxFontSize = data.font_size || textObj.fontSize
      const minFontSize = data.text_min_font_size || 6

      const content = textObj.text || ''
      const { fontSize, overflows } = calcAutoFitFontSize(
        content, boxW, boxH, maxFontSize, minFontSize,
        data.font_family || 'Arial', data.font_weight || 'normal'
      )
      textObj.set('fontSize', fontSize)
      textObj._textOverflows = overflows

      // Update overflow indicator
      if (overflows) {
        textObj.set({ stroke: '#dc2626', strokeDashArray: [5, 3], strokeWidth: 1.5 })
      } else {
        textObj.set({ stroke: null, strokeDashArray: null, strokeWidth: 0 })
      }
    } else {
      // Legacy mode: auto-expand width
      const textWidth = textObj.calcTextWidth()
      const minWidth = 10 * PX_PER_MM
      const padding = 2 * PX_PER_MM
      const newWidth = Math.max(textWidth + padding, minWidth)
      textObj.set('width', newWidth)

      if (data) {
        data.width = newWidth / PX_PER_MM
      }

      // Clear any overflow indicator from previous auto-fit
      textObj.set({ stroke: null, strokeDashArray: null, strokeWidth: 0 })
      textObj._textOverflows = false
    }
  },

  /**
   * Recreate a group (QR/barcode) at a new size
   * This is needed because scaling groups doesn't persist well
   */
  recreateGroupAtSize(obj, newWidthMM, newHeightMM) {
    if (!obj || !obj.elementId) return

    const elementId = obj.elementId
    const elementType = obj.elementType
    const data = { ...obj.elementData }

    // Update dimensions
    data.width = newWidthMM
    data.height = newHeightMM

    // Get current position (convert from canvas coords to mm)
    const x = (obj.left - this.labelBounds.left) / PX_PER_MM
    const y = (obj.top - this.labelBounds.top) / PX_PER_MM
    data.x = x
    data.y = y

    // Remove old badge and object
    this.removeFormatBadge(obj)
    this.canvas.remove(obj)
    this.elements.delete(elementId)

    // Create new object at new size
    const newX = this.labelBounds.left + x * PX_PER_MM
    const newY = this.labelBounds.top + y * PX_PER_MM

    let newObj
    if (elementType === 'qr') {
      newObj = this.createQR(data, newX, newY)
    } else if (elementType === 'barcode') {
      newObj = this.createBarcode(data, newX, newY)
    }

    if (newObj) {
      newObj.elementId = elementId
      newObj.elementType = elementType
      newObj.elementData = data

      // Copy over visibility/lock state
      newObj.set({
        visible: obj.visible,
        selectable: obj.selectable,
        evented: obj.evented,
        lockMovementX: obj.lockMovementX,
        lockMovementY: obj.lockMovementY,
        cornerColor: '#3b82f6',
        cornerStyle: 'circle',
        cornerSize: 8,
        transparentCorners: false,
        borderColor: obj.lockMovementX ? '#f59e0b' : '#3b82f6',
        borderScaleFactor: 2
      })

      this.elements.set(elementId, newObj)
      this.canvas.add(newObj)

      // Add format badge for barcode elements
      if (elementType === 'barcode') {
        this.addFormatBadge(newObj, data.barcode_format || 'CODE128', elementId)
      }

      this.canvas.setActiveObject(newObj)
      this.canvas.renderAll()
      // Save immediately (not debounced) to persist the correct dimensions
      // before the async image generation can replace the placeholder
      this.saveElementsImmediate()
    }
  },

  /**
   * Recreate a QR code or barcode element with new content
   * Used when the binding or text_content field changes
   * @param {Object} obj - The fabric object to recreate
   * @param {string} newContent - The new content value
   * @param {string} field - Which field triggered the recreation:
   *   - 'binding': update both binding and text_content
   *   - 'text_content': update only text_content, preserve binding
   *   - 'preserve': don't change binding/text_content (used for style changes like color)
   */
  recreateCodeElement(obj, newContent, field = 'binding') {
    if (!obj || !obj.elementId) return

    const elementId = obj.elementId
    const elementType = obj.elementType
    const data = { ...obj.elementData }

    // Update the appropriate field based on what triggered the recreation
    // This preserves the distinction between binding mode and fixed text mode
    if (field === 'binding') {
      data.binding = newContent
      // Also update text_content for display purposes when in binding mode
      if (newContent !== null && newContent !== undefined) {
        data.text_content = newContent
      }
    } else if (field === 'text_content') {
      // For text_content updates, preserve the existing binding value
      // binding: null means "fixed text mode"
      // binding: "" or string means "binding mode"
      data.text_content = newContent
    }
    // For 'preserve', we don't modify binding or text_content

    // Get current position (convert from canvas coords to mm)
    const x = (obj.left - this.labelBounds.left) / PX_PER_MM
    const y = (obj.top - this.labelBounds.top) / PX_PER_MM
    data.x = x
    data.y = y

    // Get current dimensions only if not explicitly set
    // (data comes from obj.elementData which may have been updated before this call)
    const currentWidth = obj.type === 'image'
      ? Math.round((obj.width * (obj.scaleX || 1)) / PX_PER_MM * 100) / 100
      : obj.type === 'group'
        ? Math.round(obj.getScaledWidth() / PX_PER_MM * 100) / 100
        : data.width
    const currentHeight = obj.type === 'image'
      ? Math.round((obj.height * (obj.scaleY || 1)) / PX_PER_MM * 100) / 100
      : obj.type === 'group'
        ? Math.round(obj.getScaledHeight() / PX_PER_MM * 100) / 100
        : data.height

    // Only use calculated dimensions if data doesn't already have explicit values
    if (!data.width || data.width === currentWidth) {
      data.width = currentWidth
    }
    if (!data.height || data.height === currentHeight) {
      data.height = currentHeight
    }

    // Set flag to prevent deselection event during recreation
    this._isRecreatingElement = true

    // Remove old badge and object
    this.removeFormatBadge(obj)
    this.canvas.remove(obj)
    this.elements.delete(elementId)

    // Create new object with updated content
    const newX = this.labelBounds.left + x * PX_PER_MM
    const newY = this.labelBounds.top + y * PX_PER_MM

    let newObj
    if (elementType === 'qr') {
      newObj = this.createQR(data, newX, newY)
    } else if (elementType === 'barcode') {
      newObj = this.createBarcode(data, newX, newY)
    }

    if (newObj) {
      newObj.elementId = elementId
      newObj.elementType = elementType
      newObj.elementData = data

      // Copy over visibility/lock state
      newObj.set({
        visible: obj.visible !== false,
        selectable: !obj.lockMovementX,
        evented: !obj.lockMovementX,
        lockMovementX: obj.lockMovementX || false,
        lockMovementY: obj.lockMovementY || false,
        cornerColor: '#3b82f6',
        cornerStyle: 'circle',
        cornerSize: 8,
        transparentCorners: false,
        borderColor: obj.lockMovementX ? '#f59e0b' : '#3b82f6',
        borderScaleFactor: 2
      })

      this.elements.set(elementId, newObj)
      this.canvas.add(newObj)

      // Add format badge for barcode elements
      if (elementType === 'barcode') {
        this.addFormatBadge(newObj, data.barcode_format || 'CODE128', elementId)
      }

      this.canvas.setActiveObject(newObj)
      this.canvas.renderAll()

      // Clear recreation flag
      this._isRecreatingElement = false

      this.saveElements()
    } else {
      // Clear flag even if creation failed
      this._isRecreatingElement = false
    }
  },

  deleteElement(id) {
    const obj = this.elements.get(id)
    if (obj) {
      this.removeFormatBadge(obj)
      this.canvas.remove(obj)
      this.elements.delete(id)
      this.cleanupEmptyGroups()
      this.updateDepthOverlays()
      this.canvas.renderAll()
      this.saveElements()
    }
  },

  deleteElements(ids) {
    if (!ids || ids.length === 0) return

    // Deselect all first to avoid issues with active selection
    this.canvas.discardActiveObject()

    // Remove each element
    ids.forEach(id => {
      const obj = this.elements.get(id)
      if (obj) {
        this.removeFormatBadge(obj)
        this.canvas.remove(obj)
        this.elements.delete(id)
      }
    })

    // Auto-dissolve groups that now have fewer than 2 members
    this.cleanupEmptyGroups()

    this.canvas.renderAll()
    this.saveElements()
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

    // Re-add elements (skip overlays during bulk load)
    this._isBulkLoading = true
    savedElements.forEach(el => this.addElement(el, false))
    this._isBulkLoading = false
    this.updateDepthOverlays()

    this.canvas.renderAll()

    // Re-fit to container after resize
    setTimeout(() => {
      this.fitToContainer()
    }, 100)
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
    // Don't save if canvas is destroyed or not initialized
    if (this._isDestroyed || !this.elements || !this._isInitialized) {
      console.warn('saveElementsImmediate: Canvas not ready, skipping save')
      return
    }

    // Don't save if canvas/labelBounds not set up
    if (!this.canvas || !this.labelBounds) {
      console.warn('saveElementsImmediate: Canvas or labelBounds not ready, skipping save')
      return
    }

    // CRITICAL: If objects are inside an ActiveSelection, their left/top are RELATIVE
    // to the selection center — not absolute canvas coords. Temporarily discard the
    // selection so all positions become absolute, then restore it after collecting data.
    const activeObj = this.canvas.getActiveObject()
    const wasActiveSelection = activeObj && activeObj.type === 'activeSelection'
    let selectedObjects = null
    if (wasActiveSelection) {
      selectedObjects = activeObj.getObjects().slice()
      // Suppress selection events during save to avoid server-side flickering
      this._isSavingElements = true
      this.canvas.discardActiveObject()
      this._isSavingElements = false
    }

    const elements = []

    this.elements.forEach((obj, id) => {
      if (!obj || !obj.elementType) return

      const data = obj.elementData || {}

      // Calculate position from canvas coordinates (always absolute now)
      const currentX = Math.round(((obj.left - this.labelBounds.left) / PX_PER_MM) * 100) / 100
      const currentY = Math.round(((obj.top - this.labelBounds.top) / PX_PER_MM) * 100) / 100

      // IMPORTANT: Preserve original width/height from elementData
      // Only update them if the element was explicitly resized (scaleX/scaleY != 1)
      let width = data.width
      let height = data.height

      // Handle size calculations based on object type
      const scaleX = obj.scaleX || 1
      const scaleY = obj.scaleY || 1

      // Detect QR/barcode by elementType (they can be fabric.Group or fabric.Image
      // depending on whether async generation has completed)
      const isCodeElement = obj.elementType === 'qr' || obj.elementType === 'barcode'

      if (isCodeElement) {
        // For QR/barcode: Get actual visual dimensions
        const visualWidthMM = Math.round((obj.getScaledWidth() / PX_PER_MM) * 100) / 100
        const visualHeightMM = Math.round((obj.getScaledHeight() / PX_PER_MM) * 100) / 100

        // Always use the visual dimensions as the source of truth
        width = visualWidthMM
        height = visualHeightMM

        // Update elementData to match visual (keep in sync)
        if (data.width !== width || data.height !== height) {
          data.width = width
          data.height = height
          obj.elementData = data
        }

        // Only mark for recreation if the user actually resized the element
        // (scale changed from creation scale, not just != 1).
        // Barcode images always have non-1 scale because bwip-js output
        // dimensions don't match target dimensions.
        const baseScaleX = obj._creationScaleX || 1
        const baseScaleY = obj._creationScaleY || 1
        if (Math.abs(scaleX - baseScaleX) > 0.01 || Math.abs(scaleY - baseScaleY) > 0.01) {
          if (!obj._pendingRecreate) {
            obj._pendingRecreate = { width, height }
          }
        }
      } else if (obj._explicitSizeUpdate) {
        // Size was set explicitly from properties panel
        delete obj._explicitSizeUpdate
        // For images: recalculate scale to match the new data dimensions
        if (obj.type === 'image' && obj.width > 0 && obj.height > 0) {
          obj.set({
            scaleX: (data.width * PX_PER_MM) / obj.width,
            scaleY: (data.height * PX_PER_MM) / obj.height
          })
          obj.setCoords()
        }
      } else if (obj.elementType === 'image' && obj.type === 'image') {
        // Images use scale for rendering — read visual size directly, never reset scale
        width = Math.round((obj.getScaledWidth() / PX_PER_MM) * 100) / 100
        height = Math.round((obj.getScaledHeight() / PX_PER_MM) * 100) / 100
        if (data.width !== width || data.height !== height) {
          data.width = width
          data.height = height
          obj.elementData = data
        }
      } else if (obj.type === 'textbox') {
        // Textbox: Fabric.js modifies width directly (not via scale)
        // Always read current width from the object
        width = Math.round((obj.width / PX_PER_MM) * 100) / 100
        if (data.text_auto_fit === true) {
          // Auto-fit ON: preserve user-defined height (bounding box)
          height = data.height || Math.round((obj.height / PX_PER_MM) * 100) / 100
        } else {
          // Auto-fit OFF: height is auto-calculated by Fabric
          height = Math.round((obj.height / PX_PER_MM) * 100) / 100
        }
        // Update elementData to stay in sync
        if (data.width !== width || data.height !== height) {
          data.width = width
          data.height = height
          obj.elementData = data
        }
      } else if (obj.type === 'ellipse') {
        // Ellipse uses rx/ry, convert to width/height (diameter)
        const visualWidth = Math.round(((obj.rx * 2 * scaleX) / PX_PER_MM) * 100) / 100
        const visualHeight = Math.round(((obj.ry * 2 * scaleY) / PX_PER_MM) * 100) / 100
        width = visualWidth
        height = visualHeight
        // Reset scale and update rx/ry to normalized values
        if (Math.abs(scaleX - 1) > 0.01 || Math.abs(scaleY - 1) > 0.01) {
          obj.set({
            rx: (width * PX_PER_MM) / 2,
            ry: (height * PX_PER_MM) / 2,
            scaleX: 1,
            scaleY: 1
          })
          obj.setCoords()
        }
        // Update elementData
        if (data.width !== width || data.height !== height) {
          data.width = width
          data.height = height
          obj.elementData = data
        }
      } else if (Math.abs(scaleX - 1) > 0.01 || Math.abs(scaleY - 1) > 0.01) {
        // Element was resized by dragging handles - recalculate dimensions from scale
        width = Math.round((data.width * scaleX) * 100) / 100
        height = Math.round((data.height * scaleY) * 100) / 100
        // Reset scale and update data
        obj.set({ scaleX: 1, scaleY: 1 })
        obj.setCoords()
        data.width = width
        data.height = height
        obj.elementData = data
      }

      // Build element object with all required fields
      const elementObj = {
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
        name: data.name,
        group_id: data.group_id || null
      }

      // CRITICAL: Explicitly include image data for image elements
      // This prevents image_data from being lost during save
      if (obj.elementType === 'image') {
        elementObj.image_data = data.image_data || null
        elementObj.image_filename = data.image_filename || null
      }

      elements.push(elementObj)
    })

    // Build groups array from the groups Map
    const groups = []
    this.groups.forEach((g, id) => {
      groups.push({ id: g.id, name: g.name, locked: !!g.locked, visible: g.visible !== false, collapsed: !!g.collapsed })
    })

    // Restore ActiveSelection if we discarded it
    if (wasActiveSelection && selectedObjects && selectedObjects.length > 0) {
      const sel = new fabric.ActiveSelection(selectedObjects, { canvas: this.canvas })
      this.canvas.setActiveObject(sel)
      this.canvas.requestRenderAll()
    }

    // Record save time to prevent load_design from reverting changes
    this._lastSaveTime = Date.now()
    this.pushEvent("element_modified", { elements, groups })

    // After saving, recreate any QR/barcode marked for recreation (regenerate at new size)
    this.elements.forEach((obj, id) => {
      if (obj._pendingRecreate && (obj.elementType === 'qr' || obj.elementType === 'barcode')) {
        const { width, height } = obj._pendingRecreate
        delete obj._pendingRecreate
        this.recreateGroupWithoutSave(obj, width, height)
      }
    })
  },

  /**
   * Recreate a group at new dimensions without triggering a save
   * Used to normalize scale after drag-resize
   */
  recreateGroupWithoutSave(obj, newWidthMM, newHeightMM) {
    if (!obj || !obj.elementId) return

    const elementId = obj.elementId
    const elementType = obj.elementType
    const data = { ...obj.elementData }
    const wasActive = this.canvas.getActiveObject() === obj

    // Update dimensions
    data.width = newWidthMM
    data.height = newHeightMM

    // Get current position
    const x = (obj.left - this.labelBounds.left) / PX_PER_MM
    const y = (obj.top - this.labelBounds.top) / PX_PER_MM
    data.x = x
    data.y = y

    // Suppress selection:cleared during recreation
    this._isRecreatingElement = true

    // Remove old badge and object
    this.removeFormatBadge(obj)
    this.canvas.remove(obj)
    this.elements.delete(elementId)

    // Create new object at new size
    const newX = this.labelBounds.left + x * PX_PER_MM
    const newY = this.labelBounds.top + y * PX_PER_MM

    let newObj
    if (elementType === 'qr') {
      newObj = this.createQR(data, newX, newY)
    } else if (elementType === 'barcode') {
      newObj = this.createBarcode(data, newX, newY)
    }

    if (newObj) {
      newObj.elementId = elementId
      newObj.elementType = elementType
      newObj.elementData = data

      // Copy over visibility/lock state
      newObj.set({
        visible: obj.visible,
        selectable: obj.selectable,
        evented: obj.evented,
        lockMovementX: obj.lockMovementX,
        lockMovementY: obj.lockMovementY,
        cornerColor: '#3b82f6',
        cornerStyle: 'circle',
        cornerSize: 8,
        transparentCorners: false,
        borderColor: obj.lockMovementX ? '#f59e0b' : '#3b82f6',
        borderScaleFactor: 2
      })

      this.elements.set(elementId, newObj)
      this.canvas.add(newObj)

      // Add format badge for barcode elements
      if (elementType === 'barcode') {
        this.addFormatBadge(newObj, data.barcode_format || 'CODE128', elementId)
      }

      // Restore selection if this was the active object
      if (wasActive) {
        this.canvas.setActiveObject(newObj)
      }

      this._isRecreatingElement = false
      this.canvas.renderAll()
    } else {
      this._isRecreatingElement = false
    }
  },

  // ============================================================================
  // Image Methods
  // ============================================================================

  captureCanvasThumbnail() {
    if (!this.canvas || !this.labelBounds) return null

    const zoom = this.canvas.getZoom()
    const bounds = this.labelBounds
    const maxThumbWidth = 320
    const maxThumbHeight = 220

    // Capture only the label area (excluding gray padding/rulers)
    const dataUrl = this.canvas.toDataURL({
      format: 'jpeg',
      quality: 0.8,
      left: bounds.left * zoom,
      top: bounds.top * zoom,
      width: bounds.width * zoom,
      height: bounds.height * zoom
    })

    // Scale down to thumbnail size using an offscreen canvas
    const img = new Image()
    return new Promise((resolve) => {
      img.onload = () => {
        const scale = Math.min(maxThumbWidth / img.width, maxThumbHeight / img.height, 1)
        const w = Math.round(img.width * scale)
        const h = Math.round(img.height * scale)
        const offscreen = document.createElement('canvas')
        offscreen.width = w
        offscreen.height = h
        const ctx = offscreen.getContext('2d')
        ctx.drawImage(img, 0, 0, w, h)
        resolve(offscreen.toDataURL('image/jpeg', 0.85))
      }
      img.onerror = () => resolve(null)
      img.src = dataUrl
    })
  },

  updateElementImage(elementId, imageData, imageFilename) {
    // Try to find element by ID (handle both number and string keys)
    let obj = this.elements.get(elementId)
    if (!obj) {
      obj = this.elements.get(String(elementId))
    }
    if (!obj) {
      obj = this.elements.get(Number(elementId))
    }

    if (!obj) {
      return
    }

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

      if (!img || !img.width || !img.height) {
        return
      }

      // Uniform scale to preserve aspect ratio (fit within the area)
      const uniformScale = Math.min(w / img.width, h / img.height)

      img.set({
        left: x,
        top: y,
        scaleX: uniformScale,
        scaleY: uniformScale,
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

      // Important: Save with a delay to ensure image is properly set
      // Use immediate save (not debounced) to prevent race conditions
      setTimeout(() => {
        this.saveElementsImmediate()
      }, 100)
    }, { crossOrigin: 'anonymous' })
  },

  // ============================================================================
  // Group Methods
  // ============================================================================

  createGroup(groupId, name, elementIds) {
    // Register the group
    this.groups.set(groupId, { id: groupId, name, locked: false, visible: true, collapsed: false })

    // Assign group_id to each element
    elementIds.forEach(elId => {
      const obj = this.elements.get(elId)
      if (obj && obj.elementData) {
        obj.elementData.group_id = groupId
      }
    })

    this.saveElementsImmediate()
  },

  ungroupElements(groupId) {
    // Remove group_id from all members
    this.elements.forEach((obj) => {
      if (obj.elementData && obj.elementData.group_id === groupId) {
        obj.elementData.group_id = null
      }
    })

    // Delete the group
    this.groups.delete(groupId)
    this.saveElementsImmediate()
  },

  removeFromGroup(elementId) {
    const obj = this.elements.get(elementId)
    if (!obj || !obj.elementData || !obj.elementData.group_id) return

    obj.elementData.group_id = null
    // Auto-cleanup will dissolve groups with <2 members
    this.cleanupEmptyGroups()
    this.saveElementsImmediate()
  },

  toggleGroupVisibility(groupId) {
    const group = this.groups.get(groupId)
    if (!group) return

    const newVisible = !group.visible
    group.visible = newVisible

    // Toggle visibility on all members
    this.elements.forEach((obj) => {
      if (obj.elementData && obj.elementData.group_id === groupId) {
        obj.set('visible', newVisible)
      }
    })

    this.canvas.renderAll()
    this.saveElementsImmediate()
  },

  toggleGroupLock(groupId) {
    const group = this.groups.get(groupId)
    if (!group) return

    const newLocked = !group.locked
    group.locked = newLocked

    // Toggle lock on all members
    this.elements.forEach((obj) => {
      if (obj.elementData && obj.elementData.group_id === groupId) {
        obj.set({
          lockMovementX: newLocked,
          lockMovementY: newLocked,
          lockRotation: newLocked,
          lockScalingX: newLocked,
          lockScalingY: newLocked,
          selectable: !newLocked,
          evented: !newLocked
        })
      }
    })

    this.canvas.renderAll()
    this.saveElementsImmediate()
  },

  // Get all fabric objects belonging to a group
  getGroupMembers(groupId) {
    const members = []
    this.elements.forEach((obj) => {
      if (obj.elementData && obj.elementData.group_id === groupId) {
        members.push(obj)
      }
    })
    return members
  },

  // Auto-dissolve groups with fewer than 2 members
  cleanupEmptyGroups() {
    const groupCounts = new Map()
    this.elements.forEach((obj) => {
      const gid = obj.elementData && obj.elementData.group_id
      if (gid) {
        groupCounts.set(gid, (groupCounts.get(gid) || 0) + 1)
      }
    })

    // Remove groups with <2 members
    this.groups.forEach((group, gid) => {
      const count = groupCounts.get(gid) || 0
      if (count < 2) {
        // Unassign remaining members
        this.elements.forEach((obj) => {
          if (obj.elementData && obj.elementData.group_id === gid) {
            obj.elementData.group_id = null
          }
        })
        this.groups.delete(gid)
      }
    })
  },

  // Expand selection to include all group members (unless Ctrl-click)
  expandSelectionToGroups(selected, isCtrlClick) {
    if (isCtrlClick || !selected || selected.length === 0) return selected

    const groupIds = new Set()
    selected.forEach(obj => {
      const gid = obj.elementData && obj.elementData.group_id
      if (gid) groupIds.add(gid)
    })

    if (groupIds.size === 0) return selected

    // Add all members of the same groups
    const expanded = new Set(selected)
    groupIds.forEach(gid => {
      this.getGroupMembers(gid).forEach(obj => expanded.add(obj))
    })

    return Array.from(expanded)
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
    // Map old group_id → new group_id to preserve groups in pasted elements
    const groupIdMap = new Map()

    elements.forEach(el => {
      let newGroupId = null
      if (el.group_id) {
        if (!groupIdMap.has(el.group_id)) {
          const newGid = 'grp_' + Math.random().toString(36).substr(2, 9)
          groupIdMap.set(el.group_id, newGid)
          // Clone the group with new id
          const oldGroup = this.groups.get(el.group_id)
          if (oldGroup) {
            this.groups.set(newGid, { ...oldGroup, id: newGid, name: oldGroup.name + ' (copia)' })
          } else {
            this.groups.set(newGid, { id: newGid, name: 'Grupo (copia)', locked: false, visible: true, collapsed: false })
          }
        }
        newGroupId = groupIdMap.get(el.group_id)
      }

      const newElement = {
        ...el,
        id: this.generateId(),
        x: (el.x || 0) + offset,
        y: (el.y || 0) + offset,
        name: el.name ? `${el.name} (copia)` : undefined,
        group_id: newGroupId
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
    // Suppress selection:cleared during reordering (bringToFront can trigger it)
    this._isSavingElements = true

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

    this._isSavingElements = false

    // Update depth overlays after reordering
    this.updateDepthOverlays()
  },

  // ============================================================================
  // Depth Overlay System
  // Draws semi-transparent overlays at intersection areas between stacked elements
  // to visually indicate which element is on top (lower elements get dimmed where covered)
  // ============================================================================

  // Remove all existing depth overlay objects from the canvas
  clearDepthOverlays() {
    const toRemove = this.canvas.getObjects().filter(o => o._isDepthOverlay)
    toRemove.forEach(o => this.canvas.remove(o))
  },

  // Calculate the intersection rectangle of two axis-aligned bounding boxes
  // Returns null if no intersection
  getIntersectionRect(r1, r2) {
    const x1 = Math.max(r1.left, r2.left)
    const y1 = Math.max(r1.top, r2.top)
    const x2 = Math.min(r1.left + r1.width, r2.left + r2.width)
    const y2 = Math.min(r1.top + r1.height, r2.top + r2.height)

    if (x2 <= x1 || y2 <= y1) return null // No overlap
    return { left: x1, top: y1, width: x2 - x1, height: y2 - y1 }
  },

  // Main method: recalculate and draw depth overlays at all intersection areas
  updateDepthOverlays() {
    if (this._isBulkLoading) return
    // Suppress selection:cleared during overlay manipulation
    const wasSaving = this._isSavingElements
    this._isSavingElements = true
    this.clearDepthOverlays()

    if (this.elements.size <= 1) return

    // Collect elements with their bounding rects sorted by z_index ascending
    const items = []
    this.elements.forEach((obj, id) => {
      if (!obj.visible) return
      items.push({
        id,
        obj,
        zIndex: obj.elementData?.z_index || 0,
        bounds: obj.getBoundingRect(true, true) // absolute + force recalculate
      })
    })
    items.sort((a, b) => a.zIndex - b.zIndex)

    // Find lower elements that have at least one OPAQUE higher element overlapping them.
    // Skip transparent upper elements — the user should see through them.
    const dimmedSet = new Set()
    for (let i = 0; i < items.length; i++) {
      if (dimmedSet.has(items[i].id)) continue // already marked
      const lower = items[i]
      for (let j = i + 1; j < items.length; j++) {
        const upper = items[j]
        if (upper.zIndex <= lower.zIndex) continue

        // Skip if upper element has transparent/no fill
        const upperFill = upper.obj.fill
        if (!upperFill || upperFill === 'transparent' || upperFill === 'rgba(0,0,0,0)') continue

        const inter = this.getIntersectionRect(lower.bounds, upper.bounds)
        if (inter) {
          dimmedSet.add(lower.id)
          break // one overlap is enough to dim this element
        }
      }
    }

    // Create overlays covering the full bounds of each dimmed element
    dimmedSet.forEach(lowerId => {
      const item = items.find(it => it.id === lowerId)
      if (!item) return

      const overlay = new fabric.Rect({
        left: item.bounds.left,
        top: item.bounds.top,
        width: item.bounds.width,
        height: item.bounds.height,
        fill: 'rgba(255,255,255,0.45)',
        selectable: false,
        evented: false,
        excludeFromExport: true,
        _isDepthOverlay: true,
        _depthForZ: item.zIndex
      })
      this.canvas.add(overlay)
    })

    // Re-apply z-ordering: element → overlay (dim) → next element → ...
    // Overlays sit just above their element, below everything else
    const overlays = this.canvas.getObjects().filter(o => o._isDepthOverlay)
    items.forEach(item => {
      this.canvas.bringToFront(item.obj)
      if (dimmedSet.has(item.id)) {
        const ov = overlays.find(o => o._depthForZ === item.zIndex)
        if (ov) this.canvas.bringToFront(ov)
      }
    })

    // Restore flag
    this._isSavingElements = wasSaving
  },

  // Auto bring-to-front: when an element is dropped overlapping another with higher z_index,
  // automatically bring it to the top so the moved element always ends up on top
  autoBringToFrontIfOverlapping(obj) {
    if (!obj || !obj.elementId || !obj.elementData) return

    const myZ = obj.elementData.z_index || 0
    const myBounds = obj.getBoundingRect(true, true)

    // Check if any visible element with higher z_index overlaps this one
    let maxZ = myZ
    this.elements.forEach((other, otherId) => {
      if (otherId === obj.elementId || !other.visible) return
      const otherZ = other.elementData?.z_index || 0
      if (otherZ <= myZ) return

      const otherBounds = other.getBoundingRect(true, true)
      const inter = this.getIntersectionRect(myBounds, otherBounds)
      if (inter) {
        if (otherZ > maxZ) maxZ = otherZ
      }
    })

    if (maxZ > myZ) {
      obj.elementData.z_index = maxZ + 1
      this.applyZIndexOrdering()
      // Notify server of the layer change
      this.pushEvent("element_selected", { id: obj.elementId })
    }
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

    this.updateDepthOverlays()
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
    this.updateDepthOverlays()
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
    const threshold = this.snapThreshold * 2 // Increased for better UX

    // Get moving object bounds
    const movingBounds = this.getObjectBounds(movingObj)

    // Element snap
    if (this.snapEnabled) {
      const updatedBounds = movingBounds

      // Snap to other elements (skip group siblings to avoid feedback loop)
      const excludeGid = this._snapExcludeGroupId
      this.elements.forEach((obj, id) => {
        if (obj === movingObj || !obj.visible) return
        if (excludeGid && obj.elementData && obj.elementData.group_id === excludeGid) return

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

    const baseH = this._baseCanvasHeight || this.canvas.height
    const baseW = this._baseCanvasWidth || this.canvas.width
    uniqueLines.forEach(line => {
      let fabricLine
      if (line.type === 'vertical') {
        fabricLine = new fabric.Line(
          [line.x, 0, line.x, baseH],
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
          [0, line.y, baseW, line.y],
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
  },

  setupDragAndDrop() {
    const container = this.el

    // Listen for custom element-drop event from DraggableElements hook
    container.addEventListener('element-drop', (e) => {
      const { type, x, y } = e.detail

      // Convert to mm (accounting for zoom and label position)
      const zoom = this._currentZoom || 1
      const xMm = (x / zoom - this.labelBounds.left) / PX_PER_MM
      const yMm = (y / zoom - this.labelBounds.top) / PX_PER_MM

      // Send event to LiveView with position
      this.pushEvent("add_element_at", {
        type: type,
        x: Math.max(0, Math.round(xMm * 10) / 10),
        y: Math.max(0, Math.round(yMm * 10) / 10)
      })
    })
  }
}

export default CanvasDesigner
