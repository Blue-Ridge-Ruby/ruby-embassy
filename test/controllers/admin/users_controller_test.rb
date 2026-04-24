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
      title: "Alice planned talk",
      kind: :talk,
      is_public: true,
      time_label: "10:00 AM",
      sort_time: 1000
    )
    alice.plan_items.create!(schedule_item: item)

    sign_in_as users(:jeremy)
    get admin_user_path(alice)
    assert_match "Alice planned talk", response.body
  end

  test "admin users index links to each user's show page" do
    sign_in_as users(:jeremy)
    get admin_users_path

    User.all.each do |u|
      assert_select "a[href=?]", admin_user_path(u)
    end
  end
end
