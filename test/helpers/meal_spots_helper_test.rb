require "test_helper"

class MealSpotsHelperTest < ActionView::TestCase
  setup do
    @meal      = ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
    @host      = users(:attendee_one)
    @spot      = @meal.meal_spots.create!(name: "Pinewood", created_by: @host)
    @walking   = @spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    @driving   = @spot.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 2)
    @walker    = users(:volunteer_one)
    @walker_rsvp = @walking.rsvps.create!(user: @walker, contact_method: "555-walker")
    @driver_rsvp = @driving.rsvps.create!(user: users(:jeremy), contact_method: "555-driver")
  end

  test "host sees contacts on every transport at their spot" do
    assert can_see_meal_contact?(@host, @walker_rsvp)
    assert can_see_meal_contact?(@host, @driver_rsvp)
  end

  test "RSVP owner always sees their own contact" do
    assert can_see_meal_contact?(@walker, @walker_rsvp)
  end

  test "same-transport peer sees the contact" do
    other_walker = @walking.rsvps.create!(user: users(:katya), contact_method: "555-katya")
    assert can_see_meal_contact?(@walker, other_walker)
  end

  test "different-transport peer at the same spot does not see the contact" do
    assert_not can_see_meal_contact?(@walker, @driver_rsvp)
  end

  test "random user with no RSVP at this spot does not see the contact" do
    stranger = users(:katya)
    assert_not can_see_meal_contact?(stranger, @walker_rsvp)
  end

  test "nil viewer or rsvp returns false" do
    assert_not can_see_meal_contact?(nil, @walker_rsvp)
    assert_not can_see_meal_contact?(@host, nil)
  end
end
