import { Controller } from "@hotwired/stimulus"

// Native <option> text cannot carry a colored dot. This keeps the <select>
// as the submitted field and draws the same dot beside each choice.
export default class extends Controller {
  static targets = [ "select", "ui", "toggle", "swatch", "label", "dropdown", "list" ]

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
    this.syncLabel()
  }

  disconnect() {
    this.selectTarget.removeEventListener("change", this.onSelectChange)
    this.unbindReposition()
  }

  toggle(event) {
    event.preventDefault()
    if (this.opened) this.closeMenu()
    else this.openMenu()
  }

  openMenu() {
    this.opened = true
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.activeIndex = Math.max(0, this.options.findIndex((option) => option.value === this.selectTarget.value))
    this.render()
    this.placeDropdown()
    this.dropdownTarget.hidden = false
    this.bindReposition()
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

  keydown(event) {
    const items = this.optionButtons()
    if (!this.opened && (event.key === "ArrowDown" || event.key === "Enter" || event.key === " ")) {
      event.preventDefault()
      this.openMenu()
      return
    }
    if (!this.opened) return

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
    } else if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      const item = items[this.activeIndex]
      if (!item) return
      this.commit(item.dataset.optionValue)
      this.closeMenu()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.closeMenu()
    }
  }

  commit(value) {
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  readOptions() {
    this.options = Array.from(this.selectTarget.options).map((option) => ({
      value: option.value,
      text: option.text,
      color: this.safeColor(option.dataset.color)
    }))
  }

  syncLabel() {
    const selected = this.options.find((option) => option.value === this.selectTarget.value) || this.options[0]
    const blank = !this.selectTarget.value
    this.labelTarget.textContent = selected?.text || ""
    this.labelTarget.classList.toggle("text-gray-800", !blank)
    this.labelTarget.classList.toggle("dark:text-white/90", !blank)
    this.labelTarget.classList.toggle("text-gray-400", blank)
    this.labelTarget.classList.toggle("dark:text-gray-500", blank)
    if (selected?.color && !blank) {
      this.swatchTarget.classList.remove("hidden")
      this.swatchTarget.style.background = selected.color
    } else {
      this.swatchTarget.classList.add("hidden")
      this.swatchTarget.style.background = ""
    }
  }

  render() {
    const selected = this.selectTarget.value
    const fragment = document.createDocumentFragment()
    this.options.forEach((option, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.optionValue = option.value
      button.setAttribute("role", "option")
      button.setAttribute("aria-selected", option.value === selected ? "true" : "false")
      button.className = "flex w-full cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-left text-sm text-gray-800 hover:bg-gray-100 focus:bg-gray-100 focus:outline-hidden dark:text-white/90 dark:hover:bg-white/5 dark:focus:bg-white/5"
      if (index === this.activeIndex) button.classList.add("bg-gray-100", "dark:bg-white/5")
      if (option.color) button.append(this.dot(option.color))
      const title = document.createElement("span")
      title.className = "min-w-0 flex-1 truncate"
      title.textContent = option.text
      button.append(title)
      fragment.append(button)
    })
    this.listTarget.replaceChildren(fragment)
  }

  dot(color) {
    const swatch = document.createElement("span")
    swatch.className = "h-2.5 w-2.5 shrink-0 rounded-full"
    swatch.style.background = color
    swatch.setAttribute("aria-hidden", "true")
    return swatch
  }

  safeColor(value) {
    return /^#[0-9a-fA-F]{6}$/.test(value || "") ? value : null
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
}
