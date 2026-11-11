import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "item" ]

  filter() {
    const query = this.inputTarget.value.toLowerCase()
    this.itemTargets.forEach((el) => {
      el.hidden = !el.dataset.name.toLowerCase().includes(query)
    })
  }

  selectAll(event) {
    this.itemTargets.filter((el) => !el.hidden).forEach((el) => {
      el.querySelectorAll("input[type=checkbox][name='page_ids[]'], input[type=checkbox][name='instagram_ids[]']").forEach((box) => {
        box.checked = event.target.checked
      })
    })
  }
}
