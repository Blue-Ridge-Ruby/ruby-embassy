require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "destroying user destroys their plan_items" do
    user = users(:attendee_one)
    item = ScheduleItem.create!(day: "thu", title: "Destroy test", kind: :activity, is_public: true)
    user.plan_items.create!(schedule_item: item)

    assert_difference -> { PlanItem.count }, -1 do
      user.destroy
    end
  end

  test "destroying user nullifies created_schedule_items (items survive)" do
    creator = users(:attendee_one)
    item = ScheduleItem.create!(
      day: "thu",
      title: "Creator-owned",
      kind: :activity,
      is_public: true,
      created_by: creator
    )

    creator.destroy

    assert ScheduleItem.exists?(item.id), "schedule_item should survive creator deletion"
    assert_nil item.reload.created_by_id
  end

  test "planned_schedule_items returns items on user's plan" do
    user = users(:attendee_one)
    item = ScheduleItem.create!(day: "fri", title: "Planned", kind: :talk, is_public: true)
    user.plan_items.create!(schedule_item: item)

    assert_includes user.planned_schedule_items, item
  end
end
