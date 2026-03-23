import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { Hooks as BackpexHooks } from "backpex"

let Hooks = {}

// Copy text to clipboard
Hooks.ClipboardCopy = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.content
      navigator.clipboard.writeText(text).then(() => {
        const original = this.el.innerText
        this.el.innerText = "Copied!"
        setTimeout(() => { this.el.innerText = original }, 2000)
      })
    })
  }
}

// Ctrl+S / Cmd+S save shortcut
Hooks.SaveShortcut = {
  mounted() {
    this.handleKeyDown = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault()
        this.pushEvent("save_current_edit", {})
      }
    }
    window.addEventListener("keydown", this.handleKeyDown)
  },
  destroyed() {
    window.removeEventListener("keydown", this.handleKeyDown)
  }
}

// Persist card field visibility to localStorage
Hooks.CardFieldSettings = {
  mounted() {
    const stored = localStorage.getItem("clio_visible_fields")
    if (stored) {
      this.pushEvent("restore_field_settings", JSON.parse(stored))
    }
    this.handleEvent("save_field_settings", (settings) => {
      localStorage.setItem("clio_visible_fields", JSON.stringify(settings))
    })
  }
}

// Auto-focus inputs when they appear
Hooks.AutoFocus = {
  mounted() {
    this.el.focus()
    if (this.el.select) this.el.select()
  }
}

// Tab navigation between editable fields
Hooks.TabNavigation = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Tab") {
        e.preventDefault()
        this.pushEvent("tab_to_next_field", { current: this.el.dataset.field, shift: e.shiftKey })
      }
    })
  }
}

// Drag and drop file upload zone
Hooks.DropZone = {
  mounted() {
    this.el.addEventListener("dragover", (e) => {
      e.preventDefault()
      this.el.classList.add("border-blue-500", "bg-gray-700")
    })
    this.el.addEventListener("dragleave", (e) => {
      e.preventDefault()
      this.el.classList.remove("border-blue-500", "bg-gray-700")
    })
    this.el.addEventListener("drop", (e) => {
      e.preventDefault()
      this.el.classList.remove("border-blue-500", "bg-gray-700")
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...BackpexHooks, ...Hooks }
})

liveSocket.connect()

window.liveSocket = liveSocket
