/**
 * Property Fields Hook
 * Handles Tab cycling through property fields
 * When Tab is pressed on the last field, focus moves to the first field
 */

const PropertyFields = {
  mounted() {
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        this.handleTab(e)
      }
    })
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
