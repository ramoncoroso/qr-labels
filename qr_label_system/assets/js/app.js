// Build version for debugging - change this to force cache bust
const BUILD_VERSION = '2.0.1-debug-' + Date.now()
console.log('🏷️ QR Label System Build:', BUILD_VERSION)

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import hooks
import Hooks from "./hooks"

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

if (!csrfToken) {
  console.error('❌ CSRF token not found! LiveView will not work.')
}

console.log('🔌 Initializing LiveSocket...')

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve Fabric.js canvas elements and their wrappers during LiveView updates
      // This is critical for Fabric.js to maintain state

      // Protect the canvas container (has phx-update="ignore" but this is extra protection)
      if (from.id === "canvas-container") {
        console.log('DOM: Protecting canvas-container from update')
        return false
      }

      // Protect the actual canvas
      if (from.id === "label-canvas") {
        console.log('DOM: Protecting label-canvas from update')
        return false
      }

      // Protect Fabric.js wrapper elements (they have class "canvas-container")
      if (from.classList?.contains('canvas-container')) {
        console.log('DOM: Protecting Fabric wrapper from update')
        return false
      }

      // Protect any element inside the canvas container
      if (from.closest('#canvas-container')) {
        console.log('DOM: Protecting element inside canvas-container from update')
        return false
      }

      return true
    }
  }
})

// Connection state tracking
let connectionAttempts = 0
const maxAttempts = 5

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Focus and select text in inputs (used by inline rename)
window.addEventListener("focus-and-select", (e) => {
  e.target.focus()
  e.target.select()
})

// Handle file download events
window.addEventListener("phx:download_file", (e) => {
  const {content, filename, mime_type} = e.detail
  const blob = new Blob([content], {type: mime_type})
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
})

// Enhanced connection monitoring
liveSocket.socket.onOpen(() => {
  console.log('✅ WebSocket connected successfully!')
  connectionAttempts = 0
  hideConnectionError()
})

liveSocket.socket.onClose((event) => {
  console.log('⚠️ WebSocket closed:', event)
  connectionAttempts++
  if (connectionAttempts >= maxAttempts) {
    showConnectionError()
  }
})

liveSocket.socket.onError((error) => {
  console.error('❌ WebSocket error:', error)
  connectionAttempts++
  if (connectionAttempts >= maxAttempts) {
    showConnectionError()
  }
})

function showConnectionError() {
  // Check if error banner already exists
  if (document.getElementById('connection-error-banner')) return

  const banner = document.createElement('div')
  banner.id = 'connection-error-banner'
  banner.className = 'fixed top-0 left-0 right-0 bg-red-600 text-white px-4 py-3 text-center z-50'
  banner.innerHTML = `
    <div class="flex items-center justify-center space-x-4">
      <span>⚠️ Error de conexión. Algunas funciones pueden no estar disponibles.</span>
      <button onclick="location.reload()" class="bg-white text-red-600 px-3 py-1 rounded text-sm font-medium hover:bg-red-50">
        Recargar página
      </button>
    </div>
  `
  document.body.prepend(banner)
}

function hideConnectionError() {
  const banner = document.getElementById('connection-error-banner')
  if (banner) {
    banner.remove()
  }
}

// connect if there are any LiveViews on the page
console.log('🔌 Connecting LiveSocket...')
liveSocket.connect()

// Enable debug mode in development
if (window.location.hostname === 'localhost') {
  liveSocket.enableDebug()
  console.log('🐛 Debug mode enabled for localhost')
}

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Log connection status after a timeout
setTimeout(() => {
  const state = liveSocket.socket?.connectionState?.()
  console.log('📊 Connection state after 3s:', state || 'unknown')
  if (state !== 'open') {
    console.warn('⚠️ WebSocket may not be connected. State:', state)
  }
}, 3000)
