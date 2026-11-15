import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "item", "count", "empty", "selectAll", "save" ]

  connect() {
    this.refresh()
  }

  filter() {
    const query = this.hasInputTarget ? this.inputTarget.value.trim().toLowerCase() : ""
    this.itemTargets.forEach((el) => {
      const name = (el.dataset.name || "").toLowerCase()
      el.hidden = query.length > 0 && !name.includes(query)
    })
    this.refresh()
  }

  selectAll(event) {
    this.visibleBoxes().forEach((box) => {
      box.checked = event.target.checked
    })
    this.refresh()
  }

  refresh() {
    const selected = this.element.querySelectorAll("input[name='page_ids[]']:checked, input[name='instagram_ids[]']:checked")
    if (this.hasCountTarget) {
      this.countTargets.forEach((el) => {
        const template = el.dataset.template || "%{count}"
        el.textContent = template.replace("%{count}", selected.length)
      })
    }
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = this.visibleItems().length > 0
    }
    if (this.hasSelectAllTarget) {
      const visible = this.visibleBoxes()
      this.selectAllTarget.checked = visible.length > 0 && visible.every((box) => box.checked)
      this.selectAllTarget.indeterminate = !this.selectAllTarget.checked && visible.some((box) => box.checked)
    }
    if (this.hasSaveTarget) {
      this.saveTarget.disabled = selected.length === 0
    }
  }

  visibleItems() {
    return this.itemTargets.filter((el) => !el.hidden)
  }

  visibleBoxes() {
    return this.visibleItems().flatMap((el) => {
      return Array.from(el.querySelectorAll("input[name='page_ids[]'], input[name='instagram_ids[]']"))
    })
  }
}
