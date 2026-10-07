// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

// Alpine powers TailAdmin's shell interactions (sidebar toggle, dropdowns, dark mode,
// password visibility). Started after Turbo loads so it re-initializes on Turbo navigations.
import Alpine from "alpinejs"
window.Alpine = Alpine
document.addEventListener("turbo:load", () => {
  if (!window.__alpineStarted) { Alpine.start(); window.__alpineStarted = true }
})

// A click on the field itself only focuses the date segments. Open the calendar
// from that same click. Already-open pickers throw; leave them open.
document.addEventListener("click", (event) => {
  const input = event.target
  if (!(input instanceof HTMLInputElement)) return
  if (input.type !== "date" && input.type !== "time") return
  if (input.disabled || input.readOnly) return
  if (typeof input.showPicker !== "function") return

  try {
    input.showPicker()
  } catch (_error) {
    // The picker is already open, or this click was not a user gesture.
  }
})
