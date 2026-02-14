/**
 * LangDropdown Hook
 * Client-side search filter for the language dropdown.
 */
const LangDropdown = {
  mounted() {
    const input = this.el.querySelector('#lang-search-input')
    const list = this.el.querySelector('#lang-dropdown-list')
    if (!input || !list) return

    // Filter options as the user types
    input.addEventListener('input', () => {
      const query = input.value.toLowerCase().trim()
      const options = list.querySelectorAll('.lang-option')

      options.forEach(btn => {
        const name = btn.dataset.langName || ''
        const code = btn.dataset.langCode || ''
        const match = !query || name.includes(query) || code.includes(query)
        btn.style.display = match ? '' : 'none'
      })
    })

    // Auto-focus the search input when the dropdown opens
    const menu = this.el.querySelector('#lang-dropdown-menu')
    if (menu) {
      const observer = new MutationObserver(() => {
        if (!menu.classList.contains('hidden')) {
          input.value = ''
          input.dispatchEvent(new Event('input'))
          // Small delay so the DOM settles before focusing
          requestAnimationFrame(() => input.focus())
        }
      })
      observer.observe(menu, { attributes: true, attributeFilter: ['class'] })
      this._observer = observer
    }
  },

  destroyed() {
    if (this._observer) this._observer.disconnect()
  }
}

export default LangDropdown
