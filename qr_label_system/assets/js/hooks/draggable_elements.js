// Hook to make element toolbar buttons draggable using manual drag (more reliable than native)
const DraggableElements = {
  mounted() {
    this._cleanupFns = []
    this._canvasContainer = null
    this.setupDraggable()
  },

  updated() {
    this.setupDraggable()
  },

  destroyed() {
    // Clean up all event listeners
    this._cleanupFns.forEach(fn => fn())
    this._cleanupFns = []
    this._canvasContainer = null
  },

  getCanvasContainer() {
    // Cache the canvas container reference
    if (!this._canvasContainer || !this._canvasContainer.isConnected) {
      this._canvasContainer = document.getElementById('canvas-container')
    }
    return this._canvasContainer
  },

  setupDraggable() {
    const buttons = this.el.querySelectorAll('.draggable-element')
    const hook = this
    const DRAG_THRESHOLD = 5

    buttons.forEach(btn => {
      if (btn._draggableSetup) return
      btn._draggableSetup = true

      btn.style.cursor = 'grab'
      btn.setAttribute('draggable', 'false')

      let startX = 0
      let startY = 0
      let isDragging = false
      let ghost = null

      const createGhost = (text) => {
        const el = document.createElement('div')
        el.textContent = text
        el.style.cssText = `
          position: fixed;
          pointer-events: none;
          background: #3b82f6;
          color: white;
          padding: 8px 16px;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 500;
          z-index: 10000;
          box-shadow: 0 4px 12px rgba(0,0,0,0.3);
          transform: translate(-50%, -50%);
        `
        document.body.appendChild(el)
        return el
      }

      const removeGhost = () => {
        if (ghost) {
          ghost.remove()
          ghost = null
        }
      }

      const handleMouseMove = (e) => {
        const dx = e.clientX - startX
        const dy = e.clientY - startY
        const distance = Math.sqrt(dx * dx + dy * dy)

        if (!isDragging && distance > DRAG_THRESHOLD) {
          isDragging = true
          const text = btn.querySelector('span')?.textContent || btn.dataset.elementType
          ghost = createGhost(text)
        }

        if (isDragging && ghost) {
          ghost.style.left = e.clientX + 'px'
          ghost.style.top = e.clientY + 'px'

          const canvas = hook.getCanvasContainer()
          if (canvas) {
            const rect = canvas.getBoundingClientRect()
            const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                          e.clientY >= rect.top && e.clientY <= rect.bottom
            canvas.classList.toggle('ring-2', isOver)
            canvas.classList.toggle('ring-blue-400', isOver)
          }
        }
      }

      const handleMouseUp = (e) => {
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
        btn.style.cursor = 'grab'

        const canvas = hook.getCanvasContainer()
        if (canvas) {
          canvas.classList.remove('ring-2', 'ring-blue-400')
        }

        const elementType = btn.dataset.elementType
        if (!elementType) {
          removeGhost()
          return
        }

        if (isDragging) {
          removeGhost()

          if (canvas) {
            const rect = canvas.getBoundingClientRect()
            const isOverCanvas = e.clientX >= rect.left && e.clientX <= rect.right &&
                                e.clientY >= rect.top && e.clientY <= rect.bottom

            if (isOverCanvas) {
              const x = e.clientX - rect.left
              const y = e.clientY - rect.top

              canvas.dispatchEvent(new CustomEvent('element-drop', {
                detail: { type: elementType, x, y }
              }))
            }
          }
        } else {
          hook.pushEvent('add_element', { type: elementType })
        }

        isDragging = false
      }

      const handleMouseDown = (e) => {
        if (e.button !== 0) return

        startX = e.clientX
        startY = e.clientY
        isDragging = false
        btn.style.cursor = 'grabbing'

        document.addEventListener('mousemove', handleMouseMove)
        document.addEventListener('mouseup', handleMouseUp)
        e.preventDefault()
      }

      btn.addEventListener('mousedown', handleMouseDown)

      // Store cleanup function
      this._cleanupFns.push(() => {
        btn.removeEventListener('mousedown', handleMouseDown)
        btn._draggableSetup = false
      })
    })
  }
}

export default DraggableElements
