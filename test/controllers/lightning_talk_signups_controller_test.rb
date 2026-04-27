require "test_helper"

class LightningTalkSignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = ScheduleItem.create!(
      day: "fri", title: "Lightning Talks", kind: :lightning,
      sort_time: 1400, time_label: "2:00 PM", is_public: true
    )
  end

  test "anonymous POST redirects to sign in" do
    post schedule_item_lightning_talk_signup_path(@item)
    assert_redirected_to new_session_path
  end

  test "signed-in user can claim a slot" do
    sign_in_as users(:attendee_one)
    assert_difference -> { LightningTalkSignup.count }, 1 do
      post schedule_item_lightning_talk_signup_path(@item)
    end
    signup = LightningTalkSignup.last
    assert_equal users(:attendee_one), signup.user
    assert_equal 1, signup.position
  end

  test "claiming a slot auto-creates a PlanItem" do
    sign_in_as users(:attendee_one)
    assert_difference -> { PlanItem.count }, 1 do
      post schedule_item_lightning_talk_signup_path(@item)
    end
  end

  test "POST when full does not create and shows alert" do
    LightningTalkSignup::MAX_SPEAKERS.times do |i|
      user = User.create!(email: "filler-#{i}@example.com", role: :attendee)
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: @item)
    end
    sign_in_as users(:attendee_one)
    assert_no_difference -> { LightningTalkSignup.count } do
      post schedule_item_lightning_talk_signup_path(@item)
    end
    assert_match(/full/i, flash[:alert].to_s)
  end

  test "speaker can edit own talk details" do
    sign_in_as users(:attendee_one)
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    patch schedule_item_lightning_talk_signup_path(@item),
          params: { lightning_talk_signup: { talk_title: "Hello", talk_description: "About a thing", slides_url: "https://example.com/slides" } }
    signup.reload
    assert_equal "Hello", signup.talk_title
    assert_equal "About a thing", signup.talk_description
    assert_equal "https://example.com/slides", signup.slides_url
  end

  test "user without a signup gets 404 when editing" do
    sign_in_as users(:attendee_one)
    LightningTalkSignup.claim_next_slot!(user: users(:volunteer_one), schedule_item: @item)
    get edit_schedule_item_lightning_talk_signup_path(@item)
    assert_response :not_found
  end
end
