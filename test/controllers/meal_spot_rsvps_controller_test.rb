require "test_helper"

class MealSpotRsvpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @meal      = ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
    @spot_a    = @meal.meal_spots.create!(name: "Hattie B's", created_by: users(:attendee_one))
    @spot_b    = @meal.meal_spots.create!(name: "Pinewood",   created_by: users(:attendee_one))
    @walking_a = @spot_a.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    @driving_b = @spot_b.transports.create!(mode: :driving, departs_at: 1.hour.from_now + 15.minutes, seats_offered: 3)
  end

  test "POST joins an existing transport" do
    sign_in_as users(:volunteer_one)
    assert_difference -> { MealSpotRsvp.count }, 1 do
      post schedule_item_meal_spot_rsvps_path(@meal, @spot_a, transport_id: @walking_a.id)
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
  end

  test "POST creates a new transport when given mode + departs_at" do
    sign_in_as users(:volunteer_one)
    assert_difference [ "MealSpotTransport.count", "MealSpotRsvp.count" ], 1 do
      post schedule_item_meal_spot_rsvps_path(@meal, @spot_a),
           params: { mode: "driving", departs_at: 90.minutes.from_now, seats_offered: 2 }
    end
  end

  test "POST persists meet_up_spot on a newly-created transport" do
    sign_in_as users(:volunteer_one)
    post schedule_item_meal_spot_rsvps_path(@meal, @spot_a),
         params: { mode: "driving", departs_at: 90.minutes.from_now, seats_offered: 2,
                   meet_up_spot: "south parking lot" }

    new_transport = @spot_a.transports.find_by(mode: :driving)
    assert_equal "south parking lot", new_transport.meet_up_spot
  end

  test "POST does NOT let the driver switch to walking — driving offer locks them in" do
    sign_in_as users(:volunteer_one)
    drive_t = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    drive_t.rsvps.create!(user: users(:volunteer_one)) # they're the driver/organizer

    # @walking_a already exists at @spot_a from setup
    post schedule_item_meal_spot_rsvps_path(@meal, @spot_a, transport_id: @walking_a.id)
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/host this ride/i, flash[:alert])

    rsvp = MealSpotRsvp.find_by!(user: users(:volunteer_one), schedule_item: @meal)
    assert_equal drive_t.id, rsvp.meal_spot_transport_id, "driver stayed on the driving transport"
  end

  test "POST switches the user from one spot to another in a single request" do
    sign_in_as users(:volunteer_one)
    @walking_a.rsvps.create!(user: users(:volunteer_one))

    assert_no_difference -> { MealSpotRsvp.where(user: users(:volunteer_one), schedule_item: @meal).count } do
      post schedule_item_meal_spot_rsvps_path(@meal, @spot_b, transport_id: @driving_b.id)
    end
    rsvp = MealSpotRsvp.find_by!(user: users(:volunteer_one), schedule_item: @meal)
    assert_equal @spot_b, rsvp.meal_spot
  end

  test "DELETE removes the caller's own RSVP when they're not the organizer" do
    sign_in_as users(:volunteer_one)
    @walking_a.rsvps.create!(user: users(:attendee_one)) # organizer
    rsvp = @walking_a.rsvps.create!(user: users(:volunteer_one)) # passenger
    assert_difference -> { MealSpotRsvp.count }, -1 do
      delete schedule_item_meal_spot_rsvp_path(@meal, @spot_a, rsvp)
    end
  end

  test "DELETE blocked when walking organizer has passengers (rug-pull guard)" do
    sign_in_as users(:volunteer_one)
    organizer_rsvp = @walking_a.rsvps.create!(user: users(:volunteer_one)) # first = organizer
    @walking_a.rsvps.create!(user: users(:attendee_one)) # passenger joined later
    assert_no_difference -> { MealSpotRsvp.count } do
      delete schedule_item_meal_spot_rsvp_path(@meal, @spot_a, organizer_rsvp)
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/started this transport group/, flash[:alert])
  end

  test "DELETE blocked for solo driver — driving offer is a commitment to future RSVPs" do
    sign_in_as users(:volunteer_one)
    drive_t = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    rsvp = drive_t.rsvps.create!(user: users(:volunteer_one)) # solo driver
    assert_no_difference -> { MealSpotRsvp.count } do
      delete schedule_item_meal_spot_rsvp_path(@meal, @spot_a, rsvp)
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/host this ride/i, flash[:alert])
  end

  test "DELETE allowed when solo walker — walking has no rug-pull risk solo" do
    sign_in_as users(:volunteer_one)
    rsvp = @walking_a.rsvps.create!(user: users(:volunteer_one)) # solo walker organizer
    assert_difference -> { MealSpotRsvp.count }, -1 do
      delete schedule_item_meal_spot_rsvp_path(@meal, @spot_a, rsvp)
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
  end

  test "POST blocked when driver tries to switch via add-form" do
    sign_in_as users(:volunteer_one)
    drive_t = @spot_a.transports.create!(mode: :driving, departs_at: 1.hour.from_now, seats_offered: 3)
    drive_t.rsvps.create!(user: users(:volunteer_one)) # solo driver

    assert_no_difference -> { MealSpotRsvp.count } do
      post schedule_item_meal_spot_rsvps_path(@meal, @spot_a),
           params: { mode: "walking", departs_at: 90.minutes.from_now }
    end

    rsvp = MealSpotRsvp.find_by!(user: users(:volunteer_one), schedule_item: @meal)
    assert_equal drive_t.id, rsvp.meal_spot_transport_id, "still on driving"
    assert_match(/host this ride/i, flash[:alert])
  end

  test "POST switch via add-form: non-driver joins existing transport instead of failing on uniqueness" do
    sign_in_as users(:volunteer_one)
    # volunteer_one starts as a walker on a different spot, then tries to switch to walking at @spot_a
    # via the add-form. @walking_a already exists at @spot_a.
    other_walking = @spot_b.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    other_walking.rsvps.create!(user: users(:attendee_one)) # someone else is the organizer of other_walking
    other_walking.rsvps.create!(user: users(:volunteer_one)) # volunteer_one is just a passenger

    assert_no_difference -> { MealSpotTransport.count } do
      post schedule_item_meal_spot_rsvps_path(@meal, @spot_a),
           params: { mode: "walking", departs_at: 90.minutes.from_now }
    end

    rsvp = MealSpotRsvp.find_by!(user: users(:volunteer_one), schedule_item: @meal)
    assert_equal @walking_a.id, rsvp.meal_spot_transport_id, "user joined existing walking transport"
    assert_redirected_to schedule_item_meal_spots_path(@meal)
  end

  test "DELETE refuses to remove someone else's RSVP" do
    sign_in_as users(:volunteer_one)
    other_rsvp = @walking_a.rsvps.create!(user: users(:attendee_one))
    assert_no_difference -> { MealSpotRsvp.count } do
      delete schedule_item_meal_spot_rsvp_path(@meal, @spot_a, other_rsvp)
    end
    assert_response :not_found
  end
end
