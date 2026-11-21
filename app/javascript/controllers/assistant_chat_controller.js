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
      const html = await response.text()
      if (html.includes("<turbo-stream")) {
        window.Turbo.renderStreamMessage(html)
        window.Alpine?.initTree?.(document.getElementById("chat-history"))
      } else {
        this.showFailure(pendingId)
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
    text.className = "max-w-xl rounded-2xl bg-gray-100 px-4 py-3 text-sm leading-6 text-gray-700 dark:bg-gray-800 dark:text-gray-200"
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
