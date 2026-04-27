require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "attendee GET /admin/users/:id returns 404" do
    sign_in_as users(:attendee_one)
    get admin_user_path(users(:volunteer_one))
    assert_response :not_found
  end

  test "admin GET /admin/users/:id returns 200" do
    sign_in_as users(:jeremy)
    get admin_user_path(users(:attendee_one))
    assert_response :success
    assert_match users(:attendee_one).full_name, response.body
    assert_match users(:attendee_one).email,     response.body
  end

  test "admin show page lists the user's plan items" do
    alice = users(:attendee_one)
    item = ScheduleItem.create!(
      day: "fri",
      title: "Alice planned activity",
      kind: :activity,
      is_public: true,
      time_label: "10:00 AM",
      sort_time: 1000
    )
    alice.plan_items.create!(schedule_item: item)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_match "Alice planned activity", response.body
  end

  test "admin show page hides talks and receptions from the plan section" do
    alice = users(:attendee_one)
    talk = ScheduleItem.create!(
      day: "fri", title: "Default Talk", kind: :talk,
      is_public: true, time_label: "10:00 AM", sort_time: 1000
    )
    reception = ScheduleItem.create!(
      day: "fri", title: "Default Reception", kind: :reception,
      is_public: true, time_label: "6:00 PM", sort_time: 1800
    )
    activity = ScheduleItem.create!(
      day: "sat", title: "Optional Activity", kind: :activity,
      is_public: true, time_label: "2:00 PM", sort_time: 1400
    )
    alice.plan_items.create!(schedule_item: talk)
    alice.plan_items.create!(schedule_item: reception)
    alice.plan_items.create!(schedule_item: activity)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_response :success
    assert_match "Optional Activity", response.body
    assert_no_match(/Default Talk/, response.body)
    assert_no_match(/Default Reception/, response.body)
  end

  test "admin users index links to each user's show page" do
    sign_in_as users(:jeremy)
    get admin_users_path

    User.all.each do |u|
      assert_select "a[href=?]", admin_user_path(u)
    end
  end

  test "show page lists events the user is hosting under Hosting" do
    alice = users(:attendee_one)
    ScheduleItem.create!(
      day: "fri",
      title: "Alice hosted session",
      host: alice.full_name,
      kind: :talk,
      is_public: true,
      time_label: "2:00 PM",
      sort_time: 1400
    )

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_response :success
    assert_match "Hosting", response.body
    assert_match "Alice hosted session", response.body
  end

  test "show page surfaces an embassy plan item under its own section" do
    alice = users(:attendee_one)
    embassy = ScheduleItem.create!(
      day: "sat",
      title: "Alice embassy slot",
      kind: :embassy,
      is_public: true,
      offers_new_passport: true,
      new_passport_capacity: 4,
      time_label: "10:00 AM",
      sort_time: 1000,
      flexible: true
    )
    alice.plan_items.create!(schedule_item: embassy)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_select "h2", text: "Embassy"
    assert_match "Alice embassy slot", response.body
  end

  test "embassy plan items do not appear in the generic plan section" do
    alice = users(:attendee_one)
    embassy = ScheduleItem.create!(
      day: "sat",
      title: "Only embassy item",
      kind: :embassy,
      is_public: true,
      offers_new_passport: true,
      new_passport_capacity: 4,
      time_label: "10:00 AM",
      sort_time: 1000
    )
    alice.plan_items.create!(schedule_item: embassy)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    # The embassy header and item render once in the Embassy section,
    # and the catch-all "On their plan" section should show the empty
    # state since this user has no non-embassy plan items.
    assert_match "Nothing else planned", response.body
  end
end
