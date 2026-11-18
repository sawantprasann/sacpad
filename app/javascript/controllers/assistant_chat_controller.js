import { Controller } from "@hotwired/stimulus"

// The question is drawn before the request returns. The answer arrives as a
// Turbo Stream, so the page does not reload.
export default class extends Controller {
  static targets = [ "thread", "list", "form", "input", "empty", "thinking" ]

  submit(event) {
    event.preventDefault()
    const body = this.inputTarget.value.trim()
    if (!body || this.sending) return

    this.sending = true
    this.appendUser(body)
    this.inputTarget.value = ""
    this.showThinking()
    this.scroll()

    const data = new FormData(this.formTarget)
    data.set("body", body)

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
        this.showFailure()
      }
    }).catch(() => {
      this.showFailure()
    }).finally(() => {
      this.sending = false
      this.scroll()
      this.inputTarget.focus()
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

  showThinking() {
    this.listTarget.appendChild(this.thinkingTarget.content.cloneNode(true))
  }

  showFailure() {
    const thinking = document.getElementById("assistant-thinking")
    const label = thinking?.querySelector("[data-thinking-label]")
    if (!label) return
    label.textContent = thinking.dataset.failed
    thinking.removeAttribute("id")
  }

  scroll() {
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }
}
