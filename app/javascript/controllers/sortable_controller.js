import { Controller } from "@hotwired/stimulus"

// Drag-to-reorder. Each child <li> needs draggable="true" and data-id="...".
// On drop, PATCHes the new ordered ids array to data-sortable-url-value.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.draggedItem = null
    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover",  this.onDragOver)
    this.element.addEventListener("drop",      this.onDrop)
    this.element.addEventListener("dragend",   this.onDragEnd)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover",  this.onDragOver)
    this.element.removeEventListener("drop",      this.onDrop)
    this.element.removeEventListener("dragend",   this.onDragEnd)
  }

  onDragStart = (e) => {
    const li = e.target.closest("[data-id]")
    if (!li) return
    this.draggedItem = li
    li.classList.add("is-dragging")
    e.dataTransfer.effectAllowed = "move"
  }

  onDragOver = (e) => {
    e.preventDefault()
    const target = e.target.closest("[data-id]")
    if (!target || target === this.draggedItem) return
    const rect = target.getBoundingClientRect()
    const before = (e.clientY - rect.top) < rect.height / 2
    target.parentNode.insertBefore(this.draggedItem, before ? target : target.nextSibling)
  }

  onDrop = (e) => { e.preventDefault() }

  onDragEnd = () => {
    if (this.draggedItem) this.draggedItem.classList.remove("is-dragging")
    this.draggedItem = null
    this.persist()
  }

  persist() {
    const ids = Array.from(this.element.querySelectorAll("[data-id]")).map(el => el.dataset.id)
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrf,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ signup_ids: ids })
    })
      .then(r => r.text())
      .then(html => window.Turbo?.renderStreamMessage(html))
  }
}
