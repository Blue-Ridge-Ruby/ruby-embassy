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

  test "admin sees the index page with lightning blocks" do
    sign_in_as @admin
    LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    get admin_lightning_talks_path
    assert_response :success
    assert_match @item.title, @response.body
    assert_match "1", @response.body  # at least one speaker count rendered
  end

  test "admin sees Full badge when block is at capacity" do
    sign_in_as @admin
    LightningTalkSignup::MAX_SPEAKERS.times do |i|
      user = User.create!(email: "filler-#{i}@example.com", role: :attendee)
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: @item)
    end
    get admin_lightning_talks_path
    assert_response :success
    assert_match "Full", @response.body
  end

  test "admin sees empty state when no lightning items exist" do
    @item.destroy
    sign_in_as @admin
    get admin_lightning_talks_path
    assert_response :success
    assert_match "No lightning talk blocks", @response.body
  end
end
