import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "prompt", "panel" ]

  open() {
    this.promptTarget.hidden = true
    this.panelTarget.hidden = false
  }

  close() {
    this.panelTarget.hidden = true
    this.promptTarget.hidden = false
  }
}
