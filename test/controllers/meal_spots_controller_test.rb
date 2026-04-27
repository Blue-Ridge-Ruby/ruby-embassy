require "test_helper"

class MealSpotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @meal = ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
    @talk = ScheduleItem.create!(day: "thu", title: "Keynote", kind: :talk, is_public: true)
  end

  test "anonymous index redirects to sign-in" do
    get schedule_item_meal_spots_path(@meal)
    assert_redirected_to new_session_path
  end

  test "index shows the empty state when no spots exist" do
    sign_in_as users(:attendee_one)
    get schedule_item_meal_spots_path(@meal)
    assert_response :success
    assert_match "No plans yet, be the first to suggest a spot.", response.body
    assert_match "Suggest a spot", response.body
  end

  test "index renders spot cards and transport groups when spots exist" do
    sign_in_as users(:attendee_one)
    spot = @meal.meal_spots.create!(name: "Hattie Hot Chicken", created_by: users(:attendee_one),
                                     map_url: "https://maps.app.goo.gl/x", contact_info: "DM Alice")
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: users(:attendee_one))

    get schedule_item_meal_spots_path(@meal)
    assert_response :success
    assert_match "Hattie Hot Chicken", response.body
    assert_match "Walking", response.body
    assert_match "DM Alice", response.body
    assert_match "Add a different way to get there", response.body
  end

  test "index 404s for non-meal items" do
    sign_in_as users(:attendee_one)
    get schedule_item_meal_spots_path(@talk)
    assert_response :not_found
  end

  test "new page surfaces the meal event details (title, day, date) in a summary card" do
    sign_in_as users(:attendee_one)
    get new_schedule_item_meal_spot_path(@meal)
    assert_response :success
    assert_match @meal.title,                                response.body
    assert_match ScheduleItem::DAY_META[@meal.day][:label],  response.body
    assert_match ScheduleItem::DAY_META[@meal.day][:date],   response.body
  end

  test "POST create makes a spot, transport, RSVP and parent PlanItem in one transaction" do
    sign_in_as users(:attendee_one)
    meal_id = @meal.id

    assert_difference [ "MealSpot.count", "MealSpotTransport.count", "MealSpotRsvp.count",
                        "PlanItem.where(schedule_item_id: #{meal_id}).count" ], 1 do
      post schedule_item_meal_spots_path(@meal), params: {
        meal_spot: { name: "Hattie B's", map_url: "https://maps.app.goo.gl/x", contact_info: "DM Alice" },
        transport: { mode: "walking", departs_at: 1.hour.from_now }
      }
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
  end

  test "GET new is blocked when the user already hosts a spot for this meal" do
    sign_in_as users(:attendee_one)
    @meal.meal_spots.create!(name: "First spot", created_by: users(:attendee_one))

    get new_schedule_item_meal_spot_path(@meal)
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/already hosting/, flash[:alert])
  end

  test "POST create is blocked when the user already hosts a spot for this meal" do
    sign_in_as users(:attendee_one)
    @meal.meal_spots.create!(name: "First spot", created_by: users(:attendee_one))

    assert_no_difference -> { MealSpot.count } do
      post schedule_item_meal_spots_path(@meal), params: {
        meal_spot: { name: "Second spot" },
        transport: { mode: "walking", departs_at: 1.hour.from_now }
      }
    end
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/already hosting/, flash[:alert])
  end

  test "index hides 'Suggest another spot' button when the user already hosts one" do
    sign_in_as users(:attendee_one)
    @meal.meal_spots.create!(name: "Hattie Hot Chicken", created_by: users(:attendee_one))

    get schedule_item_meal_spots_path(@meal)
    assert_response :success
    assert_no_match(/Suggest another spot/, response.body)
    assert_match(/You're hosting/, response.body)
  end

  test "POST create surfaces validation errors when name is missing" do
    sign_in_as users(:attendee_one)
    assert_no_difference -> { MealSpot.count } do
      post schedule_item_meal_spots_path(@meal), params: {
        meal_spot: { name: "" },
        transport: { mode: "walking", departs_at: 1.hour.from_now }
      }
    end
    assert_response :unprocessable_content
  end

  test "private spots are hidden from non-creators on the index" do
    sign_in_as users(:attendee_one)
    private_spot = @meal.meal_spots.create!(name: "Solo bowl", created_by: users(:attendee_one), is_public: false)

    get schedule_item_meal_spots_path(@meal)
    assert_response :success
    assert_match "Solo bowl", response.body
    assert_match "Private",   response.body, "creator sees the private badge"

    sign_in_as users(:volunteer_one)
    get schedule_item_meal_spots_path(@meal)
    assert_response :success
    assert_no_match(/Solo bowl/, response.body, "non-creator can't see the private spot")
  end

  test "POST create accepts is_public=false for private spots" do
    sign_in_as users(:attendee_one)
    post schedule_item_meal_spots_path(@meal), params: {
      meal_spot: { name: "Solo lunch", is_public: "false" },
      transport: { mode: "walking", departs_at: 1.hour.from_now }
    }
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    spot = MealSpot.find_by!(name: "Solo lunch")
    assert_not spot.is_public
  end

  test "edit is blocked when another attendee has RSVPd, allowed for admins" do
    sign_in_as users(:attendee_one)
    spot = @meal.meal_spots.create!(name: "Pinewood", created_by: users(:attendee_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: users(:attendee_one))

    get edit_schedule_item_meal_spot_path(@meal, spot)
    assert_response :success

    transport.rsvps.create!(user: users(:volunteer_one))
    get edit_schedule_item_meal_spot_path(@meal, spot)
    assert_redirected_to schedule_item_meal_spots_path(@meal)
    assert_match(/admin/, flash[:alert])

    sign_in_as users(:jeremy)
    get edit_schedule_item_meal_spot_path(@meal, spot)
    assert_response :success
  end

  # ----- Hosted meals -----------------------------------------------------

  def hosted_meal
    @hosted_meal ||= ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                           is_public: true, host: "Alice",
                                           location: "Pleasant Garden Inn",
                                           map_url: "https://maps.app.goo.gl/x")
  end

  test "index on a hosted meal auto-creates the canonical spot on first visit" do
    sign_in_as users(:attendee_one)
    assert_equal 0, hosted_meal.meal_spots.count

    get schedule_item_meal_spots_path(hosted_meal)
    assert_response :success
    assert_equal 1, hosted_meal.meal_spots.count
    assert_nil hosted_meal.meal_spots.first.created_by_id
  end

  test "index on a hosted meal hides the 'Suggest a spot' UI" do
    sign_in_as users(:attendee_one)
    get schedule_item_meal_spots_path(hosted_meal)
    assert_response :success
    assert_no_match(/Suggest a spot/, response.body)
    assert_no_match(/Suggest another spot/, response.body)
    assert_match(/Add a way to get there/, response.body)
  end

  test "GET new on a hosted meal redirects with a hosted-meal flash" do
    sign_in_as users(:attendee_one)
    get new_schedule_item_meal_spot_path(hosted_meal)
    assert_redirected_to schedule_item_meal_spots_path(hosted_meal)
    assert_match(/hosted at/, flash[:alert])
  end

  test "POST create on a hosted meal is blocked" do
    sign_in_as users(:attendee_one)
    assert_no_difference -> { MealSpot.where.not(created_by_id: nil).count } do
      post schedule_item_meal_spots_path(hosted_meal), params: {
        meal_spot: { name: "Some other place" },
        transport: { mode: "walking", departs_at: 1.hour.from_now }
      }
    end
    assert_redirected_to schedule_item_meal_spots_path(hosted_meal)
    assert_match(/hosted at/, flash[:alert])
  end
end
