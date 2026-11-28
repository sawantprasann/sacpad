import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "name" ]

  show(event) {
    const file = event.target.files[0]
    this.nameTarget.textContent = file ? file.name : this.nameTarget.dataset.empty
  }
}
