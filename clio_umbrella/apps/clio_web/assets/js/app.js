import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { Hooks as BackpexHooks } from "backpex"

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...BackpexHooks }
})

liveSocket.connect()

window.liveSocket = liveSocket
