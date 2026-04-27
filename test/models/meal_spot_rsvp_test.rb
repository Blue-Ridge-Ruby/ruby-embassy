require "test_helper"

class MealSpotRsvpTest < ActiveSupport::TestCase
  def setup
    @meal = ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
    @spot_a = @meal.meal_spots.create!(name: "Hattie B's", created_by: users(:attendee_one))
    @spot_b = @meal.meal_spots.create!(name: "Pinewood",   created_by: users(:attendee_one))
    @walking_a = @spot_a.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    @driving_b = @spot_b.transports.create!(mode: :driving, departs_at: 1.hour.from_now + 15.minutes, seats_offered: 3)
  end

  test "schedule_item is denormalized from the transport's spot" do
    rsvp = @walking_a.rsvps.create!(user: users(:attendee_one))
    assert_equal @meal.id, rsvp.schedule_item_id
  end

  test "joining a spot also creates a parent PlanItem" do
    assert_difference -> { PlanItem.where(user: users(:volunteer_one), schedule_item: @meal).count }, +1 do
      @walking_a.rsvps.create!(user: users(:volunteer_one))
    end
  end

  test "a user can only RSVP to one spot per meal" do
    @walking_a.rsvps.create!(user: users(:attendee_one))
    dup = @driving_b.rsvps.build(user: users(:attendee_one))
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "is already going to a spot for this meal"
  end

  test "joining a full car is rejected" do
    full_car = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 1)
    full_car.rsvps.create!(user: users(:attendee_one)) # driver
    full_car.rsvps.create!(user: users(:volunteer_one)) # the one passenger seat
    assert full_car.full?

    third = full_car.rsvps.build(user: users(:jeremy))
    assert_not third.valid?
    assert_includes third.errors[:base], "this car is already full"
  end

  test "a solo driver (0 seats) blocks all joiners" do
    solo = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 0)
    solo.rsvps.create!(user: users(:attendee_one)) # driver, alone
    assert solo.full?

    second = solo.rsvps.build(user: users(:volunteer_one))
    assert_not second.valid?
  end

  test "the same user can RSVP to spots for different meals" do
    other_meal = ScheduleItem.create!(day: "fri", title: "Lunch 2", kind: :meal, is_public: true)
    other_spot = other_meal.meal_spots.create!(name: "Anywhere", created_by: users(:attendee_one))
    other_transport = other_spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)

    @walking_a.rsvps.create!(user: users(:attendee_one))
    second = other_transport.rsvps.build(user: users(:attendee_one))
    assert second.valid?
  end

  # ----- locked_in? -------------------------------------------------------

  test "locked_in? is true for the driver of a driving transport, even solo" do
    drive = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    rsvp = drive.rsvps.create!(user: users(:attendee_one)) # solo driver
    assert rsvp.locked_in?, "solo driver is locked in by their offer to host"
    assert_match(/host this ride/i, rsvp.lock_reason)
  end

  test "locked_in? is true for the driver even with passengers" do
    drive = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    driver_rsvp = drive.rsvps.create!(user: users(:attendee_one))
    drive.rsvps.create!(user: users(:volunteer_one)) # passenger
    assert driver_rsvp.locked_in?
  end

  test "locked_in? is false for a passenger of a driving transport" do
    drive = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    drive.rsvps.create!(user: users(:attendee_one)) # driver
    passenger_rsvp = drive.rsvps.create!(user: users(:volunteer_one))
    assert_not passenger_rsvp.locked_in?, "passengers can leave freely"
    assert_nil passenger_rsvp.lock_reason
  end

  test "locked_in? is false for a solo walking organizer" do
    rsvp = @walking_a.rsvps.create!(user: users(:attendee_one)) # solo walker
    assert_not rsvp.locked_in?, "solo walking has no rug-pull risk"
  end

  test "locked_in? is true for a walking organizer with others (rug-pull)" do
    organizer_rsvp = @walking_a.rsvps.create!(user: users(:attendee_one))
    @walking_a.rsvps.create!(user: users(:volunteer_one))
    assert organizer_rsvp.locked_in?
    assert_match(/started this transport group/, organizer_rsvp.lock_reason)
  end
end
