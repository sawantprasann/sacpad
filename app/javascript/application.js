// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Alpine powers TailAdmin's shell interactions (sidebar toggle, dropdowns, dark mode,
// password visibility). Started after Turbo loads so it re-initializes on Turbo navigations.
import Alpine from "alpinejs"
window.Alpine = Alpine
document.addEventListener("turbo:load", () => {
  if (!window.__alpineStarted) { Alpine.start(); window.__alpineStarted = true }
})
