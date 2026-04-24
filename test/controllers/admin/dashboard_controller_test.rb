require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "anonymous GET /admin returns 404" do
    get admin_root_path
    assert_response :not_found
  end

  test "attendee GET /admin returns 404" do
    sign_in_as users(:attendee_one)
    get admin_root_path
    assert_response :not_found
  end

  test "volunteer GET /admin returns 404" do
    sign_in_as users(:volunteer_one)
    get admin_root_path
    assert_response :not_found
  end

  test "admin GET /admin returns 200 and shows section links" do
    sign_in_as users(:jeremy)
    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_users_path
    assert_select "a[href=?]", admin_schedule_items_path
    assert_select "a[href=?]", "/admin/jobs"
  end

  test "dashboard shows counts" do
    # Seed a handful of items so counts are non-zero
    ScheduleItem.create!(day: "thu", title: "Count test", kind: :activity, is_public: true)

    sign_in_as users(:jeremy)
    get admin_root_path

    assert_match(/#{User.count}/, response.body)
    assert_match(/#{ScheduleItem.count}/, response.body)
  end
end
