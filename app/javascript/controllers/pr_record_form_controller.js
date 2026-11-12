import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "entryRows", "newEntryRows", "entryTemplate", "categoryNotice" ]
  static values = {
    thumbnailUrl: String,
    checking: String,
    noThumbnail: String,
    thumbnailFilled: String,
    chooseFirst: String,
    lastCategory: String,
    removeFailed: String
  }

  connect() {
    this.entryIndex = Date.now()
    this.renumber()
  }

  addEntry(event) {
    event.preventDefault()
    const pending = this.pendingCategoryEntry()
    if (pending) {
      this.categoryNoticeTarget.textContent = this.chooseFirstValue
      this.categoryNoticeTarget.classList.remove("hidden")
      pending.querySelector("[data-pr-record-entry-target='category']")?.focus({ preventScroll: true })
      return
    }
    this.clearCategoryNotice()
    this.entryIndex += 1
    const html = this.entryTemplateTarget.innerHTML.replaceAll("__ENTRY__", String(this.entryIndex))
    this.newEntryRowsTarget.insertAdjacentHTML("afterbegin", html)
    this.renumber()
    this.newEntryRowsTarget.querySelector("[data-entry] select")?.focus({ preventScroll: true })
  }

  categoryChanged() {
    if (!this.pendingCategoryEntry()) this.clearCategoryNotice()
  }

  pendingCategoryEntry() {
    const entries = [
      ...this.newEntryRowsTarget.querySelectorAll("[data-entry]"),
      ...this.entryRowsTarget.querySelectorAll("[data-entry]")
    ]
    return entries.find((entry) => {
      if (entry.hidden) return false
      const select = entry.querySelector("[data-pr-record-entry-target='category']")
      return select && select.value === ""
    })
  }

  clearCategoryNotice() {
    if (!this.hasCategoryNoticeTarget) return
    this.categoryNoticeTarget.textContent = ""
    this.categoryNoticeTarget.classList.add("hidden")
  }

  async removeEntry(event) {
    event.preventDefault()
    const button = event.currentTarget
    const entry = button.closest("[data-entry]")
    if (!entry || entry.hidden) return
    const ask = window.sacpadConfirm || ((text, options = {}) => Promise.resolve(options.alert ? true : window.confirm(text)))
    if (this.visibleEntries().length <= 1) {
      await ask(this.lastCategoryValue, { alert: true })
      return
    }
    const message = button.dataset.confirm
    if (message && !(await ask(message))) return

    const url = button.dataset.destroyUrl
    if (url) {
      button.disabled = true
      const removed = await this.destroyEntry(url)
      button.disabled = false
      if (!removed) return
    }

    const destroy = entry.querySelector("[data-entry-destroy]")
    if (destroy && !url) {
      destroy.value = "1"
      entry.hidden = true
    } else {
      entry.remove()
    }
    if (!this.pendingCategoryEntry()) this.clearCategoryNotice()
    this.renumber()
  }

  visibleEntries() {
    return [
      ...this.newEntryRowsTarget.querySelectorAll("[data-entry]"),
      ...this.entryRowsTarget.querySelectorAll("[data-entry]")
    ].filter((entry) => !entry.hidden)
  }

  async destroyEntry(url) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    let response
    try {
      response = await fetch(url, {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token
        }
      })
    } catch {
      await this.tell(this.removeFailedValue)
      return false
    }
    if (response.ok) return true

    let message = this.removeFailedValue
    try {
      const data = await response.json()
      if (data.error) message = data.error
    } catch {
      // The response had no JSON body. The fallback message still explains the failure.
    }
    await this.tell(message)
    return false
  }

  tell(message) {
    const ask = window.sacpadConfirm || ((text) => Promise.resolve(window.alert(text)))
    return ask(message, { alert: true })
  }

  renumber() {
    let number = 0
    const assign = (entry) => {
      if (entry.hidden) return
      number += 1
      const slot = entry.querySelector("[data-entry-index]")
      if (slot) slot.textContent = String(number)
    }
    this.entryRowsTarget.querySelectorAll("[data-entry]").forEach(assign)
    // New blocks sit above the saved ones, but they were added after, so they take the next numbers.
    ;[ ...this.newEntryRowsTarget.querySelectorAll("[data-entry]") ].reverse().forEach(assign)
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
