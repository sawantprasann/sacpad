import { Controller } from "@hotwired/stimulus"

// The question is drawn before the request returns. The answer arrives as a
// Turbo Stream, so the page does not reload.
export default class extends Controller {
  static targets = [ "thread", "list", "form", "input", "empty", "thinking" ]

  submit(event) {
    event.preventDefault()
    const body = this.inputTarget.value.trim()
    if (!body) return

    const pendingId = `pending-${crypto.randomUUID()}`
    this.appendUser(body)
    this.inputTarget.value = ""
    this.showThinking(pendingId)
    this.scroll()
    this.inputTarget.focus()

    const data = new FormData(this.formTarget)
    data.set("body", body)
    data.set("pending_id", pendingId)

    fetch(this.formTarget.action, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: data
    }).then(async (response) => {
      if (!response.ok) {
        this.showFailure(pendingId)
        return
      }
      const html = await response.text()
      if (!html.includes("<turbo-stream")) return

      try {
        window.Turbo.renderStreamMessage(html)
        const history = document.getElementById("chat-history")
        if (history) window.Alpine?.initTree?.(history)
      } catch (_) {
        // The reply is still delivered to this bubble. A sidebar refresh
        // must not turn a saved answer into the failure sentence.
      }
    }).catch(() => {
      this.showFailure(pendingId)
    })
  }

  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  appendUser(body) {
    if (this.hasEmptyTarget) this.emptyTarget.remove()
    const row = document.createElement("div")
    row.className = "flex justify-end"
    const text = document.createElement("p")
    text.className = "max-w-[85%] rounded-2xl rounded-br-md bg-[#465fff] px-3.5 py-2.5 text-sm leading-6 text-white"
    text.textContent = body
    row.appendChild(text)
    this.listTarget.appendChild(row)
  }

  showThinking(pendingId) {
    const node = this.thinkingTarget.content.cloneNode(true)
    node.querySelector("#assistant-thinking").id = pendingId
    this.listTarget.appendChild(node)
  }

  showFailure(pendingId) {
    const thinking = document.getElementById(pendingId)
    const label = thinking?.querySelector("[data-thinking-label]")
    if (!label) return
    label.textContent = thinking.dataset.failed
  }

  scroll() {
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }
}
