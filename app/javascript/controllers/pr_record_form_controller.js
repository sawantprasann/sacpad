import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "entryRows", "entryTemplate" ]
  static values = {
    thumbnailUrl: String,
    checking: String,
    noThumbnail: String,
    thumbnailFilled: String
  }

  connect() {
    this.entryIndex = Date.now()
  }

  addEntry(event) {
    event.preventDefault()
    this.entryIndex += 1
    const html = this.entryTemplateTarget.innerHTML.replaceAll("__ENTRY__", String(this.entryIndex))
    this.entryRowsTarget.insertAdjacentHTML("beforeend", html)
  }

  removeEntry(event) {
    event.preventDefault()
    const entry = event.target.closest("[data-entry]")
    const destroy = entry.querySelector("[data-entry-destroy]")
    if (destroy) {
      destroy.value = "1"
      entry.hidden = true
    } else {
      entry.remove()
    }
  }

  addLink(event) {
    event.preventDefault()
    const entry = event.target.closest("[data-entry]")
    const html = entry.querySelector("[data-link-template]").innerHTML.replaceAll("__LINK__", Date.now().toString())
    entry.querySelector("[data-link-rows]").insertAdjacentHTML("beforeend", html)
  }

  removeLink(event) {
    event.preventDefault()
    const row = event.target.closest("[data-link-row]")
    const destroy = row.querySelector("[data-link-destroy]")
    if (destroy) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }

  async fetchThumbnail(event) {
    event.preventDefault()
    const row = event.target.closest("[data-link-row]")
    const status = row.querySelector("[data-link-status]")
    const url = row.querySelector("[data-link-url]").value
    status.textContent = this.checkingValue
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.thumbnailUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ url })
    })
    const data = await response.json()
    if (!response.ok) {
      status.textContent = data.error || this.noThumbnailValue
      return
    }
    row.querySelector("[data-link-thumb]").value = data.thumbnail_url
    status.textContent = this.thumbnailFilledValue
  }
}
