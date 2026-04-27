require "test_helper"

class ScheduleItemTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      day: "thu",
      title: "Test Item",
      kind: :activity,
      is_public: true
    }.merge(overrides)
  end

  test "requires title" do
    item = ScheduleItem.new(valid_attrs(title: nil))
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "requires day" do
    item = ScheduleItem.new(valid_attrs(day: nil))
    assert_not item.valid?
    assert_includes item.errors[:day], "can't be blank"
  end

  test "requires kind" do
    item = ScheduleItem.new(valid_attrs.except(:kind))
    assert_not item.valid?
    assert_includes item.errors[:kind], "can't be blank"
  end

  test "kind enum exposes all 8 kinds with stable integer values" do
    assert_equal %w[talk lightning embassy activity reception meal community volunteer], ScheduleItem.kinds.keys
    assert_equal 0, ScheduleItem.kinds["talk"]
    assert_equal 1, ScheduleItem.kinds["lightning"]
    assert_equal 2, ScheduleItem.kinds["embassy"]
    assert_equal 3, ScheduleItem.kinds["activity"]
    assert_equal 4, ScheduleItem.kinds["reception"]
    assert_equal 5, ScheduleItem.kinds["meal"]
    assert_equal 6, ScheduleItem.kinds["community"]
    assert_equal 7, ScheduleItem.kinds["volunteer"]
  end

  test "is_public defaults to false" do
    item = ScheduleItem.new(valid_attrs.except(:is_public))
    assert_equal false, item.is_public
  end

  test "flexible defaults to false" do
    item = ScheduleItem.new(valid_attrs)
    assert_equal false, item.flexible
  end

  test "talk? returns true only for talk kind" do
    assert ScheduleItem.new(valid_attrs(kind: :talk)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :activity)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :lightning)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :embassy)).talk?
  end

  test "rsvp_count counts plan_items" do
    item = ScheduleItem.create!(valid_attrs)
    assert_equal 0, item.rsvp_count
    item.plan_items.create!(user: users(:attendee_one))
    item.plan_items.create!(user: users(:volunteer_one))
    assert_equal 2, item.reload.rsvp_count
  end

  test "editable_by? admin can edit any item" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert item.editable_by?(users(:jeremy))
  end

  test "editable_by? creator can edit own item" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert item.editable_by?(users(:attendee_one))
  end

  test "editable_by? non-creator non-admin cannot edit" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert_not item.editable_by?(users(:volunteer_one))
  end

  test "public_items scope returns only items with is_public: true" do
    public_item = ScheduleItem.create!(valid_attrs(title: "Public", is_public: true))
    private_item = ScheduleItem.create!(valid_attrs(title: "Private", is_public: false))
    assert_includes ScheduleItem.public_items, public_item
    assert_not_includes ScheduleItem.public_items, private_item
  end

  test "audience defaults to everyone" do
    item = ScheduleItem.create!(valid_attrs)
    assert_equal "everyone", item.audience
    assert item.audience_everyone?
  end

  test "visible_to admin returns all public items including volunteers_only" do
    everyone   = ScheduleItem.create!(valid_attrs(title: "Everyone", audience: "everyone"))
    volunteers = ScheduleItem.create!(valid_attrs(title: "Volunteers", audience: "volunteers_only"))
    private_   = ScheduleItem.create!(valid_attrs(title: "Private", is_public: false))

    visible = ScheduleItem.visible_to(users(:jeremy))
    assert_includes visible, everyone
    assert_includes visible, volunteers
    assert_not_includes visible, private_
  end

  test "visible_to volunteer returns all public items including volunteers_only" do
    everyone   = ScheduleItem.create!(valid_attrs(title: "Everyone", audience: "everyone"))
    volunteers = ScheduleItem.create!(valid_attrs(title: "Volunteers", audience: "volunteers_only"))

    visible = ScheduleItem.visible_to(users(:volunteer_one))
    assert_includes visible, everyone
    assert_includes visible, volunteers
  end

  test "visible_to attendee returns only audience: everyone items" do
    everyone   = ScheduleItem.create!(valid_attrs(title: "Everyone", audience: "everyone"))
    volunteers = ScheduleItem.create!(valid_attrs(title: "Volunteers", audience: "volunteers_only"))

    visible = ScheduleItem.visible_to(users(:attendee_one))
    assert_includes visible, everyone
    assert_not_includes visible, volunteers
  end

  test "visible_to nil (signed-out) returns only audience: everyone items" do
    everyone   = ScheduleItem.create!(valid_attrs(title: "Everyone", audience: "everyone"))
    volunteers = ScheduleItem.create!(valid_attrs(title: "Volunteers", audience: "volunteers_only"))

    visible = ScheduleItem.visible_to(nil)
    assert_includes visible, everyone
    assert_not_includes visible, volunteers
  end

  test "visible_to never returns private items regardless of role" do
    private_ = ScheduleItem.create!(valid_attrs(title: "Private", is_public: false))
    [ users(:jeremy), users(:volunteer_one), users(:attendee_one), nil ].each do |user|
      assert_not_includes ScheduleItem.visible_to(user), private_, "private items must not appear for #{user&.role || 'nil'}"
    end
  end

  test "ordered scope orders by day then sort_time" do
    wed_am = ScheduleItem.create!(valid_attrs(day: "wed", sort_time: 900, title: "Wed AM"))
    wed_pm = ScheduleItem.create!(valid_attrs(day: "wed", sort_time: 1800, title: "Wed PM"))
    thu_am = ScheduleItem.create!(valid_attrs(day: "thu", sort_time: 900, title: "Thu AM"))
    ordered = ScheduleItem.where(id: [ wed_am.id, wed_pm.id, thu_am.id ]).ordered
    assert_equal [ wed_am, wed_pm, thu_am ], ordered.to_a
  end

  test "ordered scope places Sunday after Saturday" do
    sat = ScheduleItem.create!(valid_attrs(day: "sat", sort_time: 1800, title: "Sat PM"))
    sun = ScheduleItem.create!(valid_attrs(day: "sun", sort_time: 900,  title: "Sun AM brunch"))
    ordered = ScheduleItem.where(id: [ sat.id, sun.id ]).ordered
    assert_equal [ sat, sun ], ordered.to_a
  end

  test "DAY_META includes Sunday" do
    assert ScheduleItem::DAY_META.key?("sun"), "Sunday should be a listed day"
    assert_equal "Sunday", ScheduleItem::DAY_META["sun"][:label]
  end

  test "upcoming_day_keys returns conference days on or after the given date" do
    assert_equal %w[wed thu fri sat sun], ScheduleItem.upcoming_day_keys(Date.new(2026, 4, 27))
    assert_equal %w[wed thu fri sat sun], ScheduleItem.upcoming_day_keys(Date.new(2026, 4, 29))
    assert_equal %w[thu fri sat sun],     ScheduleItem.upcoming_day_keys(Date.new(2026, 4, 30))
    assert_equal %w[fri sat sun],         ScheduleItem.upcoming_day_keys(Date.new(2026, 5, 1))
    assert_equal %w[sun],                 ScheduleItem.upcoming_day_keys(Date.new(2026, 5, 3))
    assert_equal [],                      ScheduleItem.upcoming_day_keys(Date.new(2026, 5, 4))
  end

  test "after_create auto-plans private items for creator" do
    assert_difference -> { PlanItem.count }, 1 do
      ScheduleItem.create!(valid_attrs(
        title: "Private Dinner",
        is_public: false,
        created_by: users(:attendee_one)
      ))
    end
    assert_equal users(:attendee_one), PlanItem.last.user
  end

  test "after_create auto-plans public items for creator too" do
    assert_difference -> { PlanItem.count }, 1 do
      ScheduleItem.create!(valid_attrs(
        title: "Public Activity",
        is_public: true,
        created_by: users(:attendee_one)
      ))
    end
    assert_equal users(:attendee_one), PlanItem.last.user
  end

  test "after_create does not auto-plan seeded items (no creator)" do
    assert_no_difference -> { PlanItem.count } do
      ScheduleItem.create!(valid_attrs(
        title: "Seeded-Like",
        is_public: true,
        created_by: nil
      ))
    end
  end

  # ----- Volunteer capacity ----------------------------------------------

  def volunteer_attrs(overrides = {})
    valid_attrs(kind: :volunteer, title: "Stamp passports", volunteer_capacity: 3).merge(overrides)
  end

  test "volunteer_capacity is required when kind is volunteer" do
    item = ScheduleItem.new(volunteer_attrs(volunteer_capacity: nil))
    assert_not item.valid?
    assert_includes item.errors[:volunteer_capacity], "can't be blank"
  end

  test "volunteer_capacity not required for non-volunteer kinds" do
    item = ScheduleItem.new(valid_attrs(kind: :activity, volunteer_capacity: nil))
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "volunteer_capacity must be a positive integer" do
    item = ScheduleItem.new(volunteer_attrs(volunteer_capacity: 0))
    assert_not item.valid?
    assert_includes item.errors[:volunteer_capacity], "must be greater than 0"
  end

  test "volunteer_state returns :empty when no signups" do
    item = ScheduleItem.create!(volunteer_attrs(volunteer_capacity: 3))
    assert item.volunteer_empty?
    assert_equal :empty, item.volunteer_state
  end

  test "volunteer_state returns :partial when some signups but not full" do
    item = ScheduleItem.create!(volunteer_attrs(volunteer_capacity: 3))
    item.plan_items.create!(user: users(:volunteer_one))
    assert item.reload.volunteer_partial?
    assert_equal :partial, item.volunteer_state
  end

  test "volunteer_state returns :full when capacity reached" do
    item = ScheduleItem.create!(volunteer_attrs(volunteer_capacity: 2))
    item.plan_items.create!(user: users(:volunteer_one))
    item.plan_items.create!(user: users(:jeremy))
    assert item.reload.volunteer_full?
    assert_equal :full, item.volunteer_state
  end

  test "volunteer_state returns nil for non-volunteer kinds" do
    item = ScheduleItem.create!(valid_attrs(kind: :talk))
    assert_nil item.volunteer_state
  end

  test "volunteer_seats_remaining decrements with signups" do
    item = ScheduleItem.create!(volunteer_attrs(volunteer_capacity: 3))
    assert_equal 3, item.volunteer_seats_remaining
    item.plan_items.create!(user: users(:volunteer_one))
    assert_equal 2, item.reload.volunteer_seats_remaining
  end

  test "volunteer_empty scope returns only volunteer-kind items with zero signups" do
    empty   = ScheduleItem.create!(volunteer_attrs(title: "Empty"))
    filled  = ScheduleItem.create!(volunteer_attrs(title: "Filled", volunteer_capacity: 1))
    filled.plan_items.create!(user: users(:volunteer_one))
    other   = ScheduleItem.create!(valid_attrs(kind: :talk, title: "Talk"))

    result = ScheduleItem.volunteer_empty
    assert_includes result, empty
    assert_not_includes result, filled
    assert_not_includes result, other
  end

  # ----- Per-mode embassy capacity ---------------------------------------

  def embassy_attrs(overrides = {})
    valid_attrs(
      kind: :embassy,
      title: "Test Embassy",
      offers_new_passport: true,
      new_passport_capacity: 4
    ).merge(overrides)
  end

  test "embassy block requires at least one mode" do
    item = ScheduleItem.new(valid_attrs(kind: :embassy))
    assert_not item.valid?
    assert_includes item.errors[:base].join, "must offer at least one mode"
  end

  test "embassy block requires capacity for each offered mode" do
    item = ScheduleItem.new(embassy_attrs(offers_stamping: true, stamping_capacity: nil))
    assert_not item.valid?
    assert_includes item.errors[:stamping_capacity], "must be set when this mode is offered"
  end

  test "embassy block valid with single mode and matching capacity" do
    item = ScheduleItem.new(embassy_attrs)
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "embassy block valid with all three modes" do
    item = ScheduleItem.new(embassy_attrs(
      offers_stamping: true, stamping_capacity: 3,
      offers_passport_pickup: true, passport_pickup_capacity: 2
    ))
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "active_embassy_modes lists only enabled modes" do
    item = ScheduleItem.create!(embassy_attrs(offers_stamping: true, stamping_capacity: 2))
    assert_equal %w[new_passport stamping].sort, item.active_embassy_modes.sort
  end

  test "seats_taken_for counts only that mode's bookings" do
    item = ScheduleItem.create!(embassy_attrs(offers_stamping: true, stamping_capacity: 2))
    user = users(:attendee_one)
    plan_item = user.plan_items.create!(schedule_item: item)
    EmbassyBooking.create!(user: user, schedule_item: item, plan_item: plan_item,
                           mode: "stamping", state: "confirmed")
    assert_equal 0, item.seats_taken_for("new_passport")
    assert_equal 1, item.seats_taken_for("stamping")
  end

  test "full_for? is per-mode" do
    item = ScheduleItem.create!(embassy_attrs(
      new_passport_capacity: 1,
      offers_stamping: true, stamping_capacity: 5
    ))
    user = users(:attendee_one)
    plan_item = user.plan_items.create!(schedule_item: item)
    EmbassyBooking.create!(user: user, schedule_item: item, plan_item: plan_item,
                           mode: "new_passport", state: "confirmed")
    assert item.full_for?("new_passport")
    assert_not item.full_for?("stamping")
  end

  test "embassy_mode derives 'both' when passport and stamping are offered" do
    item = ScheduleItem.new(embassy_attrs(offers_stamping: true, stamping_capacity: 2))
    assert_equal "both", item.embassy_mode
  end

  test "embassy_mode derives 'passport_pickup' when only pickup is offered" do
    item = ScheduleItem.new(valid_attrs(
      kind: :embassy,
      offers_new_passport: false,
      offers_passport_pickup: true,
      passport_pickup_capacity: 3
    ))
    assert_equal "passport_pickup", item.embassy_mode
  end

  test "full? returns true only when every active mode is full" do
    item = ScheduleItem.create!(embassy_attrs(
      new_passport_capacity: 1,
      offers_stamping: true, stamping_capacity: 5
    ))
    user = users(:attendee_one)
    plan_item = user.plan_items.create!(schedule_item: item)
    EmbassyBooking.create!(user: user, schedule_item: item, plan_item: plan_item,
                           mode: "new_passport", state: "confirmed")
    assert_not item.full?, "passport full but stamping has seats — block isn't fully full"
  end

  test "total_capacity sums all per-mode capacities" do
    item = ScheduleItem.create!(embassy_attrs(
      new_passport_capacity: 4,
      offers_stamping: true, stamping_capacity: 3,
      offers_passport_pickup: true, passport_pickup_capacity: 2
    ))
    assert_equal 9, item.total_capacity
  end
end
