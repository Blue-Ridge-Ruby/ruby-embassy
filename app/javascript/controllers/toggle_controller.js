import { Controller } from "@hotwired/stimulus"

/*
 * Generic toggle controller — matches the Bridgetown pattern.
 *
 * Usage:
 *   <div data-controller="toggle" data-toggle-toggle-class="hidden">
 *     <button data-action="click->toggle#toggle click@window->toggle#hide">...</button>
 *     <div data-toggle-target="toggleable" class="hidden">...</div>
 *   </div>
 *
 * - #toggle flips the configured class on the toggleable target.
 * - #hide re-applies the class (closes the panel). It's bound to
 *   click@window so clicks outside close the menu; the event is
 *   ignored if the click came from inside this controller's element
 *   (so tapping the button doesn't immediately close what it opened).
 */
export default class extends Controller {
  static targets = ["toggleable"]
  static values = { toggleClass: { type: String, default: "hidden" } }

  toggle(event) {
    event?.stopPropagation()
    this.toggleableTarget.classList.toggle(this.toggleClassValue)
  }

  hide(event) {
    if (event && this.element.contains(event.target)) return
    this.toggleableTarget.classList.add(this.toggleClassValue)
  }
}
