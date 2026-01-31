// Hook to make element toolbar buttons draggable using manual drag (more reliable than native)
const DraggableElements = {
  mounted() {
    this.setupDraggable()
  },

  updated() {
    this.setupDraggable()
  },

  setupDraggable() {
    const buttons = this.el.querySelectorAll('.draggable-element')
    const hook = this

    buttons.forEach(btn => {
      if (btn._draggableSetup) return
      btn._draggableSetup = true

      btn.style.cursor = 'grab'
      btn.setAttribute('draggable', 'false') // Disable native drag

      let startX = 0
      let startY = 0
      let isDragging = false
      let ghost = null
      const DRAG_THRESHOLD = 5 // Pixels to move before considering it a drag

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

      const moveGhost = (x, y) => {
        if (ghost) {
          ghost.style.left = x + 'px'
          ghost.style.top = y + 'px'
        }
      }

      const removeGhost = () => {
        if (ghost) {
          ghost.remove()
          ghost = null
        }
      }

      const getCanvasContainer = () => {
        return document.getElementById('canvas-container')
      }

      const handleMouseDown = (e) => {
        if (e.button !== 0) return // Only left click

        startX = e.clientX
        startY = e.clientY
        isDragging = false
        btn.style.cursor = 'grabbing'

        document.addEventListener('mousemove', handleMouseMove)
        document.addEventListener('mouseup', handleMouseUp)
        e.preventDefault()
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

        if (isDragging) {
          moveGhost(e.clientX, e.clientY)

          // Highlight canvas when hovering over it
          const canvas = getCanvasContainer()
          if (canvas) {
            const rect = canvas.getBoundingClientRect()
            const isOver = e.clientX >= rect.left && e.clientX <= rect.right &&
                          e.clientY >= rect.top && e.clientY <= rect.bottom
            if (isOver) {
              canvas.classList.add('ring-2', 'ring-blue-400')
            } else {
              canvas.classList.remove('ring-2', 'ring-blue-400')
            }
          }
        }
      }

      const handleMouseUp = (e) => {
        document.removeEventListener('mousemove', handleMouseMove)
        document.removeEventListener('mouseup', handleMouseUp)
        btn.style.cursor = 'grab'

        const canvas = getCanvasContainer()
        if (canvas) {
          canvas.classList.remove('ring-2', 'ring-blue-400')
        }

        const elementType = btn.dataset.elementType
        if (!elementType) {
          removeGhost()
          return
        }

        if (isDragging) {
          // Was a drag - check if dropped on canvas
          removeGhost()

          if (canvas) {
            const rect = canvas.getBoundingClientRect()
            const isOverCanvas = e.clientX >= rect.left && e.clientX <= rect.right &&
                                e.clientY >= rect.top && e.clientY <= rect.bottom

            if (isOverCanvas) {
              // Calculate position relative to canvas
              const x = e.clientX - rect.left
              const y = e.clientY - rect.top

              // Dispatch custom event to canvas for position calculation
              const dropEvent = new CustomEvent('element-drop', {
                detail: { type: elementType, x, y }
              })
              canvas.dispatchEvent(dropEvent)
            }
          }
        } else {
          // Was a click - add element at default position
          hook.pushEvent('add_element', { type: elementType })
        }

        isDragging = false
      }

      btn.addEventListener('mousedown', handleMouseDown)
    })
  }
}

export default DraggableElements
