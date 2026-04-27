require "test_helper"

class Admin::VolunteerSlotsControllerTest < ActionDispatch::IntegrationTest
  test "attendee cannot access /admin/volunteer_slots" do
    sign_in_as users(:attendee_one)
    get admin_volunteer_slots_path
    assert_response :not_found
  end

  test "admin sees the slot index with capacity status" do
    ScheduleItem.create!(
      day: "fri", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 3
    )

    sign_in_as users(:jeremy)
    get admin_volunteer_slots_path
    assert_response :success
    assert_match "Stamp passports", response.body
    assert_match "Help wanted", response.body
  end

  test "admin show page lists signups + add form" do
    slot = ScheduleItem.create!(
      day: "fri", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 3
    )
    slot.plan_items.create!(user: users(:volunteer_one))

    sign_in_as users(:jeremy)
    get admin_volunteer_slot_path(slot)
    assert_response :success
    assert_match users(:volunteer_one).full_name, response.body
    assert_match "Add a volunteer", response.body
  end

  test "admin show page returns 404 for non-volunteer-kind item" do
    talk = ScheduleItem.create!(day: "fri", title: "A talk", kind: :talk, is_public: true)
    sign_in_as users(:jeremy)
    get admin_volunteer_slot_path(talk)
    assert_response :not_found
  end

  test "admin show page hides add form when slot is full" do
    slot = ScheduleItem.create!(
      day: "fri", title: "Cleanup",
      kind: :volunteer, is_public: true, volunteer_capacity: 1
    )
    slot.plan_items.create!(user: users(:volunteer_one))

    sign_in_as users(:jeremy)
    get admin_volunteer_slot_path(slot)
    assert_match "This slot is full", response.body
  end
end
