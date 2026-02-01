/**
 * BorderRadiusSlider Hook
 * Handles the border-radius slider for circle elements without LiveView re-renders
 */

const BorderRadiusSlider = {
  mounted() {
    this.slider = this.el.querySelector('input[type="range"]')
    this.valueDisplay = this.el.querySelector('span')
    this.elementId = this.el.dataset.elementId

    // Set initial value
    const initialValue = parseFloat(this.el.dataset.value) || 100
    this.slider.value = initialValue
    this.valueDisplay.textContent = `${Math.round(initialValue)}%`

    // Handle slider changes - update canvas directly via custom event
    this.slider.addEventListener('input', (e) => {
      const value = parseFloat(e.target.value)
      this.valueDisplay.textContent = `${Math.round(value)}%`

      // Dispatch custom event for CanvasDesigner to handle
      window.dispatchEvent(new CustomEvent('border-radius-change', {
        detail: {
          elementId: this.elementId,
          value: value
        }
      }))
    })

    // Save on mouse up / touch end - push to server
    this.slider.addEventListener('change', (e) => {
      const value = parseFloat(e.target.value)

      // Dispatch event to trigger save in canvas
      window.dispatchEvent(new CustomEvent('border-radius-save', {
        detail: {
          elementId: this.elementId,
          value: value
        }
      }))
    })
  },

  updated() {
    // With phx-update="ignore", this shouldn't be called
    // But if it is, update the value from data attribute
    const newValue = parseFloat(this.el.dataset.value) || 100
    if (this.slider && this.slider.value != newValue) {
      this.slider.value = newValue
      this.valueDisplay.textContent = `${Math.round(newValue)}%`
    }
  }
}

export default BorderRadiusSlider
