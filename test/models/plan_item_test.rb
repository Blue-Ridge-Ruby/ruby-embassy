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
end
