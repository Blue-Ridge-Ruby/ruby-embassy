require "test_helper"

class MealSpotTransportTest < ActiveSupport::TestCase
  def setup
    @meal = ScheduleItem.create!(day: "thu", title: "Dinner", kind: :meal, is_public: true)
    @spot = @meal.meal_spots.create!(name: "Pinewood", created_by: users(:attendee_one))
  end

  test "mode is unique per spot — only one walking group, one driving group, etc." do
    @spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    dup = @spot.transports.build(mode: :walking, departs_at: 2.hours.from_now)
    assert_not dup.valid?
    assert_includes dup.errors[:mode], "has already been taken"
  end

  test "departs_at is required" do
    transport = @spot.transports.build(mode: :walking)
    assert_not transport.valid?
    assert_includes transport.errors[:departs_at], "can't be blank"
  end

  test "different modes can coexist on the same spot" do
    @spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    driver = @spot.transports.build(mode: :driving, departs_at: 1.hour.from_now + 15.minutes, seats_offered: 3)
    assert driver.valid?
  end

  test "driving requires seats_offered (>= 0)" do
    transport = @spot.transports.build(mode: :driving, departs_at: 1.hour.from_now)
    assert_not transport.valid?
    assert_includes transport.errors[:seats_offered], "can't be blank"

    transport.seats_offered = -1
    assert_not transport.valid?

    transport.seats_offered = 0
    assert transport.valid?, "0 seats means 'driving solo' and is allowed"
  end

  test "walking ignores seats_offered" do
    transport = @spot.transports.build(mode: :walking, departs_at: 1.hour.from_now)
    assert transport.valid?
  end

  test "started_by? identifies the first RSVPer as organizer" do
    transport = @spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: users(:attendee_one))
    transport.rsvps.create!(user: users(:volunteer_one))

    assert transport.started_by?(users(:attendee_one))
    assert_not transport.started_by?(users(:volunteer_one))
    assert_not transport.started_by?(nil)
  end

  test "meet_up_spot is optional and round-trips" do
    transport = @spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    assert_nil transport.reload.meet_up_spot, "default is nil"

    transport.update!(meet_up_spot: "hotel lobby")
    assert_equal "hotel lobby", transport.reload.meet_up_spot
  end

  test "passenger_count and full? track car capacity" do
    transport = @spot.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 2)
    transport.rsvps.create!(user: users(:attendee_one)) # driver
    assert_equal 0, transport.passenger_count
    assert_not transport.full?

    transport.rsvps.create!(user: users(:volunteer_one)) # passenger 1
    assert_equal 1, transport.passenger_count
    assert_not transport.full?

    transport.rsvps.create!(user: users(:jeremy)) # passenger 2 — fills the car
    assert_equal 2, transport.passenger_count
    assert transport.full?
  end
end
