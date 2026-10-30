import { Controller } from "@hotwired/stimulus"

// Month grid is rendered by the server. This opens the add/edit dialog and
// fills the date, time, and color fields for the day or event that was chosen.
export default class extends Controller {
  static targets = [
    "dialog", "form", "title", "color", "startsOn", "startsTime", "endsOn", "endsTime",
    "location", "notes", "heading", "submit", "destroyForm", "destroyWrap", "destroyButton", "error"
  ]
  static values = { open: Boolean, fresh: Boolean, date: String }

  connect() {
    if (this.openValue) {
      this.show()
    } else if (this.freshValue) {
      this.createOnDate(this.dateValue)
    }
  }

  createOn(event) {
    this.createOnDate(event.params.date)
  }

  createOnDate(date) {
    this.formTarget.action = this.formTarget.dataset.createUrl
    this.setMethod("post")
    this.headingTarget.textContent = this.element.dataset.newHeading
    this.submitTarget.textContent = this.element.dataset.saveLabel
    this.hideDestroy()
    this.hideErrors()
    this.fill({
      title: "",
      color: "primary",
      startsOn: date,
      startsTime: "09:00",
      endsOn: date,
      endsTime: "10:00",
      location: "",
      notes: ""
    })
    this.show()
  }

  edit(event) {
    const data = event.params.event
    this.formTarget.action = data.url
    this.setMethod("patch")
    this.headingTarget.textContent = this.element.dataset.editHeading
    this.submitTarget.textContent = this.element.dataset.updateLabel
    this.destroyFormTarget.action = data.url
    this.destroyWrapTarget.classList.remove("hidden")
    this.destroyButtonTarget.disabled = false
    this.hideErrors()
    this.fill(data)
    this.show()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target !== this.dialogTarget) return

    const rect = this.dialogTarget.getBoundingClientRect()
    const inside = event.clientX >= rect.left && event.clientX <= rect.right &&
      event.clientY >= rect.top && event.clientY <= rect.bottom
    if (!inside) this.close()
  }

  fill(data) {
    this.titleTarget.value = data.title || ""
    this.locationTarget.value = data.location || ""
    this.notesTarget.value = data.notes || ""
    this.startsTimeTarget.value = data.startsTime || "09:00"
    this.endsTimeTarget.value = data.endsTime || "10:00"
    this.setDate(this.startsOnTarget, data.startsOn)
    this.setDate(this.endsOnTarget, data.endsOn)
    this.setColor(data.color || "primary")
  }

  setDate(input, value) {
    if (input._flatpickr) {
      input._flatpickr.setDate(value || "", true)
    } else {
      input.value = value || ""
    }
  }

  setColor(color) {
    const chosen = this.colorTargets.some((input) => input.value === color) ? color : "primary"
    this.colorTargets.forEach((input) => {
      input.checked = input.value === chosen
    })
  }

  setMethod(verb) {
    let input = this.formTarget.querySelector("input[name='_method']")
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "_method"
      this.formTarget.prepend(input)
    }
    input.value = verb
  }

  hideDestroy() {
    if (this.hasDestroyWrapTarget) this.destroyWrapTarget.classList.add("hidden")
    if (this.hasDestroyButtonTarget) this.destroyButtonTarget.disabled = true
  }

  hideErrors() {
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }

  show() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
    this.titleTarget.focus()
  }
}
