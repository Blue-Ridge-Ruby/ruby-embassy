require "test_helper"

class Admin::LightningTalksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:jeremy)
    @item  = ScheduleItem.create!(
      day: "fri", title: "Lightning Talks", kind: :lightning,
      sort_time: 1400, time_label: "2:00 PM", is_public: true
    )
  end

  test "non-admin gets 404" do
    sign_in_as users(:attendee_one)
    get admin_lightning_talks_path
    assert_response :not_found
  end

  test "admin sees the lineup directly with the speakers panel" do
    sign_in_as @admin
    LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    get admin_lightning_talks_path
    assert_response :success
    assert_match @item.title, @response.body
    assert_match users(:attendee_one).full_name, @response.body
    assert_match "Speakers", @response.body
  end

  test "admin sees empty state when no lightning block exists" do
    @item.destroy
    sign_in_as @admin
    get admin_lightning_talks_path
    assert_response :success
    assert_match "No lightning talk block", @response.body
  end
end
