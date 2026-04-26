import { Controller } from "@hotwired/stimulus"

// Toggles visibility of the embassy-only settings (capacity, mode) on the
// admin schedule-item form based on the kind dropdown.
export default class extends Controller {
  static targets = ["kindSelect", "extras"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasExtrasTarget || !this.hasKindSelectTarget) return
    const isEmbassy = this.kindSelectTarget.value === "embassy"
    this.extrasTarget.hidden = !isEmbassy
  }
}
