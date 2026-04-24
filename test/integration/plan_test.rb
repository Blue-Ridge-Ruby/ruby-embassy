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

  test "/plan shows remove button for each plan_item" do
    alice = users(:attendee_one)
    plan = alice.plan_items.create!(schedule_item: @talk)

    sign_in_as alice
    get plan_path

    assert_select "form[action=?][method=?]", plan_item_path(plan), "post" do
      assert_select "input[name=_method][value=delete]"
    end
  end
end
