import { Controller } from "@hotwired/stimulus"

// District narrows talukas, and district or taluka narrows villages.
export default class extends Controller {
  static targets = ["district", "taluka", "village"]

  connect() {
    this.talukaOptions = this.capture(this.talukaTarget)
    this.villageOptions = this.capture(this.villageTarget)
    this.apply()
  }

  districtChanged() {
    this.talukaTarget.value = ""
    this.villageTarget.value = ""
    this.apply()
  }

  talukaChanged() {
    this.villageTarget.value = ""
    this.apply()
  }

  apply() {
    const districtId = this.districtTarget.value
    this.render(
      this.talukaTarget,
      this.talukaOptions.filter((option) => this.matchesTaluka(option, districtId)),
      this.talukaTarget.value
    )

    const talukaId = this.talukaTarget.value
    this.render(
      this.villageTarget,
      this.villageOptions.filter((option) => this.matchesVillage(option, districtId, talukaId)),
      this.villageTarget.value
    )
  }

  capture(select) {
    return Array.from(select.options).map((option) => ({
      value: option.value,
      text: option.text,
      districtId: option.dataset.districtId || "",
      talukaId: option.dataset.talukaId || ""
    }))
  }

  render(select, options, selectedValue) {
    select.replaceChildren()
    options.forEach((option) => {
      const element = document.createElement("option")
      element.value = option.value
      element.textContent = option.text
      if (option.districtId) element.dataset.districtId = option.districtId
      if (option.talukaId) element.dataset.talukaId = option.talukaId
      if (option.value === selectedValue) element.selected = true
      select.append(element)
    })
  }

  matchesTaluka(option, districtId) {
    if (option.value === "") return true
    if (districtId === "") return true
    return option.districtId === districtId
  }

  matchesVillage(option, districtId, talukaId) {
    if (option.value === "") return true
    if (talukaId !== "") return option.talukaId === talukaId
    if (districtId !== "") return option.districtId === districtId
    return true
  }
}
