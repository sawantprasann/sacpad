import { Controller } from "@hotwired/stimulus"

// Remembers whether a <details> panel was left open or closed.
// The markup can start open; a saved "closed" choice still wins.
export default class extends Controller {
  static values = { key: String }

  connect() {
    const stored = this.stored()
    if (stored === "open") this.element.open = true
    if (stored === "closed") this.element.open = false
  }

  toggle() {
    this.store(this.element.open ? "open" : "closed")
  }

  stored() {
    try {
      return window.localStorage.getItem(this.storageKey)
    } catch {
      return null
    }
  }

  store(value) {
    try {
      window.localStorage.setItem(this.storageKey, value)
    } catch {
      // Private browsing can block storage. The panel still toggles for this visit.
    }
  }

  get storageKey() {
    return `sacpad:disclosure:${this.keyValue}`
  }
}
