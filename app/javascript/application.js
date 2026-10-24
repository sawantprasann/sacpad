// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

// Dashboard donuts keep names off the ring. The total sits in the hole. Slice
// names are arrows under the chart, each in that slice's color. Opt in with
// plugins.pieSliceLabels.
if (window.Chart?.register) {
  window.Chart.register({
    id: "pieSliceLabels",
    beforeUpdate(chart) {
      if (!chart.options.plugins?.pieSliceLabels) return
      const dataset = chart.data.datasets?.[0]
      if (!dataset) return
      dataset.spacing = 6
      dataset.borderRadius = 10
      dataset.borderWidth = 0
      dataset.hoverOffset = 10
    },
    afterDatasetsDraw(chart) {
      if (!chart.options.plugins?.pieSliceLabels) return

      const meta = chart.getDatasetMeta(0)
      const dataset = chart.data.datasets?.[0]
      const arc = meta?.data?.[0]
      if (!arc || !dataset || arc.innerRadius < 34) return

      const total = dataset.data.reduce((sum, value) => sum + Number(value || 0), 0)
      if (!total) return

      const dark = document.body.classList.contains("dark")
      const ctx = chart.ctx
      ctx.save()
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillStyle = dark ? "#f9fafb" : "#101828"
      ctx.font = "700 30px Outfit, sans-serif"
      ctx.fillText(String(total), arc.x, arc.y - 8)
      ctx.fillStyle = dark ? "#98a2b3" : "#667085"
      ctx.font = "600 11px Outfit, sans-serif"
      ctx.fillText("Total", arc.x, arc.y + 14)
      ctx.restore()
    }
  })
}

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
