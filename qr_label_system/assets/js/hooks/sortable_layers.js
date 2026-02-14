/**
 * Sortable Layers Hook
 * Provides drag-to-reorder functionality for the layers panel
 */

const SortableLayers = {
  mounted() {
    this.initSortable()
  },

  updated() {
    // Re-initialize if the list structure changes
    this.initSortable()
  },

  destroyed() {
    this.cleanup()
  },

  initSortable() {
    this.cleanup()

    const container = this.el
    const items = container.querySelectorAll('[data-id]')
    this._handleListeners = []

    items.forEach(item => {
      const handle = item.querySelector('.drag-handle')
      if (handle) {
        const listener = this.handleDragStart.bind(this, item)
        handle.addEventListener('mousedown', listener)
        this._handleListeners.push({ handle, listener })
      }
    })

    this._dragItem = null
    this._placeholder = null
    this._initialY = 0
  },

  cleanup() {
    // Remove document-level drag handlers
    if (this._boundHandlers) {
      document.removeEventListener('mousemove', this._boundHandlers.move)
      document.removeEventListener('mouseup', this._boundHandlers.up)
    }
    // Remove per-handle mousedown handlers
    if (this._handleListeners) {
      this._handleListeners.forEach(({ handle, listener }) => {
        handle.removeEventListener('mousedown', listener)
      })
      this._handleListeners = []
    }
  },

  handleDragStart(item, e) {
    e.preventDefault()

    this._dragItem = item
    this._initialY = e.clientY
    this._itemHeight = item.offsetHeight

    // Create placeholder
    this._placeholder = document.createElement('div')
    this._placeholder.className = 'h-10 bg-blue-100 border-2 border-dashed border-blue-300 rounded mx-2'
    this._placeholder.style.height = `${this._itemHeight}px`

    // Style the dragged item
    item.style.position = 'relative'
    item.style.zIndex = '1000'
    item.style.backgroundColor = '#fff'
    item.style.boxShadow = '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
    item.style.opacity = '0.9'

    // Insert placeholder
    item.parentNode.insertBefore(this._placeholder, item.nextSibling)

    // Bind handlers
    this._boundHandlers = {
      move: this.handleDragMove.bind(this),
      up: this.handleDragEnd.bind(this)
    }

    document.addEventListener('mousemove', this._boundHandlers.move)
    document.addEventListener('mouseup', this._boundHandlers.up)
  },

  handleDragMove(e) {
    if (!this._dragItem || !this._placeholder) return

    const deltaY = e.clientY - this._initialY
    this._dragItem.style.transform = `translateY(${deltaY}px)`

    // Get all items
    const container = this.el
    const items = Array.from(container.querySelectorAll('[data-id]')).filter(
      item => item !== this._dragItem
    )

    // Find the item we're hovering over
    const dragRect = this._dragItem.getBoundingClientRect()
    const dragCenterY = dragRect.top + dragRect.height / 2

    let insertBefore = null
    for (const item of items) {
      const rect = item.getBoundingClientRect()
      const centerY = rect.top + rect.height / 2

      if (dragCenterY < centerY) {
        insertBefore = item
        break
      }
    }

    // Move placeholder
    if (insertBefore) {
      container.insertBefore(this._placeholder, insertBefore)
    } else {
      container.appendChild(this._placeholder)
    }
  },

  handleDragEnd() {
    if (!this._dragItem || !this._placeholder) return

    // Reset styles
    this._dragItem.style.position = ''
    this._dragItem.style.zIndex = ''
    this._dragItem.style.backgroundColor = ''
    this._dragItem.style.boxShadow = ''
    this._dragItem.style.opacity = ''
    this._dragItem.style.transform = ''

    // Move the actual item to placeholder position
    this._placeholder.parentNode.insertBefore(this._dragItem, this._placeholder)

    // Remove placeholder
    this._placeholder.remove()

    // Get new order
    const container = this.el
    const orderedIds = Array.from(container.querySelectorAll('[data-id]')).map(
      item => item.dataset.id
    )

    // Send to server
    this.pushEvent('reorder_layers', { ordered_ids: orderedIds })

    // Cleanup
    this.cleanup()
    this._dragItem = null
    this._placeholder = null
  }
}

export default SortableLayers
