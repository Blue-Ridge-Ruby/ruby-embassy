require "test_helper"

class Admin::VolunteerSignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @slot = ScheduleItem.create!(
      day: "fri", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 2
    )
  end

  test "attendee cannot create a signup" do
    sign_in_as users(:attendee_one)
    assert_no_difference -> { PlanItem.count } do
      post admin_volunteer_signups_path,
           params: { user_id: users(:volunteer_one).id, schedule_item_id: @slot.id }
    end
    assert_response :not_found
  end

  test "admin can assign a volunteer to a slot" do
    sign_in_as users(:jeremy)
    assert_difference -> { PlanItem.count }, 1 do
      post admin_volunteer_signups_path,
           params: { user_id: users(:volunteer_one).id, schedule_item_id: @slot.id }
    end
    assert_redirected_to admin_volunteers_path
  end

  test "admin cannot assign someone to a slot that's already full" do
    @slot.update!(volunteer_capacity: 1)
    @slot.plan_items.create!(user: users(:volunteer_one))

    sign_in_as users(:jeremy)
    assert_no_difference -> { PlanItem.count } do
      post admin_volunteer_signups_path,
           params: { user_id: users(:jeremy).id, schedule_item_id: @slot.id }
    end
    follow_redirect!
    assert_match "full", response.body
  end

  test "admin cannot assign attendee through this endpoint (scoped finder)" do
    sign_in_as users(:jeremy)
    assert_no_difference -> { PlanItem.count } do
      post admin_volunteer_signups_path,
           params: { user_id: users(:attendee_one).id, schedule_item_id: @slot.id }
    end
    assert_response :not_found
  end

  test "admin cannot use this endpoint for non-volunteer-kind items (scoped finder)" do
    talk = ScheduleItem.create!(day: "fri", title: "A talk", kind: :talk, is_public: true)
    sign_in_as users(:jeremy)
    assert_no_difference -> { PlanItem.count } do
      post admin_volunteer_signups_path,
           params: { user_id: users(:volunteer_one).id, schedule_item_id: talk.id }
    end
    assert_response :not_found
  end

  test "admin can remove a signup" do
    plan = @slot.plan_items.create!(user: users(:volunteer_one))
    sign_in_as users(:jeremy)
    assert_difference -> { PlanItem.count }, -1 do
      delete admin_volunteer_signup_path(plan)
    end
    assert_redirected_to admin_volunteers_path
  end
end
