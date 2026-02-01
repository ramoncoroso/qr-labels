/**
 * Property Fields Hook
 * Handles Tab cycling through property fields and preserves focus during re-renders
 */

const PropertyFields = {
  mounted() {
    this.focusedElementName = null
    this.focusedElementValue = null
    this.cursorPosition = null

    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        this.handleTab(e)
      }
    })

    // Track focus to restore after re-render
    this.el.addEventListener('focusin', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        this.focusedElementName = e.target.getAttribute('phx-value-field') || e.target.name
        this.focusedElementValue = e.target.value
        this.cursorPosition = e.target.selectionStart
      }
    })

    // Track cursor position changes
    this.el.addEventListener('input', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        this.focusedElementValue = e.target.value
        this.cursorPosition = e.target.selectionStart
      }
    })

    // Clear focus tracking on blur
    this.el.addEventListener('focusout', (e) => {
      // Delay clearing to allow for re-focus after render
      setTimeout(() => {
        if (!this.el.contains(document.activeElement)) {
          this.focusedElementName = null
          this.focusedElementValue = null
          this.cursorPosition = null
        }
      }, 50)
    })
  },

  updated() {
    // After LiveView re-render, restore focus if we had one
    if (this.focusedElementName) {
      const input = this.el.querySelector(
        `[phx-value-field="${this.focusedElementName}"], [name="${this.focusedElementName}"]`
      )
      if (input && document.activeElement !== input) {
        // Restore focus
        input.focus()

        // Restore the value the user was typing (not the server value)
        if (this.focusedElementValue !== null && input.value !== this.focusedElementValue) {
          input.value = this.focusedElementValue
        }

        // Restore cursor position
        if (this.cursorPosition !== null && input.setSelectionRange) {
          const pos = Math.min(this.cursorPosition, input.value.length)
          input.setSelectionRange(pos, pos)
        }
      }
    }
  },

  handleTab(e) {
    // Get all focusable inputs and selects within the properties panel
    const focusableElements = this.el.querySelectorAll(
      'input:not([type="hidden"]):not([disabled]), select:not([disabled])'
    )

    if (focusableElements.length === 0) return

    const focusableArray = Array.from(focusableElements)
    const currentIndex = focusableArray.indexOf(document.activeElement)

    if (currentIndex === -1) return

    if (e.shiftKey) {
      // Shift+Tab: go to previous, or cycle to last
      if (currentIndex === 0) {
        e.preventDefault()
        focusableArray[focusableArray.length - 1].focus()
      }
    } else {
      // Tab: go to next, or cycle to first
      if (currentIndex === focusableArray.length - 1) {
        e.preventDefault()
        focusableArray[0].focus()
      }
    }
  }
}

export default PropertyFields
