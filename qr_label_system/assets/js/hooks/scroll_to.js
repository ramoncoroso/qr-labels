const ScrollTo = {
  mounted() {
    this.handleEvent("scroll_to", ({ id }) => {
      requestAnimationFrame(() => {
        const el = document.getElementById(id)
        if (el) {
          el.scrollIntoView({ behavior: "smooth", block: "start" })
        }
      })
    })
  }
}

export default ScrollTo
