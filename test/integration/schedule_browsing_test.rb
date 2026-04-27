require "test_helper"

class ScheduleBrowsingTest < ActionDispatch::IntegrationTest
  setup do
    @talk = ScheduleItem.create!(
      slug: "test-talk",
      day: "thu",
      time_label: "10:00 AM",
      sort_time: 1000,
      title: "A Talk About Tests",
      host: "Jane Speaker",
      kind: :talk,
      is_public: true
    )
    @activity = ScheduleItem.create!(
      slug: "test-activity",
      day: "sat",
      time_label: "TBD",
      sort_time: 1000,
      title: "Group Bike Ride",
      kind: :activity,
      is_public: true,
      flexible: true
    )
    @embassy = ScheduleItem.create!(
      slug: "test-embassy",
      day: "thu",
      time_label: "9:00 AM",
      sort_time: 900,
      title: "Welcome",
      kind: :embassy,
      is_public: true,
      offers_new_passport: true,
      new_passport_capacity: 8
    )
    @private_item = ScheduleItem.create!(
      slug: "test-private",
      day: "thu",
      time_label: "7:00 PM",
      sort_time: 1900,
      title: "Secret Dinner",
      kind: :activity,
      is_public: false,
      created_by: users(:attendee_one)
    )
  end

  test "signed-in attendee sees public items on /schedule" do
    sign_in_as users(:attendee_one)
    get schedule_path

    assert_response :success
    assert_select "h1", text: /Schedule/i
    assert_match "A Talk About Tests", response.body
    assert_match "Jane Speaker",        response.body
    assert_match "Group Bike Ride",     response.body
    assert_match "Welcome",             response.body
  end

  test "private items do not appear on /schedule even for creator" do
    sign_in_as users(:attendee_one)
    get schedule_path

    assert_no_match "Secret Dinner", response.body
  end

  test "talks show 'Add to plan' button label" do
    sign_in_as users(:attendee_one)
    get schedule_path

    assert_match(/Add to plan/i, response.body)
  end

  test "non-talks show 'RSVP' button label" do
    sign_in_as users(:attendee_one)
    get schedule_path

    assert_match(/RSVP/i, response.body)
  end

  test "descriptions render on schedule items when present" do
    ScheduleItem.create!(
      slug: "desc-test",
      day: "thu",
      time_label: "10:00 AM",
      sort_time: 1000,
      title: "Item with details",
      description: "Bring a notebook and questions for the speaker.",
      kind: :talk,
      is_public: true
    )
    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match "Bring a notebook and questions for the speaker.", response.body
  end

  test "days are rendered in conference order (wed, thu, fri, sat)" do
    sign_in_as users(:attendee_one)
    get schedule_path

    body = response.body
    thu_index = body.index("Thursday")
    sat_index = body.index("Saturday")
    assert thu_index, "Thursday header should render"
    assert sat_index, "Saturday header should render"
    assert thu_index < sat_index, "Thursday should render before Saturday"
  end

  test "attendees do not see volunteers_only items on /schedule" do
    ScheduleItem.create!(
      slug: "volunteer-briefing",
      day: "fri", time_label: "8:00 AM", sort_time: 800,
      title: "Volunteer Briefing",
      kind: :volunteer, is_public: true, audience: "volunteers_only",
      volunteer_capacity: 3
    )
    sign_in_as users(:attendee_one)
    get schedule_path
    assert_no_match "Volunteer Briefing", response.body
  end

  test "volunteers see volunteers_only items on /schedule" do
    ScheduleItem.create!(
      slug: "volunteer-briefing",
      day: "fri", time_label: "8:00 AM", sort_time: 800,
      title: "Volunteer Briefing",
      kind: :volunteer, is_public: true, audience: "volunteers_only",
      volunteer_capacity: 3
    )
    sign_in_as users(:volunteer_one)
    get schedule_path
    assert_match "Volunteer Briefing", response.body
  end

  test "admins see volunteers_only items on /schedule" do
    ScheduleItem.create!(
      slug: "volunteer-briefing",
      day: "fri", time_label: "8:00 AM", sort_time: 800,
      title: "Volunteer Briefing",
      kind: :volunteer, is_public: true, audience: "volunteers_only",
      volunteer_capacity: 3
    )
    sign_in_as users(:jeremy)
    get schedule_path
    assert_match "Volunteer Briefing", response.body
  end

  # ----- Meal rides summary on /schedule ---------------------------------

  test "meal cards on /schedule show 'Suggest a spot' for non-hosted meals with no rides" do
    ScheduleItem.create!(slug: "thu-lunch", day: "thu", time_label: "12:00 PM", sort_time: 1200,
                          title: "Open Lunch", kind: :meal, is_public: true)
    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match "Open Lunch", response.body
    assert_match "Suggest a spot", response.body
    assert_no_match(/Get or host a ride/, response.body, "ride wording is reserved for hosted meals")
  end

  test "meal cards on /schedule list spots and compact transport info when rides exist" do
    meal = ScheduleItem.create!(slug: "thu-lunch", day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                 title: "Open Lunch", kind: :meal, is_public: true)
    spot = meal.meal_spots.create!(name: "Hattie Hot Chicken", created_by: users(:attendee_one),
                                    map_url: "https://maps.app.goo.gl/x")
    transport = spot.transports.create!(mode: :walking, departs_at: Time.zone.local(2026, 4, 30, 12, 15))
    transport.rsvps.create!(user: users(:attendee_one))

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match "Hattie Hot Chicken", response.body, "spot name shows"
    assert_match "https://maps.app.goo.gl/x", response.body, "map link shows"
    assert_match "Walking", response.body
    assert_match "12:15 PM", response.body
    assert_match "1 going", response.body
    assert_match "Click to see more info or RSVP", response.body
    assert_no_match(/Suggest a spot/, response.body, "empty-state CTA is suppressed when rides exist")
  end

  test "meal cards on /schedule hide private spots from non-creators" do
    meal = ScheduleItem.create!(slug: "thu-lunch", day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                 title: "Open Lunch", kind: :meal, is_public: true)
    private_spot = meal.meal_spots.create!(name: "Solo bowl", created_by: users(:attendee_one), is_public: false)
    private_spot.transports.create!(mode: :walking, departs_at: Time.zone.local(2026, 4, 30, 12, 0))

    sign_in_as users(:volunteer_one)
    get schedule_path
    assert_no_match(/Solo bowl/, response.body, "private spot is hidden on /schedule")
    assert_match "Suggest a spot", response.body, "falls through to empty state"
  end

  test "meal cards on /schedule hide private spots even for the creator" do
    meal = ScheduleItem.create!(slug: "thu-lunch", day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                 title: "Open Lunch", kind: :meal, is_public: true)
    private_spot = meal.meal_spots.create!(name: "Solo bowl", created_by: users(:attendee_one), is_public: false)
    private_spot.transports.create!(mode: :walking, departs_at: Time.zone.local(2026, 4, 30, 12, 0))

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_no_match(/Solo bowl/, response.body, "schedule page never shows private spots, even to creator")
  end

  test "hosted meal with canonical spot but no transports shows 'No rides yet' placeholder" do
    hosted = ScheduleItem.create!(slug: "thu-dinner", day: "thu", time_label: "6:00 PM", sort_time: 1800,
                                   title: "Welcome dinner", kind: :meal, is_public: true,
                                   host: "Alice", location: "Pleasant Garden Inn")
    MealSpot.canonical_for_hosted!(hosted)

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match "No rides yet", response.body
    assert_match "Get or host a ride", response.body
  end

  test "hosted meal hides the canonical spot's name (already shown as the meal's location)" do
    hosted = ScheduleItem.create!(slug: "thu-dinner", day: "thu", time_label: "6:00 PM", sort_time: 1800,
                                   title: "Welcome dinner", kind: :meal, is_public: true,
                                   host: "Alice", location: "Pleasant Garden Inn")
    canonical = MealSpot.canonical_for_hosted!(hosted)
    transport = canonical.transports.create!(mode: :walking, departs_at: Time.zone.local(2026, 4, 30, 18, 0))
    transport.rsvps.create!(user: users(:attendee_one))

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match "Walking", response.body
    assert_match "6:00 PM", response.body
    # Pleasant Garden Inn appears once (as the meal's location), not twice (not also as the spot title)
    assert_equal 1, response.body.scan("Pleasant Garden Inn").size
  end
end
