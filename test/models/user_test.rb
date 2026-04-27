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

  test "new user is auto-RSVPed to all default-plan items" do
    talk      = ScheduleItem.create!(day: "thu", title: "Default Talk", kind: :talk, is_public: true)
    reception = ScheduleItem.create!(day: "thu", title: "Default Reception", kind: :reception, is_public: true)
    activity  = ScheduleItem.create!(day: "sat", title: "Optional Activity", kind: :activity, is_public: true)
    private_talk = ScheduleItem.create!(day: "thu", title: "Private Talk", kind: :talk, is_public: false)
    volunteers_only_reception = ScheduleItem.create!(
      day: "thu", title: "Crew Reception", kind: :reception,
      is_public: true, audience: "volunteers_only"
    )

    user = User.create!(email: "newbie@example.com", first_name: "New", last_name: "Bie")

    assert_includes user.planned_schedule_items, talk
    assert_includes user.planned_schedule_items, reception
    assert_not_includes user.planned_schedule_items, activity, "non-default kinds should not be auto-added"
    assert_not_includes user.planned_schedule_items, private_talk, "private items should not be auto-added"
    assert_not_includes user.planned_schedule_items, volunteers_only_reception, "volunteers_only items should not be auto-added to attendees"
  end

  test "materialize_default_plan_items is idempotent" do
    ScheduleItem.create!(day: "thu", title: "Default Talk", kind: :talk, is_public: true)
    user = User.create!(email: "idem@example.com", first_name: "I", last_name: "D")

    assert_no_difference -> { user.plan_items.count } do
      user.materialize_default_plan_items
      user.materialize_default_plan_items
    end
  end
end
