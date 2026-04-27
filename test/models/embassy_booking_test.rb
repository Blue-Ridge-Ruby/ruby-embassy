require "test_helper"

class EmbassyBookingTest < ActiveSupport::TestCase
  setup do
    @item = ScheduleItem.create!(
      day: "thu", title: "Embassy Block", kind: :embassy, is_public: true,
      offers_new_passport: true, new_passport_capacity: 4,
      offers_passport_pickup: true, passport_pickup_capacity: 2
    )
    @user = users(:attendee_one)
    @plan_item = @user.plan_items.create!(schedule_item: @item)
  end

  test "passport_pickup is an allowed mode value" do
    booking = EmbassyBooking.create!(
      user: @user, schedule_item: @item, plan_item: @plan_item,
      mode: "passport_pickup", state: "confirmed"
    )
    assert booking.passport_pickup?
    assert_equal "passport_pickup", booking.mode
  end

  test "application_required? returns true only for new_passport" do
    np = EmbassyBooking.new(mode: "new_passport")
    st = EmbassyBooking.new(mode: "stamping")
    pp = EmbassyBooking.new(mode: "passport_pickup")
    assert np.application_required?
    assert_not st.application_required?
    assert_not pp.application_required?
  end
end
