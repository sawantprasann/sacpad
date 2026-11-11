import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "category", "platform", "platformWrap", "platformLabel", "links", "outdoor", "title" ]
  static values = { newspaper: String, tvChannel: String, placeholder: String }

  connect() {
    this.applyCategory()
  }

  applyCategory() {
    const selected = this.categoryTarget.selectedOptions[0]
    const slug = selected?.value ? (selected.dataset.slug || "") : ""
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = selected?.value ? selected.textContent.trim() : this.placeholderValue
    }
    const platformSlugs = [ "electronic", "print", "local-print", "local-electronic" ]
    const linkSlugs = [ "electronic", "local-electronic", "podcasts" ]
    const showPlatform = platformSlugs.includes(slug)
    this.platformWrapTarget.hidden = !showPlatform
    this.linksTarget.hidden = !linkSlugs.includes(slug)
    this.outdoorTarget.hidden = slug !== "outdoor-media"
    this.platformLabelTarget.textContent = (slug === "print" || slug === "local-print") ? this.newspaperValue : this.tvChannelValue
    const current = this.platformTarget.value
    this.platformTarget.querySelectorAll("option").forEach((option) => {
      if (!option.value) return
      const match = option.dataset.category === slug
      const keep = option.value === current
      option.hidden = !(match || keep)
      option.disabled = !(match || keep)
    })
    if (this.platformTarget.selectedOptions[0]?.disabled) this.platformTarget.value = ""
  }
}
