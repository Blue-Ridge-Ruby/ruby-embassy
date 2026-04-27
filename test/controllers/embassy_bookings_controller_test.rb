require "test_helper"

class EmbassyBookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @block = ScheduleItem.create!(
      day: "thu", title: "Embassy Block", kind: :embassy, is_public: true,
      offers_new_passport: true, new_passport_capacity: 2,
      offers_stamping: true, stamping_capacity: 1,
      offers_passport_pickup: true, passport_pickup_capacity: 1,
      time_label: "9:00 AM", sort_time: 900
    )
    @user = users(:attendee_one)
  end

  test "user can book new_passport mode" do
    sign_in_as @user
    assert_difference -> { EmbassyBooking.where(mode: "new_passport").count }, 1 do
      post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "new_passport" }
    end
  end

  test "user can book stamping mode" do
    sign_in_as @user
    assert_difference -> { EmbassyBooking.where(mode: "stamping").count }, 1 do
      post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "stamping" }
    end
  end

  test "stamping create redirects so Turbo accepts the form response" do
    sign_in_as @user
    post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "stamping" }
    booking = EmbassyBooking.where(mode: "stamping").last
    assert_redirected_to embassy_booking_path(booking)
    follow_redirect!
    assert_response :success
    assert_match(/Stamping Appointment.*Confirmed/, response.body)
  end

  test "show only returns caller's own booking" do
    sign_in_as @user
    other_plan = users(:volunteer_one).plan_items.create!(schedule_item: @block)
    other = EmbassyBooking.create!(user: users(:volunteer_one), schedule_item: @block,
                                    plan_item: other_plan, mode: "stamping", state: "confirmed")
    get embassy_booking_path(other)
    assert_response :not_found
  end

  test "user-facing flow rejects passport_pickup mode" do
    sign_in_as @user
    assert_no_difference -> { EmbassyBooking.where(mode: "passport_pickup").count } do
      post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "passport_pickup" }
    end
  end

  test "booking is rejected when chosen mode is full but other modes have seats" do
    other = users(:volunteer_one)
    other_plan = other.plan_items.create!(schedule_item: @block)
    EmbassyBooking.create!(user: other, schedule_item: @block, plan_item: other_plan,
                           mode: "stamping", state: "confirmed")

    sign_in_as @user
    assert_no_difference -> { EmbassyBooking.where(mode: "stamping").count } do
      post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "stamping" }
    end
    assert_redirected_to new_embassy_booking_path(schedule_item_id: @block.id)
  end

  test "booking succeeds in another mode even when one mode is full" do
    other = users(:volunteer_one)
    other_plan = other.plan_items.create!(schedule_item: @block)
    EmbassyBooking.create!(user: other, schedule_item: @block, plan_item: other_plan,
                           mode: "stamping", state: "confirmed")

    sign_in_as @user
    assert_difference -> { EmbassyBooking.where(mode: "new_passport").count }, 1 do
      post embassy_bookings_path, params: { schedule_item_id: @block.id, mode: "new_passport" }
    end
  end
end
