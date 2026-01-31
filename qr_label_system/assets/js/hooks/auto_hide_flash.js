const AutoHideFlash = {
  mounted() {
    this.timeout = setTimeout(() => {
      this.el.style.opacity = '0'
      setTimeout(() => {
        // Don't push event - just remove the element to avoid LiveView re-render
        this.el.remove()
      }, 300)
    }, 3000)
  },

  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}

export default AutoHideFlash
