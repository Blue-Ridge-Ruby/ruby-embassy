require "test_helper"

class MealSpotTest < ActiveSupport::TestCase
  def meal
    @meal ||= ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
  end

  def build_spot(name: "Hattie B's", creator: users(:attendee_one))
    meal.meal_spots.create!(name: name, created_by: creator)
  end

  test "rejects spots whose parent isn't a meal" do
    talk = ScheduleItem.create!(day: "thu", title: "Keynote", kind: :talk, is_public: true)
    spot = talk.meal_spots.build(name: "Anywhere", created_by: users(:attendee_one))
    assert_not spot.valid?
    assert_includes spot.errors[:schedule_item], "must be a meal event"
  end

  test "name is unique per meal, case-insensitively" do
    build_spot(name: "Hattie B's")
    dup = meal.meal_spots.build(name: "hattie b's", created_by: users(:volunteer_one))
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "editable_by? lets the creator edit until anyone else RSVPs" do
    spot = build_spot(creator: users(:attendee_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: users(:attendee_one))

    assert spot.editable_by?(users(:attendee_one)),  "creator can edit before others join"
    assert_not spot.editable_by?(users(:volunteer_one)), "non-creator can't edit"

    transport.rsvps.create!(user: users(:volunteer_one))
    spot.reload
    assert_not spot.editable_by?(users(:attendee_one)),  "creator locked out once others join"
    assert spot.editable_by?(users(:jeremy)), "admins can always edit"
  end

  test "ownership transfers when the creator un-RSVPs" do
    spot = build_spot(creator: users(:attendee_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    creator_rsvp = transport.rsvps.create!(user: users(:attendee_one))
    transport.rsvps.create!(user: users(:volunteer_one))

    creator_rsvp.destroy!
    assert_equal users(:volunteer_one), spot.reload.created_by
  end
end
