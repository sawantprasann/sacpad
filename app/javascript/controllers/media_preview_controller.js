import { Controller } from "@hotwired/stimulus"

// One picker for photos or a single video. The file list is rebuilt so a
// removed preview is also removed from the upload.
export default class extends Controller {
  static targets = [ "input", "zone", "list", "message", "card" ]
  static values = { mixed: String, limit: String }

  connect() {
    this.files = []
    this.urls = []
  }

  disconnect() {
    this.revoke()
  }

  over(event) {
    event.preventDefault()
    this.zoneTarget.style.background = "#e4e6eb"
  }

  leave(event) {
    if (this.zoneTarget.contains(event.relatedTarget)) return
    this.resetZone()
  }

  drop(event) {
    event.preventDefault()
    this.resetZone()
    this.add(event.dataTransfer.files)
  }

  choose() {
    const picked = Array.from(this.inputTarget.files || [])
    if (this.sameFiles(picked, this.files)) return
    this.add(picked)
  }

  add(list) {
    const picked = Array.from(list || [])
    if (picked.length === 0) return
    this.apply(this.files.concat(picked))
  }

  sameFiles(left, right) {
    if (left.length !== right.length) return false
    return left.every((file, index) => {
      const other = right[index]
      return file === other || (file.name === other.name && file.size === other.size && file.lastModified === other.lastModified)
    })
  }

  remove(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    this.apply(this.files.filter((_, i) => i !== index))
  }

  apply(incoming) {
    const images = []
    const videos = []
    let other = false
    incoming.forEach((file) => {
      if (file.type.startsWith("image/")) images.push(file)
      else if (file.type.startsWith("video/")) videos.push(file)
      else other = true
    })

    if (other || (images.length && videos.length) || videos.length > 1) {
      this.messageTarget.textContent = this.mixedValue
      this.syncInput()
      return
    }

    if (images.length > 4) {
      this.messageTarget.textContent = this.limitValue
      this.files = images.slice(0, 4)
    } else {
      this.messageTarget.textContent = ""
      this.files = videos.length ? videos : images
    }
    this.syncInput()
    this.render()
  }

  syncInput() {
    const transfer = new DataTransfer()
    this.files.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
  }

  play(event) {
    const video = event.currentTarget
    if (video.paused) video.play()
    else video.pause()
  }

  render() {
    this.revoke()
    this.listTarget.querySelectorAll("[data-preview]").forEach((node) => node.remove())
    this.files.forEach((file, index) => {
      const node = this.cardTarget.content.firstElementChild.cloneNode(true)
      const url = URL.createObjectURL(file)
      this.urls.push(url)
      const image = node.querySelector("[data-slot=image]")
      const video = node.querySelector("[data-slot=video]")
      if (file.type.startsWith("video/")) {
        image.remove()
        video.src = url
        video.hidden = false
      } else {
        video.remove()
        image.src = url
        image.hidden = false
      }
      node.querySelector("button").dataset.index = String(index)
      this.zoneTarget.before(node)
    })
    const video = this.files.some((file) => file.type.startsWith("video/"))
    this.zoneTarget.hidden = video || this.files.length >= 4
  }

  resetZone() {
    this.zoneTarget.style.background = "#f0f2f5"
  }

  revoke() {
    this.urls.forEach((url) => URL.revokeObjectURL(url))
    this.urls = []
  }
}
