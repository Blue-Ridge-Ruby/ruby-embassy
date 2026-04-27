require "test_helper"

class PlanItemTest < ActiveSupport::TestCase
  def build_schedule_item
    ScheduleItem.create!(day: "thu", title: "Some Item", kind: :activity, is_public: true)
  end

  test "belongs_to user and schedule_item" do
    item = build_schedule_item
    plan = PlanItem.create!(user: users(:attendee_one), schedule_item: item)
    assert_equal users(:attendee_one), plan.user
    assert_equal item, plan.schedule_item
  end

  test "a user cannot have two plan_items for the same schedule_item" do
    item = build_schedule_item
    PlanItem.create!(user: users(:attendee_one), schedule_item: item)
    duplicate = PlanItem.new(user: users(:attendee_one), schedule_item: item)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "already has this item on their plan"
  end

  test "different users can both have the same schedule_item on their plans" do
    item = build_schedule_item
    PlanItem.create!(user: users(:attendee_one), schedule_item: item)
    other = PlanItem.new(user: users(:volunteer_one), schedule_item: item)
    assert other.valid?
  end

  test "notes are optional" do
    item = build_schedule_item
    plan = PlanItem.new(user: users(:attendee_one), schedule_item: item)
    assert plan.valid?
  end

  test "cannot create plan_item for a full volunteer slot" do
    slot = ScheduleItem.create!(
      day: "thu", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 1
    )
    PlanItem.create!(user: users(:volunteer_one), schedule_item: slot)

    overflow = PlanItem.new(user: users(:jeremy), schedule_item: slot)
    assert_not overflow.valid?
    assert_includes overflow.errors[:base], "This volunteer slot is full"
  end

  test "non-full volunteer slot accepts a signup" do
    slot = ScheduleItem.create!(
      day: "thu", title: "Stamp passports",
      kind: :volunteer, is_public: true, volunteer_capacity: 2
    )
    plan = PlanItem.new(user: users(:volunteer_one), schedule_item: slot)
    assert plan.valid?
  end

  test "contact_method is optional and persists when given" do
    item = build_schedule_item
    plan = PlanItem.create!(
      user: users(:attendee_one),
      schedule_item: item,
      contact_method: "text 555-0100"
    )
    assert_equal "text 555-0100", plan.reload.contact_method
  end
end
