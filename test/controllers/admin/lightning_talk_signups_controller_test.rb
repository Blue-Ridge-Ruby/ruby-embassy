require "test_helper"

class Admin::LightningTalkSignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:jeremy)
    @item  = ScheduleItem.create!(
      day: "fri", title: "Lightning Talks", kind: :lightning,
      sort_time: 1400, time_label: "2:00 PM", is_public: true
    )
  end

  test "non-admin gets 404 from index" do
    sign_in_as users(:attendee_one)
    get admin_schedule_item_lightning_talk_signups_path(@item)
    assert_response :not_found
  end

  test "admin HTML index redirects to top-level Lightning Talks page" do
    sign_in_as @admin
    get admin_schedule_item_lightning_talk_signups_path(@item)
    assert_redirected_to admin_lightning_talks_path
  end

  test "admin can add a speaker" do
    sign_in_as @admin
    assert_difference -> { LightningTalkSignup.count }, 1 do
      post admin_schedule_item_lightning_talk_signups_path(@item),
           params: { user_id: users(:attendee_one).id }
    end
  end

  test "admin can update talk details for any speaker" do
    sign_in_as @admin
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    patch admin_schedule_item_lightning_talk_signup_path(@item, signup),
          params: { lightning_talk_signup: { talk_title: "Admin-edited" } }
    assert_equal "Admin-edited", signup.reload.talk_title
  end

  test "admin destroy renumbers subsequent positions" do
    sign_in_as @admin
    s1 = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    s2 = LightningTalkSignup.claim_next_slot!(user: users(:volunteer_one), schedule_item: @item)
    s3 = LightningTalkSignup.claim_next_slot!(user: users(:katya), schedule_item: @item)

    delete admin_schedule_item_lightning_talk_signup_path(@item, s2)

    assert_nil LightningTalkSignup.find_by(id: s2.id)
    assert_equal 1, s1.reload.position
    assert_equal 2, s3.reload.position
  end

  test "admin reorder updates positions" do
    sign_in_as @admin
    s1 = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    s2 = LightningTalkSignup.claim_next_slot!(user: users(:volunteer_one), schedule_item: @item)
    s3 = LightningTalkSignup.claim_next_slot!(user: users(:katya), schedule_item: @item)

    patch reorder_admin_schedule_item_lightning_talk_signups_path(@item),
          params: { signup_ids: [ s3.id, s1.id, s2.id ] },
          as: :json

    assert_response :no_content
    assert_equal 1, s3.reload.position
    assert_equal 2, s1.reload.position
    assert_equal 3, s2.reload.position
  end

  test "PDF export returns pdf content type" do
    sign_in_as @admin
    LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: @item)
    get admin_schedule_item_lightning_talk_signups_path(@item, format: :pdf)
    assert_response :success
    assert_match "application/pdf", @response.content_type
    assert @response.body.start_with?("%PDF-"), "expected PDF signature"
  end
end
