/**
 * QR Logo Upload Hook
 * Handles file selection, validation, and base64 conversion for QR logo uploads
 */

const MAX_LOGO_SIZE = 500 * 1024 // 500KB

const QRLogoUpload = {
  mounted() {
    const container = this.el
    const fileInput = container.querySelector('#qr-logo-file-input')

    container.addEventListener('click', () => {
      fileInput.click()
    })

    fileInput.addEventListener('change', (e) => {
      const file = e.target.files[0]
      if (!file) return

      if (file.size > MAX_LOGO_SIZE) {
        alert('El logo es demasiado grande. Máximo 500KB.')
        fileInput.value = ''
        return
      }

      if (!file.type.match(/^image\/(png|jpeg|svg\+xml)$/)) {
        alert('Formato no soportado. Usa PNG, JPG o SVG.')
        fileInput.value = ''
        return
      }

      const reader = new FileReader()
      reader.onload = (event) => {
        const base64 = event.target.result
        this.pushEvent("update_element", {field: "qr_logo_data", value: base64})
      }
      reader.readAsDataURL(file)
    })
  }
}

export default QRLogoUpload
