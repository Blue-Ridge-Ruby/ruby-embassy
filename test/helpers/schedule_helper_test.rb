require "test_helper"

class ScheduleHelperTest < ActionView::TestCase
  setup do
    @host     = users(:attendee_one)
    @activity = ScheduleItem.create!(
      day: "sat", title: "Looking Glass Hike",
      kind: :activity, is_public: true, created_by: @host
    )
    # auto_plan_for_creator already creates @host's plan_item
    @rsvper       = users(:volunteer_one)
    @rsvper_plan  = @rsvper.plan_items.create!(schedule_item: @activity, contact_method: "@vic on Slack")
  end

  test "activity creator sees co-attendee contacts" do
    assert can_see_activity_contact?(@host, @rsvper_plan)
  end

  test "fellow RSVPer sees other attendees' contacts" do
    third = users(:jeremy)
    third.plan_items.create!(schedule_item: @activity)
    assert can_see_activity_contact?(third, @rsvper_plan)
  end

  test "RSVPer always sees their own contact" do
    assert can_see_activity_contact?(@rsvper, @rsvper_plan)
  end

  test "non-RSVPer who isn't the creator does not see contacts" do
    stranger = users(:katya)
    assert_not can_see_activity_contact?(stranger, @rsvper_plan)
  end

  test "nil viewer or plan_item returns false" do
    assert_not can_see_activity_contact?(nil, @rsvper_plan)
    assert_not can_see_activity_contact?(@host, nil)
  end
end
