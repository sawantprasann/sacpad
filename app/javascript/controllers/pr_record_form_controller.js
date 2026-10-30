import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "category", "platform", "platformWrap", "platformLabel", "links", "linkRows", "linkTemplate", "outdoor" ]
  static values = {
    thumbnailUrl: String,
    newspaper: String,
    tvChannel: String,
    checking: String,
    noThumbnail: String,
    thumbnailFilled: String
  }

  connect() {
    this.applyCategory()
  }

  applyCategory() {
    const slug = this.categoryTarget.selectedOptions[0]?.dataset.slug || ""
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

  addLink(event) {
    event.preventDefault()
    const html = this.linkTemplateTarget.innerHTML.replaceAll("__INDEX__", Date.now().toString())
    this.linkRowsTarget.insertAdjacentHTML("beforeend", html)
  }

  removeLink(event) {
    event.preventDefault()
    const row = event.target.closest("[data-link-row]")
    const destroy = row.querySelector("[data-link-destroy]")
    if (destroy) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row.remove()
    }
  }

  async fetchThumbnail(event) {
    event.preventDefault()
    const row = event.target.closest("[data-link-row]")
    const status = row.querySelector("[data-link-status]")
    const url = row.querySelector("[data-link-url]").value
    status.textContent = this.checkingValue
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.thumbnailUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ url })
    })
    const data = await response.json()
    if (!response.ok) {
      status.textContent = data.error || this.noThumbnailValue
      return
    }
    row.querySelector("[data-link-thumb]").value = data.thumbnail_url
    status.textContent = this.thumbnailFilledValue
  }
}
