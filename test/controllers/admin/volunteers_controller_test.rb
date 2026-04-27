require "test_helper"

class Admin::VolunteersControllerTest < ActionDispatch::IntegrationTest
  test "attendee cannot access /admin/volunteers" do
    sign_in_as users(:attendee_one)
    get admin_volunteers_path
    assert_response :not_found
  end

  test "admin sees volunteer list with slot counts" do
    slot = ScheduleItem.create!(
      day: "fri", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 3
    )
    slot.plan_items.create!(user: users(:volunteer_one))

    sign_in_as users(:jeremy)
    get admin_volunteers_path
    assert_response :success
    assert_match users(:volunteer_one).full_name, response.body
  end

  test "admin show page renders volunteer's slots and assign form" do
    slot = ScheduleItem.create!(
      day: "fri", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 3
    )
    slot.plan_items.create!(user: users(:volunteer_one))

    sign_in_as users(:jeremy)
    get admin_volunteer_path(users(:volunteer_one))
    assert_response :success
    assert_match "Stamp passports", response.body
    assert_match "Assign to a volunteer slot", response.body
  end

  test "admin show page returns 404 for an attendee" do
    sign_in_as users(:jeremy)
    get admin_volunteer_path(users(:attendee_one))
    assert_response :not_found
  end
end
