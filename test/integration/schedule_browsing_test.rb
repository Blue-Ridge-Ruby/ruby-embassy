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
      is_public: true
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
      kind: :volunteer, is_public: true, audience: "volunteers_only"
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
      kind: :volunteer, is_public: true, audience: "volunteers_only"
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
      kind: :volunteer, is_public: true, audience: "volunteers_only"
    )
    sign_in_as users(:jeremy)
    get schedule_path
    assert_match "Volunteer Briefing", response.body
  end
end
