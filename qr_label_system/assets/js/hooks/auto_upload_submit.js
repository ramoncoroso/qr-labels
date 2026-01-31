/**
 * AutoUploadSubmit Hook
 * Automatically submits a form when a file upload reaches 100% progress
 */
const AutoUploadSubmit = {
  mounted() {
    console.log('AutoUploadSubmit: mounted')
    this._submitted = false
    this.startPolling()
  },

  updated() {
    // Check for progress on every LiveView update
    this.checkProgress()
  },

  startPolling() {
    // Poll for progress changes since LiveView morphs don't trigger MutationObserver reliably
    this._pollInterval = setInterval(() => {
      this.checkProgress()
    }, 200)
  },

  checkProgress() {
    if (this._submitted) return

    // Find progress bar in this form
    const progressBar = this.el.querySelector('[style*="width:"]')
    if (progressBar) {
      const widthMatch = progressBar.style.width.match(/(\d+)%/)
      if (widthMatch) {
        const progress = parseInt(widthMatch[1])
        console.log('AutoUploadSubmit: progress', progress)

        if (progress === 100) {
          this._submitted = true
          // Small delay to ensure upload is complete
          setTimeout(() => {
            const submitBtn = this.el.querySelector('button[type="submit"]')
            if (submitBtn) {
              console.log('AutoUploadSubmit: Auto-submitting form')
              submitBtn.click()
            }
          }, 100)
        }
      }
    }
  },

  destroyed() {
    if (this._pollInterval) {
      clearInterval(this._pollInterval)
    }
  }
}

export default AutoUploadSubmit
