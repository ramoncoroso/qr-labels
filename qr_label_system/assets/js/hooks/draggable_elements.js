// Hook to make element toolbar buttons draggable
console.log('DraggableElements module loaded!')

const DraggableElements = {
  mounted() {
    console.log('DraggableElements: mounted()', this.el.id)
    this.setupDraggable()
  },

  updated() {
    console.log('DraggableElements: updated()')
    this.setupDraggable()
  },

  setupDraggable() {
    const buttons = this.el.querySelectorAll('.draggable-element')
    console.log('DraggableElements: found', buttons.length, 'buttons')

    buttons.forEach(btn => {
      // Skip if already set up
      if (btn._draggableSetup) return
      btn._draggableSetup = true

      console.log('DraggableElements: setting up', btn.dataset.elementType)

      // Make draggable
      btn.setAttribute('draggable', 'true')
      btn.style.cursor = 'grab'

      btn.addEventListener('dragstart', (e) => {
        console.log('DraggableElements: dragstart', btn.dataset.elementType)
        e.stopPropagation()
        btn.style.cursor = 'grabbing'
        e.dataTransfer.setData('element-type', btn.dataset.elementType)
        e.dataTransfer.effectAllowed = 'copy'

        // Create visible drag ghost
        const ghost = document.createElement('div')
        ghost.textContent = btn.querySelector('span')?.textContent || btn.dataset.elementType
        ghost.style.cssText = 'position: fixed; top: -100px; left: -100px; background: #3b82f6; color: white; padding: 8px 12px; border-radius: 6px; font-size: 14px; font-weight: 500; z-index: 9999;'
        document.body.appendChild(ghost)

        e.dataTransfer.setDragImage(ghost, ghost.offsetWidth / 2, ghost.offsetHeight / 2)

        requestAnimationFrame(() => {
          setTimeout(() => ghost.remove(), 100)
        })
      })

      btn.addEventListener('dragend', () => {
        console.log('DraggableElements: dragend')
        btn.style.cursor = 'grab'
      })
    })
  }
}

export default DraggableElements
