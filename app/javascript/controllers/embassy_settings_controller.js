import { Controller } from "@hotwired/stimulus"

// Toggles visibility of kind-specific settings panels (embassy and volunteer)
// on the admin schedule-item form based on the kind dropdown.
export default class extends Controller {
  static targets = ["kindSelect", "extras", "volunteerExtras"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasKindSelectTarget) return
    const kind = this.kindSelectTarget.value
    if (this.hasExtrasTarget) this.extrasTarget.hidden = kind !== "embassy"
    if (this.hasVolunteerExtrasTarget) this.volunteerExtrasTarget.hidden = kind !== "volunteer"
  }
}
