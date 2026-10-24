import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

const PREV_ARROW = `<svg class="stroke-current" width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12.5 15L7.5 10L12.5 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`
const NEXT_ARROW = `<svg class="stroke-current" width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7.5 15L12.5 10L7.5 5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`

// TailAdmin date field: calendar icon, "Select date" placeholder, and the flatpickr popup.
// The named input keeps YYYY-MM-DD so forms still submit an ISO date.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.picker = flatpickr(this.inputTarget, {
      mode: "single",
      static: true,
      monthSelectorType: "static",
      dateFormat: "Y-m-d",
      altInput: true,
      altFormat: "F j, Y",
      altInputClass: this.inputTarget.className,
      allowInput: false,
      disableMobile: true,
      prevArrow: PREV_ARROW,
      nextArrow: NEXT_ARROW
    })

    if (!this.inputTarget.id) return

    this.onLabelClick = (event) => {
      event.preventDefault()
      this.picker.open()
    }
    this.label = document.querySelector(`label[for="${CSS.escape(this.inputTarget.id)}"]`)
    this.label?.addEventListener("click", this.onLabelClick)
  }

  disconnect() {
    this.label?.removeEventListener("click", this.onLabelClick)
    this.picker?.destroy()
  }
}
