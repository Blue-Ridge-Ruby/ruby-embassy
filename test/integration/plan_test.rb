require "test_helper"

class PlanTest < ActionDispatch::IntegrationTest
  setup do
    @talk = ScheduleItem.create!(
      slug: "thu-plan-talk",
      day: "thu",
      time_label: "10:00 AM",
      sort_time: 1000,
      title: "Planned Talk",
      host: "Jane",
      kind: :talk,
      is_public: true
    )
    @activity = ScheduleItem.create!(
      slug: "sat-plan-act",
      day: "sat",
      time_label: "2:00 PM",
      sort_time: 1400,
      title: "Planned Activity",
      kind: :activity,
      is_public: true
    )
  end

  test "anonymous GET /plan redirects to sign-in" do
    get plan_path
    assert_redirected_to new_session_path
  end

  test "/plan shows only current_user's plan_items" do
    alice = users(:attendee_one)
    vic   = users(:volunteer_one)
    alice.plan_items.create!(schedule_item: @talk)
    vic.plan_items.create!(schedule_item: @activity, notes: "Vic's secret note")

    sign_in_as alice
    get plan_path

    assert_response :success
    assert_match "Planned Talk", response.body
    assert_no_match "Planned Activity", response.body
    assert_no_match "Vic's secret note", response.body
  end

  test "/plan orders items by day then sort_time" do
    alice = users(:attendee_one)
    alice.plan_items.create!(schedule_item: @activity) # Saturday
    alice.plan_items.create!(schedule_item: @talk)     # Thursday

    sign_in_as alice
    get plan_path

    thu_idx = response.body.index("Planned Talk")
    sat_idx = response.body.index("Planned Activity")
    assert thu_idx && sat_idx
    assert thu_idx < sat_idx, "Thursday item should appear before Saturday item"
  end

  test "/plan shows notes for plan_items that have them" do
    alice = users(:attendee_one)
    alice.plan_items.create!(schedule_item: @talk, notes: "Sit near the front")

    sign_in_as alice
    get plan_path

    assert_match "Sit near the front", response.body
  end

  test "/plan shows item descriptions when present" do
    alice = users(:attendee_one)
    item = ScheduleItem.create!(
      day: "fri",
      time_label: "2:00 PM",
      sort_time: 1400,
      title: "Planned Item With Description",
      description: "Notes about this session go here.",
      kind: :activity,
      is_public: true
    )
    alice.plan_items.create!(schedule_item: item)

    sign_in_as alice
    get plan_path
    assert_match "Notes about this session go here.", response.body
  end

  test "/plan meal cards show 'Get or host a ride' when no transports exist" do
    alice = users(:attendee_one)
    meal  = ScheduleItem.create!(day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                  title: "Open Lunch", kind: :meal, is_public: true)
    alice.plan_items.create!(schedule_item: meal)

    sign_in_as alice
    get plan_path
    assert_match "Get or host a ride", response.body
  end

  test "/plan meal cards count transports, not spots — hosted meal with canonical spot but no transport" do
    alice = users(:attendee_one)
    hosted = ScheduleItem.create!(day: "thu", time_label: "6:00 PM", sort_time: 1800,
                                   title: "Welcome dinner", kind: :meal, is_public: true,
                                   host: "Alice", location: "Pleasant Garden Inn")
    MealSpot.canonical_for_hosted!(hosted)
    alice.plan_items.create!(schedule_item: hosted)

    sign_in_as alice
    get plan_path
    assert_match "Add a way to get there", response.body
    assert_no_match(/\d+ spot/, response.body, "must not display a spot count when no transports exist")
  end

  test "/plan hides the remove × button on a meal once the user has a spot RSVP" do
    alice = users(:attendee_one)
    meal  = ScheduleItem.create!(day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                  title: "Open Lunch", kind: :meal, is_public: true)
    spot  = meal.meal_spots.create!(name: "Hattie Hot Chicken", created_by: alice)
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: alice) # auto-creates the PlanItem

    sign_in_as alice
    get plan_path
    assert_match "Open Lunch", response.body
    assert_no_match(/aria-label="Remove from plan"/, response.body,
                    "remove button is hidden once user is RSVP'd to a spot for this meal")
  end

  test "/plan still shows the remove × button on a meal when the user has no spot RSVP" do
    alice = users(:attendee_one)
    meal  = ScheduleItem.create!(day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                  title: "Open Lunch", kind: :meal, is_public: true)
    alice.plan_items.create!(schedule_item: meal)

    sign_in_as alice
    get plan_path
    assert_match "Open Lunch", response.body
    assert_match(/aria-label="Remove from plan"/, response.body,
                 "remove button is present when no spot RSVP exists")
  end

  test "/plan meal cards show the user's spot details when RSVPd" do
    alice = users(:attendee_one)
    meal  = ScheduleItem.create!(day: "thu", time_label: "12:00 PM", sort_time: 1200,
                                  title: "Open Lunch", kind: :meal, is_public: true)
    spot  = meal.meal_spots.create!(name: "Hattie Hot Chicken", created_by: alice,
                                     map_url: "https://maps.app.goo.gl/x",
                                     meet_up_spot: "hotel lobby",
                                     contact_info: "DM Alice on Slack")
    transport = spot.transports.create!(mode: :driving, departs_at: Time.zone.local(2026, 4, 30, 12, 15), seats_offered: 3)
    transport.rsvps.create!(user: alice)

    sign_in_as alice
    get plan_path

    assert_match "Hattie Hot Chicken", response.body
    assert_match "Driving", response.body
    assert_match "12:15 PM", response.body
    assert_match "0 of 3 passenger seats", response.body
    assert_match "hotel lobby", response.body
    assert_match "DM Alice on Slack", response.body
    assert_match "View all spots", response.body
  end

  test "/plan shows remove button for each plan_item" do
    alice = users(:attendee_one)
    plan = alice.plan_items.create!(schedule_item: @talk)

    sign_in_as alice
    get plan_path

    assert_select "form[action=?][method=?]", plan_item_path(plan), "post" do
      assert_select "input[name=_method][value=delete]"
    end
  end

  test "/plan shows green READY badge on embassy card once application.ready_at is set" do
    alice = users(:attendee_one)
    passport_block = ScheduleItem.create!(
      day: "thu", time_label: "9:00 AM", sort_time: 900,
      title: "Passport Block", kind: :embassy, is_public: true,
      offers_new_passport: true, new_passport_capacity: 4
    )
    plan_item = alice.plan_items.create!(schedule_item: passport_block)
    booking = EmbassyBooking.create!(
      user: alice, schedule_item: passport_block, plan_item: plan_item,
      mode: "new_passport", state: "confirmed"
    )
    application = EmbassyApplication.create!(
      embassy_booking: booking, state: "submitted", submitted_at: Time.current,
      drawn_question_ids: [], notary_profile_id: nil,
      ready_at: Time.current
    )

    sign_in_as alice
    get plan_path

    assert_match "embassy-appointment-card--ready", response.body
    assert_match "embassy-ready-badge", response.body
    assert_match application.serial, response.body
    assert_no_match(/aria-label="Cancel appointment"/, response.body,
                    "cancel button is hidden once the embassy says ready")
  end

  test "/plan shows activity attendees, contact form for self, and contacts of co-RSVPers" do
    alice = users(:attendee_one)
    vic   = users(:volunteer_one)
    alice.plan_items.create!(schedule_item: @activity)
    vic.plan_items.create!(schedule_item: @activity, contact_method: "@vic on Slack")

    sign_in_as alice
    get plan_path

    assert_match "Going (2)", response.body
    assert_match "Alice", response.body
    assert_match "Vic", response.body
    assert_match "@vic on Slack", response.body, "alice (a co-RSVPer) should see vic's contact"
    assert_match "How to reach you", response.body, "alice should see her own contact form"
  end
end
