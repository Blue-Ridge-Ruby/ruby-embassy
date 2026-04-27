require "test_helper"

class PlanItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = ScheduleItem.create!(
      slug: "test-talk",
      day: "thu",
      title: "Test Talk",
      kind: :talk,
      is_public: true
    )
  end

  test "anonymous POST /plan_items redirects to sign-in" do
    post plan_items_path, params: { schedule_item_id: @item.id }
    assert_redirected_to new_session_path
  end

  test "signed-in attendee POST creates a plan_item" do
    sign_in_as users(:attendee_one)
    assert_difference -> { users(:attendee_one).plan_items.count }, 1 do
      post plan_items_path, params: { schedule_item_id: @item.id }
    end
  end

  test "POST with duplicate schedule_item does not double-create" do
    sign_in_as users(:attendee_one)
    post plan_items_path, params: { schedule_item_id: @item.id }
    assert_no_difference -> { users(:attendee_one).plan_items.count } do
      post plan_items_path, params: { schedule_item_id: @item.id }
    end
  end

  test "DELETE removes caller's own plan_item" do
    sign_in_as users(:attendee_one)
    plan = users(:attendee_one).plan_items.create!(schedule_item: @item)
    assert_difference -> { PlanItem.count }, -1 do
      delete plan_item_path(plan)
    end
  end

  test "DELETE on another user's plan_item returns 404" do
    sign_in_as users(:attendee_one)
    other_plan = users(:volunteer_one).plan_items.create!(schedule_item: @item)

    assert_no_difference -> { PlanItem.count } do
      delete plan_item_path(other_plan)
    end
    assert_response :not_found
  end

  test "PATCH updates notes on own plan_item" do
    sign_in_as users(:attendee_one)
    plan = users(:attendee_one).plan_items.create!(schedule_item: @item)

    patch plan_item_path(plan), params: { plan_item: { notes: "Sit near the front" } }
    assert_equal "Sit near the front", plan.reload.notes
  end

  test "PATCH on another user's plan_item returns 404" do
    sign_in_as users(:attendee_one)
    other_plan = users(:volunteer_one).plan_items.create!(schedule_item: @item)

    patch plan_item_path(other_plan), params: { plan_item: { notes: "injected" } }
    assert_response :not_found
    assert_not_equal "injected", other_plan.reload.notes
  end

  test "DELETE on a passport_pickup plan_item is refused (admin-only cancel)" do
    pickup_block = ScheduleItem.create!(
      day: "sat", title: "Pickup", kind: :embassy, is_public: true,
      offers_passport_pickup: true, passport_pickup_capacity: 2,
      time_label: "2:00 PM", sort_time: 1400
    )
    user      = users(:attendee_one)
    plan_item = user.plan_items.create!(schedule_item: pickup_block)
    EmbassyBooking.create!(user: user, schedule_item: pickup_block, plan_item: plan_item,
                           mode: "passport_pickup", state: "confirmed")

    sign_in_as user
    assert_no_difference -> { PlanItem.count } do
      delete plan_item_path(plan_item)
    end
  end

  test "attendee POST to a volunteers_only item returns 404 (visibility guard)" do
    hidden = ScheduleItem.create!(
      slug: "vol-only", day: "fri", title: "Vol-only briefing",
      kind: :volunteer, is_public: true, audience: "volunteers_only",
      volunteer_capacity: 3
    )
    sign_in_as users(:attendee_one)

    assert_no_difference -> { users(:attendee_one).plan_items.count } do
      post plan_items_path, params: { schedule_item_id: hidden.id }
    end
    assert_response :not_found
  end

  test "volunteer can RSVP to a volunteers_only item" do
    hidden = ScheduleItem.create!(
      slug: "vol-only", day: "fri", title: "Vol-only briefing",
      kind: :volunteer, is_public: true, audience: "volunteers_only",
      volunteer_capacity: 3
    )
    sign_in_as users(:volunteer_one)

    assert_difference -> { users(:volunteer_one).plan_items.count }, 1 do
      post plan_items_path, params: { schedule_item_id: hidden.id }
    end
  end

  test "turbo_stream DELETE response removes plan_item frame AND updates schedule_item frame" do
    sign_in_as users(:attendee_one)
    plan = users(:attendee_one).plan_items.create!(schedule_item: @item)

    delete plan_item_path(plan), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    # /plan uses this to make the row disappear.
    assert_match %r{<turbo-stream action="remove" target="plan_item_#{plan.id}">}, response.body
    # /schedule uses this to revert the button to "+ Add to plan" / "+ RSVP".
    assert_match %r{<turbo-stream action="replace" target="schedule_item_#{@item.id}">}, response.body
  end

  test "DELETE on plan_item with submitted embassy application does NOT destroy" do
    sign_in_as users(:attendee_one)
    embassy_item = ScheduleItem.create!(
      slug: "embassy-block", day: "sat", title: "Embassy Block",
      kind: :embassy, is_public: true, embassy_mode: "new_passport", embassy_capacity: 10
    )
    plan        = users(:attendee_one).plan_items.create!(schedule_item: embassy_item)
    booking     = EmbassyBooking.create!(
      user: users(:attendee_one), schedule_item: embassy_item, plan_item: plan,
      mode: "new_passport", state: "confirmed"
    )
    EmbassyApplication.create!(embassy_booking: booking, state: "submitted")

    assert_no_difference -> { PlanItem.count } do
      assert_no_difference -> { EmbassyBooking.count } do
        assert_no_difference -> { EmbassyApplication.count } do
          delete plan_item_path(plan)
        end
      end
    end
    assert_redirected_to plan_path
    assert_match(/can't be cancelled/i, flash[:alert])
  end

  test "DELETE on plan_item with submitted embassy application returns 403 turbo_stream" do
    sign_in_as users(:attendee_one)
    embassy_item = ScheduleItem.create!(
      slug: "embassy-block", day: "sat", title: "Embassy Block",
      kind: :embassy, is_public: true, embassy_mode: "new_passport", embassy_capacity: 10
    )
    plan    = users(:attendee_one).plan_items.create!(schedule_item: embassy_item)
    booking = EmbassyBooking.create!(
      user: users(:attendee_one), schedule_item: embassy_item, plan_item: plan,
      mode: "new_passport", state: "confirmed"
    )
    EmbassyApplication.create!(embassy_booking: booking, state: "submitted")

    delete plan_item_path(plan), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :forbidden
    assert_match %r{<turbo-stream action="replace" target="plan_item_#{plan.id}">}, response.body
  end

  test "DELETE on plan_item with draft embassy application DOES destroy" do
    sign_in_as users(:attendee_one)
    embassy_item = ScheduleItem.create!(
      slug: "embassy-block", day: "sat", title: "Embassy Block",
      kind: :embassy, is_public: true, embassy_mode: "new_passport", embassy_capacity: 10
    )
    plan    = users(:attendee_one).plan_items.create!(schedule_item: embassy_item)
    booking = EmbassyBooking.create!(
      user: users(:attendee_one), schedule_item: embassy_item, plan_item: plan,
      mode: "new_passport", state: "confirmed"
    )
    EmbassyApplication.create!(embassy_booking: booking, state: "draft")

    assert_difference -> { PlanItem.count }, -1 do
      delete plan_item_path(plan)
    end
  end

  test "DELETE on stamping embassy booking (no application) DOES destroy" do
    sign_in_as users(:attendee_one)
    embassy_item = ScheduleItem.create!(
      slug: "embassy-stamp", day: "sat", title: "Embassy Stamping",
      kind: :embassy, is_public: true, embassy_mode: "stamping", embassy_capacity: 10
    )
    plan = users(:attendee_one).plan_items.create!(schedule_item: embassy_item)
    EmbassyBooking.create!(
      user: users(:attendee_one), schedule_item: embassy_item, plan_item: plan,
      mode: "stamping", state: "confirmed"
    )

    assert_difference -> { PlanItem.count }, -1 do
      delete plan_item_path(plan)
    end
  end
end
