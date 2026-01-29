/**
 * Keyboard Shortcuts Hook
 * Provides keyboard shortcuts for the label editor
 *
 * Shortcuts:
 * - Ctrl+Z: Undo
 * - Ctrl+Y / Ctrl+Shift+Z: Redo
 * - Ctrl+S: Save
 * - Ctrl+P: Toggle Preview
 * - Delete/Backspace: Delete selected element
 * - Escape: Deselect element
 * - Q: Add QR code
 * - B: Add Barcode
 * - T: Add Text
 * - L: Add Line
 * - R: Add Rectangle
 */

const KeyboardShortcuts = {
  mounted() {
    this.handleKeyDown = this.handleKeyDown.bind(this)
    document.addEventListener('keydown', this.handleKeyDown)
  },

  destroyed() {
    document.removeEventListener('keydown', this.handleKeyDown)
  },

  handleKeyDown(e) {
    // Ignore if typing in an input field
    if (this.isTyping(e.target)) {
      return
    }

    const isCtrl = e.ctrlKey || e.metaKey
    const isShift = e.shiftKey

    // Ctrl+Z: Undo
    if (isCtrl && !isShift && e.key === 'z') {
      e.preventDefault()
      this.pushEvent('undo', {})
      return
    }

    // Ctrl+Y or Ctrl+Shift+Z: Redo
    if ((isCtrl && e.key === 'y') || (isCtrl && isShift && e.key === 'z')) {
      e.preventDefault()
      this.pushEvent('redo', {})
      return
    }

    // Ctrl+S: Save
    if (isCtrl && e.key === 's') {
      e.preventDefault()
      this.pushEvent('save_design', {})
      return
    }

    // Ctrl+P: Toggle Preview
    if (isCtrl && e.key === 'p') {
      e.preventDefault()
      this.pushEvent('toggle_preview', {})
      return
    }

    // Delete or Backspace: Delete selected element
    if (e.key === 'Delete' || e.key === 'Backspace') {
      e.preventDefault()
      this.pushEvent('delete_element', {})
      return
    }

    // Escape: Deselect
    if (e.key === 'Escape') {
      e.preventDefault()
      this.pushEvent('element_deselected', {})
      return
    }

    // Quick add elements (only when not pressing Ctrl)
    if (!isCtrl) {
      switch (e.key.toLowerCase()) {
        case 'q':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'qr'})
          break
        case 'b':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'barcode'})
          break
        case 't':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'text'})
          break
        case 'l':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'line'})
          break
        case 'r':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'rectangle'})
          break
        case 'i':
          e.preventDefault()
          this.pushEvent('add_element', {type: 'image'})
          break
      }
    }
  },

  isTyping(target) {
    const tagName = target.tagName.toLowerCase()
    return tagName === 'input' ||
           tagName === 'textarea' ||
           tagName === 'select' ||
           target.isContentEditable
  }
}

export default KeyboardShortcuts
