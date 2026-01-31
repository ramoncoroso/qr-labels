const AutoHideFlash = {
  mounted() {
    this.timeout = setTimeout(() => {
      this.el.style.opacity = '0'
      setTimeout(() => {
        this.pushEvent("lv:clear-flash", { key: this.el.dataset.kind })
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
