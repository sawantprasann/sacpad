// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Same confirmation block as the console flash dialog. A delete proceeds only
// after Confirm. Cancel, Escape, and the backdrop leave the record in place.
let confirmClose = null

function confirmDialog(message, options = {}) {
  const root = document.getElementById("confirm-dialog")
  if (!root) return Promise.resolve(options.alert ? true : window.confirm(message))
  if (confirmClose) confirmClose(false)

  const alertOnly = options.alert === true
  const title = root.querySelector("[data-confirm-title]")
  const body = root.querySelector("[data-confirm-message]")
  const accept = root.querySelector("[data-confirm-accept]")
  const cancel = root.querySelector("[data-confirm-cancel]")
  const ok = root.querySelector("[data-confirm-ok]")
  const backdrop = root.querySelector("[data-confirm-backdrop]")
  title.textContent = options.title || root.dataset.title
  body.textContent = message
  accept.textContent = options.acceptLabel || root.dataset.accept
  accept.hidden = alertOnly
  cancel.hidden = alertOnly
  ok.hidden = !alertOnly
  root.hidden = false
  ;(alertOnly ? ok : cancel).focus()

  return new Promise((resolve) => {
    const finish = (answer) => {
      if (confirmClose !== finish) return
      confirmClose = null
      root.hidden = true
      accept.removeEventListener("click", onAccept)
      cancel.removeEventListener("click", onCancel)
      ok.removeEventListener("click", onOk)
      backdrop.removeEventListener("click", onCancel)
      document.removeEventListener("keydown", onKey)
      resolve(answer)
    }
    const onAccept = () => finish(true)
    const onOk = () => finish(true)
    const onCancel = () => finish(alertOnly)
    const onKey = (event) => {
      if (event.key === "Escape") onCancel()
    }
    confirmClose = finish
    accept.addEventListener("click", onAccept)
    cancel.addEventListener("click", onCancel)
    ok.addEventListener("click", onOk)
    backdrop.addEventListener("click", onCancel)
    document.addEventListener("keydown", onKey)
  })
}

window.sacpadConfirm = confirmDialog
if (window.Turbo?.config?.forms) {
  window.Turbo.config.forms.confirm = (message) => confirmDialog(message)
}
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

      const text = String(Math.round(total))
      const size = text.length >= 7 ? 16 : text.length >= 6 ? 18 : text.length >= 5 ? 22 : 30
      const dark = document.body.classList.contains("dark")
      const ctx = chart.ctx
      ctx.save()
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillStyle = dark ? "#f9fafb" : "#101828"
      ctx.font = `700 ${size}px Outfit, sans-serif`
      ctx.fillText(text, arc.x, arc.y - 8)
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

// The election year swap replaces one frame. Keep the address bar in step
// without a page visit, then draw the donut if its script did not.
document.addEventListener("turbo:frame-load", (event) => {
  const frame = event.target
  if (!(frame instanceof HTMLElement) || frame.id !== "election-result") return

  const src = frame.getAttribute("src")
  if (src) {
    const next = new URL(src, window.location.href)
    const current = new URL(window.location.href)
    const sameAddress = next.pathname === current.pathname && next.search === current.search
    const history = window.Turbo?.session?.history
    if (!sameAddress && history?.replace) {
      history.replace(next)
      if (window.Turbo.session.view) window.Turbo.session.view.lastRenderedLocation = next
    }
  }

  frame.querySelectorAll("[id^='election-share-']").forEach((element) => {
    if (element.querySelector("canvas")) return
    const script = element.nextElementSibling
    if (!(script instanceof HTMLScriptElement)) return
    if (!script.textContent.includes("Chartkick")) return

    const fresh = document.createElement("script")
    fresh.textContent = script.textContent
    script.replaceWith(fresh)
  })
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
