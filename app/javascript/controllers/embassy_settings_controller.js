import { Controller } from "@hotwired/stimulus"

// Toggles visibility of kind-specific settings panels (embassy and volunteer)
// on the admin schedule-item form, plus per-mode capacity inputs that show
// only when their mode checkbox is checked.
export default class extends Controller {
  static targets = [
    "kindSelect", "extras", "volunteerExtras",
    "newPassportToggle", "stampingToggle", "passportPickupToggle",
    "newPassportCapacity", "stampingCapacity", "passportPickupCapacity"
  ]

  connect() {
    this.toggle()
    this.syncAllCapacities()
  }

  toggle() {
    if (!this.hasKindSelectTarget) return
    const kind = this.kindSelectTarget.value
    if (this.hasExtrasTarget) this.extrasTarget.hidden = kind !== "embassy"
    if (this.hasVolunteerExtrasTarget) this.volunteerExtrasTarget.hidden = kind !== "volunteer"
  }

  toggleCapacity(event) {
    const map = {
      newPassportToggle: "newPassportCapacity",
      stampingToggle: "stampingCapacity",
      passportPickupToggle: "passportPickupCapacity"
    }
    const targetName = Object.entries(map).find(([toggle]) =>
      this[`has${this.cap(toggle)}Target`] && this[`${toggle}Target`] === event.target
    )?.[1]
    if (!targetName) return
    const wrapper = this[`${targetName}Target`]
    if (wrapper) wrapper.hidden = !event.target.checked
  }

  syncAllCapacities() {
    const pairs = [
      ["newPassportToggle", "newPassportCapacity"],
      ["stampingToggle", "stampingCapacity"],
      ["passportPickupToggle", "passportPickupCapacity"]
    ]
    pairs.forEach(([toggle, capacity]) => {
      const hasToggle = this[`has${this.cap(toggle)}Target`]
      const hasCap = this[`has${this.cap(capacity)}Target`]
      if (hasToggle && hasCap) {
        this[`${capacity}Target`].hidden = !this[`${toggle}Target`].checked
      }
    })
  }

  cap(s) { return s.charAt(0).toUpperCase() + s.slice(1) }
}
