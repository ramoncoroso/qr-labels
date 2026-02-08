/**
 * Property Fields Hook
 * Handles Tab cycling through property fields and preserves focus during re-renders
 */

const PropertyFields = {
  mounted() {
    this.focusedElementName = null
    this.focusedElementValue = null
    this.cursorPosition = null
    this._blurTimeout = null

    // Bind handlers for proper cleanup
    this._handleKeydown = (e) => {
      if (e.key === 'Tab') {
        this.handleTab(e)
      }
    }

    this._handleFocusin = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        this.focusedElementName = e.target.getAttribute('data-field') || e.target.getAttribute('phx-value-field') || e.target.id
        this.focusedElementValue = e.target.value
        this.cursorPosition = e.target.selectionStart
      }
    }

    this._handleInput = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        this.focusedElementValue = e.target.value
        this.cursorPosition = e.target.selectionStart
      }
    }

    this._handleFocusout = () => {
      // Clear any existing timeout
      if (this._blurTimeout) {
        clearTimeout(this._blurTimeout)
      }
      // Delay clearing to allow for re-focus after render
      this._blurTimeout = setTimeout(() => {
        if (!this.el.contains(document.activeElement)) {
          this.focusedElementName = null
          this.focusedElementValue = null
          this.cursorPosition = null
        }
      }, 50)
    }

    this.el.addEventListener('keydown', this._handleKeydown)
    this.el.addEventListener('focusin', this._handleFocusin)
    this.el.addEventListener('input', this._handleInput)
    this.el.addEventListener('focusout', this._handleFocusout)
  },

  destroyed() {
    // Clean up event listeners and timers
    if (this._blurTimeout) {
      clearTimeout(this._blurTimeout)
    }
    this.el.removeEventListener('keydown', this._handleKeydown)
    this.el.removeEventListener('focusin', this._handleFocusin)
    this.el.removeEventListener('input', this._handleInput)
    this.el.removeEventListener('focusout', this._handleFocusout)
  },

  updated() {
    // After LiveView re-render, restore focus if we had one
    if (this.focusedElementName) {
      // Sanitize the field name to prevent CSS selector injection
      const safeName = CSS.escape(this.focusedElementName)
      const input = this.el.querySelector(
        `[data-field="${safeName}"], [phx-value-field="${safeName}"], #${safeName}`
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
