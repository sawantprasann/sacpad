import { Controller } from "@hotwired/stimulus"

// Bottom-corner button. The chat frame loads the first time it opens.
export default class extends Controller {
  static targets = [ "panel", "frame", "button" ]
  static values = { src: String }

  toggle() {
    const willOpen = this.panelTarget.classList.contains("hidden")
    this.panelTarget.classList.toggle("hidden", !willOpen)
    this.buttonTarget.setAttribute("aria-expanded", willOpen ? "true" : "false")
    if (willOpen && !this.frameTarget.getAttribute("src")) {
      this.frameTarget.src = this.srcValue
    }
    if (willOpen) {
      this.panelTarget.querySelector("textarea")?.focus()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
