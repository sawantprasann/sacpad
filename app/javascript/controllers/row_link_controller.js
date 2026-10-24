import { Controller } from "@hotwired/stimulus"

// Opens the row's record. Links and buttons inside the row keep their own action.
export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (event.target.closest("a, button, input, select, textarea, label")) return
    if (!this.hasUrlValue) return

    window.Turbo.visit(this.urlValue)
  }
}
