import { Controller } from "@hotwired/stimulus"

// Searchable select. The option list stays hidden until the query reaches
// minLength, same idea as Preline's "Minimum search length" advanced select.
// The native <select> is what the form submits.
export default class extends Controller {
  static targets = [ "select", "ui", "toggle", "label", "clear", "dropdown", "search", "hint", "list", "empty", "optionTemplate" ]
  static values = {
    minLength: { type: Number, default: 2 },
    placeholder: { type: String, default: "Select..." },
    emptyText: { type: String, default: "No options found" }
  }

  connect() {
    this.opened = false
    this.activeIndex = -1
    this.readOptions()

    this.selectTarget.classList.add("hidden")
    this.selectTarget.tabIndex = -1
    this.uiTarget.classList.remove("hidden")
    if (this.selectTarget.id) {
      this.toggleTarget.id = this.selectTarget.id
      this.selectTarget.removeAttribute("id")
    }

    this.onSelectChange = () => this.syncLabel()
    this.selectTarget.addEventListener("change", this.onSelectChange)
    this.observer = new MutationObserver(() => this.refreshOptions())
    this.observer.observe(this.selectTarget, { childList: true })
    this.syncLabel()
  }

  disconnect() {
    this.selectTarget.removeEventListener("change", this.onSelectChange)
    this.observer?.disconnect()
    this.unbindReposition()
  }

  toggle(event) {
    event.preventDefault()
    if (this.opened) {
      this.closeMenu()
    } else {
      this.openMenu()
    }
  }

  openMenu() {
    this.opened = true
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.searchTarget.value = ""
    this.activeIndex = -1
    this.render()
    this.placeDropdown()
    this.dropdownTarget.hidden = false
    this.bindReposition()
    this.searchTarget.focus()
  }

  closeMenu() {
    if (!this.opened) return

    this.opened = false
    this.dropdownTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.activeIndex = -1
    this.unbindReposition()
  }

  focusOut(event) {
    if (this.element.contains(event.relatedTarget)) return

    this.closeMenu()
  }

  clear(event) {
    event.preventDefault()
    event.stopPropagation()
    this.commit("")
    this.closeMenu()
  }

  keepFocus(event) {
    if (event.target.closest("[data-option-value]")) event.preventDefault()
  }

  choose(event) {
    const item = event.target.closest("[data-option-value]")
    if (!item || !this.listTarget.contains(item)) return

    this.commit(item.dataset.optionValue)
    this.closeMenu()
    this.toggleTarget.focus()
  }

  filter() {
    this.activeIndex = -1
    this.render()
  }

  searchKeydown(event) {
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
      event.preventDefault()
      const item = items[this.activeIndex]
      if (!item) return
      this.commit(item.dataset.optionValue)
      this.closeMenu()
      this.toggleTarget.focus()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.closeMenu()
      this.toggleTarget.focus()
    }
  }

  commit(value) {
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  readOptions() {
    this.options = Array.from(this.selectTarget.options).map((option) => ({
      value: option.value,
      text: option.text
    }))
  }

  refreshOptions() {
    this.readOptions()
    this.syncLabel()
    if (this.opened) this.render()
  }

  bindReposition() {
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

  // Fixed positioning so the menu is not clipped by overflow:hidden parents.
  placeDropdown() {
    const rect = this.toggleTarget.getBoundingClientRect()
    const dropdown = this.dropdownTarget
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

  syncLabel() {
    const selected = this.selectTarget.selectedOptions[0]
    const blank = this.selectTarget.value === ""
    this.labelTarget.textContent = blank ? this.placeholderValue : (selected?.text || this.placeholderValue)
    this.labelTarget.classList.toggle("text-gray-800", !blank)
    this.labelTarget.classList.toggle("dark:text-white/90", !blank)
    this.labelTarget.classList.toggle("text-gray-400", blank)
    this.labelTarget.classList.toggle("dark:text-gray-500", blank)
    if (this.hasClearTarget) this.clearTarget.classList.toggle("hidden", blank)
  }

  render() {
    const query = this.searchTarget.value.trim().toLowerCase()
    const ready = query.length >= this.minLengthValue
    const visible = ready ? this.matches(query) : this.pinnedOptions()
    const selected = this.selectTarget.value

    this.hintTarget.classList.toggle("hidden", ready)
    this.hintTarget.textContent = `Please enter ${this.minLengthValue} or more characters`
    this.emptyTarget.textContent = this.emptyTextValue
    this.emptyTarget.classList.toggle("hidden", !(ready && visible.length === 0))

    const fragment = document.createDocumentFragment()
    visible.forEach((option) => {
      const button = this.optionTemplateTarget.content.firstElementChild.cloneNode(true)
      button.dataset.optionValue = option.value
      button.setAttribute("aria-selected", option.value === selected ? "true" : "false")
      button.querySelector("[data-title]").textContent = option.text
      button.classList.remove("bg-gray-100", "dark:bg-white/5", "font-medium")
      if (option.value === selected && option.value !== "") button.classList.add("font-medium")
      const check = button.querySelector("[data-check]")
      check.classList.toggle("hidden", option.value !== selected || option.value === "")
      fragment.append(button)
    })
    this.listTarget.replaceChildren(fragment)
  }

  matches(query) {
    const matched = this.options.filter((option) => option.text.toLowerCase().includes(query))
    const starts = []
    const rest = []
    matched.forEach((option) => {
      if (option.text.toLowerCase().startsWith(query)) starts.push(option)
      else rest.push(option)
    })
    return starts.concat(rest)
  }

  pinnedOptions() {
    const selected = this.selectTarget.value
    return this.options.filter((option) => {
      if (option.value === "") return true
      if (option.value === selected) return true
      const length = option.text.trim().length
      return length > 0 && length < this.minLengthValue
    })
  }

  optionButtons() {
    return Array.from(this.listTarget.querySelectorAll("[data-option-value]"))
  }

  applyActive(items) {
    items.forEach((item, index) => {
      const active = index === this.activeIndex
      item.classList.toggle("bg-gray-100", active)
      item.classList.toggle("dark:bg-white/5", active)
      if (active) item.scrollIntoView({ block: "nearest" })
    })
  }
}
