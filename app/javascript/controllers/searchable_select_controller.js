import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "select", "optionsContainer", "option"]

  connect() {
    this.originalOptions = Array.from(this.selectTarget.options).map(opt => ({
      value: opt.value,
      text: opt.text,
      element: opt
    }))
  }

  search(event) {
    const query = this.inputTarget.value.toLowerCase()

    this.originalOptions.forEach(option => {
      const matches = option.text.toLowerCase().includes(query)
      option.element.style.display = matches ? "" : "none"
    })
  }

  clearSearch() {
    this.inputTarget.value = ""
    this.originalOptions.forEach(option => {
      option.element.style.display = ""
    })
  }
}
