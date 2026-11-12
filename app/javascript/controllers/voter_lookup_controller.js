import { Controller } from "@hotwired/stimulus"

// Village first, then a debounced name search. Nothing is fetched until the
// query reaches minLength, and each response is capped by the server.
export default class extends Controller {
  static targets = [ "village", "query", "voterId", "anchor", "results", "status", "optionTemplate", "messageTemplate" ]
  static values = {
    url: String,
    minLength: { type: Number, default: 2 },
    delay: { type: Number, default: 300 },
    hint: String,
    pickVillage: String,
    empty: String,
    narrow: String,
    picked: String,
    searching: String,
    failed: String
  }

  connect() {
    this.timer = null
    this.abortController = null
    this.activeIndex = -1
    this.syncVillage()
    if (this.voterIdTarget.value && this.queryTarget.value) {
      this.statusTarget.textContent = this.fill(this.pickedValue, { name: this.queryTarget.value })
    } else if (this.hasVillageSelected()) {
      this.statusTarget.textContent = this.fill(this.hintValue, { count: this.minLengthValue })
    }
  }

  disconnect() {
    clearTimeout(this.timer)
    this.abortController?.abort()
    this.unbindReposition()
  }

  villageChanged() {
    clearTimeout(this.timer)
    this.abortController?.abort()
    this.voterIdTarget.value = ""
    this.queryTarget.value = ""
    this.clearResults()
    this.syncVillage()
    if (this.hasVillageSelected()) {
      this.statusTarget.textContent = this.fill(this.hintValue, { count: this.minLengthValue })
    }
  }

  search() {
    this.voterIdTarget.value = ""
    clearTimeout(this.timer)
    const query = this.queryTarget.value.trim()
    if (!this.hasVillageSelected()) {
      this.clearResults()
      this.statusTarget.textContent = this.pickVillageValue
      return
    }
    if (query.length < this.minLengthValue) {
      this.clearResults()
      this.statusTarget.textContent = this.fill(this.hintValue, { count: this.minLengthValue })
      return
    }

    this.statusTarget.textContent = ""
    this.timer = setTimeout(() => {
      this.showMessage(this.searchingValue)
      this.fetchVoters()
    }, this.delayValue)
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.clearResults()
      return
    }
    if (this.resultsTarget.hidden) return

    const items = this.optionButtons()
    if (event.key === "ArrowDown") {
      event.preventDefault()
      if (!items.length) return
      this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
      this.applyActive(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      if (!items.length) return
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.applyActive(items)
    } else if (event.key === "Enter") {
      const button = items[this.activeIndex] || items[0]
      if (!button) return
      event.preventDefault()
      this.applyChoice(button)
    }
  }

  focusOut(event) {
    if (this.anchorTarget.contains(event.relatedTarget)) return

    this.clearResults()
  }

  keepFocus(event) {
    if (event.target.closest("button[data-voter-id]")) event.preventDefault()
  }

  choose(event) {
    const button = event.target.closest("button[data-voter-id]")
    if (!button || !this.resultsTarget.contains(button)) return

    this.applyChoice(button)
  }

  async fetchVoters() {
    const village = this.villageTarget.value
    const query = this.queryTarget.value.trim()
    if (!village || query.length < this.minLengthValue) return

    this.abortController?.abort()
    this.abortController = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("village", village)
    url.searchParams.set("q", query)

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })
      if (!response.ok) throw new Error("search failed")

      const data = await response.json()
      if (this.villageTarget.value !== village || this.queryTarget.value.trim() !== query) return

      this.render(data.voters || [], data.truncated)
    } catch (error) {
      if (error.name === "AbortError") return

      this.clearResults()
      this.statusTarget.textContent = this.failedValue
    }
  }

  render(voters, truncated) {
    this.resultsTarget.replaceChildren()
    this.activeIndex = -1
    if (!voters.length) {
      this.showMessage(this.emptyValue)
      return
    }

    voters.forEach((voter) => {
      const button = this.optionTemplateTarget.content.firstElementChild.cloneNode(true)
      button.classList.remove("bg-gray-100", "dark:bg-white/5")
      const shownName = voter.label || voter.name
      button.dataset.voterId = voter.id
      button.dataset.voterName = shownName
      button.querySelector("[data-title]").textContent = shownName
      this.resultsTarget.append(button)
    })

    if (truncated) {
      const note = this.messageTemplateTarget.content.firstElementChild.cloneNode(true)
      note.classList.add("text-xs")
      note.textContent = this.fill(this.narrowValue, { count: voters.length })
      this.resultsTarget.append(note)
    }

    this.openMenu()
    this.statusTarget.textContent = ""
  }

  showMessage(text) {
    const note = this.messageTemplateTarget.content.firstElementChild.cloneNode(true)
    note.textContent = text
    this.resultsTarget.replaceChildren(note)
    this.openMenu()
  }

  openMenu() {
    this.resultsTarget.hidden = false
    this.queryTarget.setAttribute("aria-expanded", "true")
    this.placeDropdown()
    this.bindReposition()
  }

  placeDropdown() {
    const rect = this.queryTarget.getBoundingClientRect()
    const dropdown = this.resultsTarget
    const gap = 8
    const maxHeight = 288
    const spaceBelow = window.innerHeight - rect.bottom
    const spaceAbove = rect.top
    const openUp = spaceBelow < Math.min(maxHeight, 220) && spaceAbove > spaceBelow

    dropdown.style.position = "fixed"
    dropdown.style.left = `${Math.max(8, rect.left)}px`
    dropdown.style.width = `${rect.width}px`
    dropdown.style.right = "auto"
    dropdown.style.marginTop = "0"
    if (openUp) {
      dropdown.style.top = "auto"
      dropdown.style.bottom = `${window.innerHeight - rect.top + gap}px`
      dropdown.style.maxHeight = `${Math.max(160, spaceAbove - gap - 8)}px`
    } else {
      dropdown.style.bottom = "auto"
      dropdown.style.top = `${rect.bottom + gap}px`
      dropdown.style.maxHeight = `${Math.max(160, Math.min(maxHeight, spaceBelow - gap - 8))}px`
    }
  }

  bindReposition() {
    if (this.onReposition) return

    this.onReposition = () => this.placeDropdown()
    window.addEventListener("scroll", this.onReposition, true)
    window.addEventListener("resize", this.onReposition)
  }

  unbindReposition() {
    if (!this.onReposition) return

    window.removeEventListener("scroll", this.onReposition, true)
    window.removeEventListener("resize", this.onReposition)
    this.onReposition = null
  }

  optionButtons() {
    return Array.from(this.resultsTarget.querySelectorAll("button[data-voter-id]"))
  }

  applyActive(items) {
    items.forEach((item, index) => {
      const active = index === this.activeIndex
      item.classList.toggle("bg-gray-100", active)
      item.classList.toggle("dark:bg-white/5", active)
      if (active) item.scrollIntoView({ block: "nearest" })
    })
  }

  applyChoice(button) {
    this.voterIdTarget.value = button.dataset.voterId
    this.queryTarget.value = button.dataset.voterName
    this.clearResults()
    this.statusTarget.textContent = this.fill(this.pickedValue, { name: button.dataset.voterName })
  }

  syncVillage() {
    const ready = this.hasVillageSelected()
    this.queryTarget.disabled = !ready
    if (!ready) this.statusTarget.textContent = this.pickVillageValue
  }

  hasVillageSelected() {
    return this.villageTarget.value !== ""
  }

  clearResults() {
    this.resultsTarget.replaceChildren()
    this.resultsTarget.hidden = true
    this.queryTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
    this.unbindReposition()
  }

  fill(template, values) {
    return template.replace(/%\{(\w+)\}/g, (_, key) => values[key] ?? "")
  }
}
